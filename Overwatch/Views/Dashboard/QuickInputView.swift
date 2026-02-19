import SwiftUI
import SwiftData

/// HUD-styled text input field for freeform habit logging.
///
/// SF Mono font, ">" prompt character, blinking cursor animation.
/// Submit routes to NaturalLanguageParser for regex-based matching.
/// Success: glow pulse + particle scatter + confirmation materialize.
/// Error: red glow + shake + error message.
struct QuickInputView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: DashboardViewModel

    @State private var inputText = ""
    @State private var isFocused = false
    @State private var feedbackState: FeedbackState = .idle
    @State private var feedbackMessage = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var particleTrigger = false
    @State private var inputHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var isParsing = false
    @FocusState private var fieldFocused: Bool

    private let historyKey = "overwatch.quickInput.history"
    private let maxHistory = 20
    private let parser = NaturalLanguageParser()

    enum FeedbackState {
        case idle
        case success(String)
        case error(String)
    }

    var body: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            inputField
            feedbackLabel
        }
        .onAppear {
            loadHistory()
        }
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            // Prompt character
            Text(">")
                .font(Typography.commandPrompt)
                .foregroundStyle(
                    fieldFocused
                        ? OverwatchTheme.accentCyan
                        : OverwatchTheme.accentCyan.opacity(0.4)
                )
                .textGlow(OverwatchTheme.accentCyan, radius: fieldFocused ? 8 : 2)

            // Text field
            TextField("", text: $inputText, prompt: promptText)
                .textFieldStyle(.plain)
                .font(Typography.commandLine)
                .foregroundStyle(OverwatchTheme.textPrimary)
                .focused($fieldFocused)
                .onSubmit {
                    submitInput()
                }
                .onKeyPress(.upArrow) {
                    navigateHistory(direction: .up)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    navigateHistory(direction: .down)
                    return .handled
                }

            // Blinking cursor when empty and not focused
            if inputText.isEmpty && !fieldFocused {
                BlinkingInputCursor()
            }
        }
        .padding(.horizontal, OverwatchTheme.Spacing.lg)
        .padding(.vertical, OverwatchTheme.Spacing.md)
        .background(OverwatchTheme.surfaceTranslucent)
        .clipShape(HUDFrameShape(chamferSize: 10))
        .overlay(
            HUDFrameShape(chamferSize: 10)
                .stroke(
                    fieldFocused
                        ? OverwatchTheme.accentCyan.opacity(0.6)
                        : OverwatchTheme.accentCyan.opacity(0.15),
                    lineWidth: fieldFocused ? 1.5 : 1
                )
        )
        .shadow(
            color: fieldFocused ? OverwatchTheme.accentCyan.opacity(0.2) : .clear,
            radius: fieldFocused ? 8 : 0
        )
        .shadow(
            color: fieldFocused ? OverwatchTheme.accentCyan.opacity(0.08) : .clear,
            radius: fieldFocused ? 20 : 0
        )
        .offset(x: shakeOffset)
        .particleScatter(
            trigger: $particleTrigger,
            particleCount: 8,
            burstRadius: 30,
            color: OverwatchTheme.accentSecondary
        )
        .animation(.easeInOut(duration: 0.15), value: fieldFocused)
    }

    private var promptText: Text {
        if isParsing {
            return Text("ANALYZING INPUT...")
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
        }
        return Text("Log a habit... (e.g., 'Drank 3L water')")
            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.25))
    }

    // MARK: - Feedback Label

    @ViewBuilder
    private var feedbackLabel: some View {
        switch feedbackState {
        case .idle:
            EmptyView()

        case .success(let message):
            HStack(spacing: OverwatchTheme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(OverwatchTheme.accentSecondary)
                    .font(.system(size: 11))
                Text(message)
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentSecondary)
                    .tracking(1.5)
                    .textGlow(OverwatchTheme.accentSecondary, radius: 4)
            }
            .transition(.opacity.combined(with: .offset(y: 4)))

        case .error(let message):
            HStack(spacing: OverwatchTheme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(OverwatchTheme.alert)
                    .font(.system(size: 11))
                Text(message)
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.alert)
                    .tracking(1.5)
                    .textGlow(OverwatchTheme.alert, radius: 4)
            }
            .transition(.opacity.combined(with: .offset(y: 4)))
        }
    }

    // MARK: - Submit

    private func submitInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !isParsing else { return }

        saveToHistory(trimmed)

        let habitRefs = viewModel.trackedHabits.map { tracked in
            HabitReference(
                id: tracked.id,
                name: tracked.name,
                isQuantitative: false,
                unitLabel: ""
            )
        }

        isParsing = true
        let capturedText = trimmed

        Task {
            let parsed = await parser.parse(capturedText, habits: habitRefs)
            isParsing = false

            if let habitID = parsed.matchedHabitID, parsed.confidence >= 0.5 {
                handleSuccessfulParse(parsed, habitID: habitID)
            } else {
                handleFailedParse()
            }
        }
    }

    private func handleSuccessfulParse(_ parsed: ParsedHabit, habitID: UUID) {
        if parsed.value != nil {
            viewModel.confirmHabitEntry(
                habitID,
                value: parsed.value,
                notes: parsed.rawInput,
                in: modelContext
            )
        } else {
            viewModel.toggleHabitCompletion(habitID, in: modelContext)
        }
        inputText = ""
        historyIndex = -1

        particleTrigger = true
        withAnimation(.easeOut(duration: 0.3)) {
            feedbackState = .success("LOGGED: \(parsed.habitName.uppercased())")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.2)) {
                feedbackState = .idle
            }
        }
    }

    private func handleFailedParse() {
        inputText = ""
        historyIndex = -1

        withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) {
            shakeOffset = 6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) {
                shakeOffset = -4
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) {
                shakeOffset = 2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                shakeOffset = 0
            }
        }

        withAnimation(.easeOut(duration: 0.3)) {
            feedbackState = .error("UNRECOGNIZED INPUT")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                feedbackState = .idle
            }
        }
    }

    // MARK: - History

    private enum HistoryDirection {
        case up, down
    }

    private func navigateHistory(direction: HistoryDirection) {
        guard !inputHistory.isEmpty else { return }

        switch direction {
        case .up:
            if historyIndex < inputHistory.count - 1 {
                historyIndex += 1
                inputText = inputHistory[inputHistory.count - 1 - historyIndex]
            }
        case .down:
            if historyIndex > 0 {
                historyIndex -= 1
                inputText = inputHistory[inputHistory.count - 1 - historyIndex]
            } else {
                historyIndex = -1
                inputText = ""
            }
        }
    }

    private func saveToHistory(_ text: String) {
        inputHistory.append(text)
        if inputHistory.count > maxHistory {
            inputHistory.removeFirst()
        }
        UserDefaults.standard.set(inputHistory, forKey: historyKey)
    }

    private func loadHistory() {
        inputHistory = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }
}

// MARK: - Blinking Input Cursor

private struct BlinkingInputCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(OverwatchTheme.accentCyan)
            .frame(width: 2, height: 14)
            .opacity(visible ? 0.8 : 0)
            .shadow(color: OverwatchTheme.accentCyan.opacity(0.6), radius: 4)
            .shadow(color: OverwatchTheme.accentCyan.opacity(0.2), radius: 10)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

#Preview("Quick Input") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        QuickInputView(viewModel: DashboardViewModel())
            .padding()
            .frame(width: 600)
    }
    .modelContainer(for: [Habit.self, HabitEntry.self], inMemory: true)
    .frame(width: 700, height: 200)
}
