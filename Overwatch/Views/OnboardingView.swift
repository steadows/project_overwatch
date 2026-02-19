import SwiftUI
import SwiftData

// MARK: - Onboarding Sequence View

/// Four-step guided setup shown once on first launch, after the boot sequence.
/// Step 1: Welcome → Step 2: Connect WHOOP → Step 3: Add Habits → Step 4: Operational
struct OnboardingView: View {
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 1
    @State private var stepVisible = true
    @State private var completionBurst = false

    var body: some View {
        ZStack {
            // Background layers
            OverwatchTheme.background.ignoresSafeArea()
            GridBackdrop().ignoresSafeArea()
            DataStreamTexture(opacity: 0.04).ignoresSafeArea()
            ScanLineOverlay().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Step content
                Group {
                    switch currentStep {
                    case 1: WelcomeStep(onNext: advanceStep)
                    case 2: ConnectWhoopStep(onNext: advanceStep, onSkip: advanceStep)
                    case 3: AddHabitsStep(modelContext: modelContext, onNext: advanceStep)
                    case 4: OperationalStep(onComplete: finishOnboarding)
                    default: EmptyView()
                    }
                }
                .materializeEffect(isVisible: stepVisible, delay: 0.05)

                Spacer()

                // Progress dots
                if currentStep < 4 {
                    ProgressDots(currentStep: currentStep, totalSteps: 4)
                        .padding(.bottom, OverwatchTheme.Spacing.xxl)
                }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .particleScatter(
            trigger: $completionBurst,
            particleCount: 20,
            burstRadius: 80,
            color: OverwatchTheme.accentSecondary
        )
    }

    private func advanceStep() {
        withAnimation(.easeIn(duration: 0.2)) {
            stepVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentStep += 1
            withAnimation(.easeOut(duration: 0.3)) {
                stepVisible = true
            }
        }
    }

    private func finishOnboarding() {
        completionBurst = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onComplete()
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    var onNext: () -> Void

    var body: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                // Header
                VStack(spacing: OverwatchTheme.Spacing.sm) {
                    Text("WELCOME, OPERATOR")
                        .font(Typography.title)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(3)
                        .textGlow(OverwatchTheme.accentCyan, radius: 10)

                    HUDDivider()
                        .padding(.horizontal, OverwatchTheme.Spacing.xl)
                }

                // Description
                Text("Overwatch tracks your habits, syncs your biometrics, and delivers AI-powered performance insights.")
                    .font(Typography.caption)
                    .foregroundStyle(OverwatchTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, OverwatchTheme.Spacing.lg)

                // CTA
                HUDButton(label: "BEGIN SETUP", action: onNext)
            }
            .padding(.vertical, OverwatchTheme.Spacing.xl)
        }
        .frame(maxWidth: 420)
    }
}

// MARK: - Step 2: Connect WHOOP

private struct ConnectWhoopStep: View {
    var onNext: () -> Void
    var onSkip: () -> Void

    @State private var connectionStatus: ConnectionStatus = .idle

    private enum ConnectionStatus {
        case idle, connecting, connected
    }

    var body: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                // Header
                VStack(spacing: OverwatchTheme.Spacing.sm) {
                    Text("LINK BIOMETRIC SOURCE")
                        .font(Typography.title)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(3)
                        .textGlow(OverwatchTheme.accentCyan, radius: 10)

                    HUDDivider()
                        .padding(.horizontal, OverwatchTheme.Spacing.xl)
                }

                // WHOOP connection
                VStack(spacing: OverwatchTheme.Spacing.lg) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .symbolRenderingMode(.hierarchical)

                    switch connectionStatus {
                    case .idle:
                        Text("Connect your WHOOP to sync recovery, strain, and sleep data.")
                            .font(Typography.caption)
                            .foregroundStyle(OverwatchTheme.textSecondary)
                            .multilineTextAlignment(.center)

                    case .connecting:
                        HStack(spacing: OverwatchTheme.Spacing.sm) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(OverwatchTheme.accentCyan)
                            Text("ESTABLISHING LINK...")
                                .font(Typography.hudLabel)
                                .foregroundStyle(OverwatchTheme.accentCyan)
                                .tracking(1.5)
                        }

                    case .connected:
                        HStack(spacing: OverwatchTheme.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OverwatchTheme.accentSecondary)
                            Text("WHOOP LINKED — Biometric data will sync automatically")
                                .font(Typography.caption)
                                .foregroundStyle(OverwatchTheme.accentSecondary)
                        }
                    }
                }

                // Actions
                VStack(spacing: OverwatchTheme.Spacing.md) {
                    if connectionStatus == .idle {
                        HUDButton(label: "CONNECT WHOOP") {
                            connectionStatus = .connecting
                            // TODO: Phase 3 — trigger real OAuth flow
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                connectionStatus = .connected
                            }
                        }
                    }

                    if connectionStatus == .connected {
                        HUDButton(label: "CONTINUE", action: onNext)
                    }

                    Button(action: onSkip) {
                        Text("SKIP FOR NOW")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.textSecondary)
                            .tracking(1.5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, OverwatchTheme.Spacing.xl)
        }
        .frame(maxWidth: 420)
    }
}

// MARK: - Step 3: Add Habits

private struct AddHabitsStep: View {
    let modelContext: ModelContext
    var onNext: () -> Void

    @State private var selectedHabits: Set<String> = []
    @State private var showCustomForm = false

    private static let suggestions: [(name: String, emoji: String, category: String)] = [
        ("Water", "💧", "Health"),
        ("Exercise", "🏋️", "Health"),
        ("Sleep 8h", "😴", "Health"),
        ("Meditation", "🧘", "Wellness"),
        ("Reading", "📖", "Growth"),
    ]

    var body: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                // Header
                VStack(spacing: OverwatchTheme.Spacing.sm) {
                    Text("ESTABLISH OPERATIONS")
                        .font(Typography.title)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(3)
                        .textGlow(OverwatchTheme.accentCyan, radius: 10)

                    HUDDivider()
                        .padding(.horizontal, OverwatchTheme.Spacing.xl)

                    Text("Select habits to track. Tap to add, tap again to remove.")
                        .font(Typography.caption)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Habit chips
                FlowLayout(spacing: OverwatchTheme.Spacing.sm) {
                    ForEach(Array(Self.suggestions.enumerated()), id: \.element.name) { index, suggestion in
                        HabitChip(
                            name: suggestion.name,
                            emoji: suggestion.emoji,
                            isSelected: selectedHabits.contains(suggestion.name)
                        ) {
                            if selectedHabits.contains(suggestion.name) {
                                selectedHabits.remove(suggestion.name)
                            } else {
                                selectedHabits.insert(suggestion.name)
                            }
                        }
                        .staggerEffect(index: index, delayPerItem: 0.08)
                    }
                }
                .padding(.horizontal, OverwatchTheme.Spacing.sm)

                // Actions
                VStack(spacing: OverwatchTheme.Spacing.md) {
                    HUDButton(
                        label: selectedHabits.isEmpty ? "SKIP" : "CONTINUE (\(selectedHabits.count) SELECTED)"
                    ) {
                        createSelectedHabits()
                        onNext()
                    }
                }
            }
            .padding(.vertical, OverwatchTheme.Spacing.xl)
        }
        .frame(maxWidth: 460)
    }

    private func createSelectedHabits() {
        for (index, suggestion) in Self.suggestions.enumerated() {
            guard selectedHabits.contains(suggestion.name) else { continue }
            let habit = Habit(
                name: suggestion.name,
                emoji: suggestion.emoji,
                category: suggestion.category,
                targetFrequency: 7,
                sortOrder: index
            )
            modelContext.insert(habit)
        }
    }
}

// MARK: - Step 4: Operational

private struct OperationalStep: View {
    var onComplete: () -> Void

    @State private var titleVisible = false
    @State private var glowBloom = false

    var body: some View {
        VStack(spacing: OverwatchTheme.Spacing.xl) {
            Text("YOU ARE NOW OPERATIONAL")
                .font(Typography.title)
                .foregroundStyle(OverwatchTheme.accentSecondary)
                .tracking(4)
                .textGlow(OverwatchTheme.accentSecondary, radius: titleVisible ? 32 : 8)
                .opacity(titleVisible ? 1 : 0)
                .scaleEffect(titleVisible ? 1.0 : 0.9)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                titleVisible = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                glowBloom = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete()
            }
        }
    }
}

// MARK: - Habit Chip

private struct HabitChip: View {
    let name: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    @State private var pulseActive = false

    var body: some View {
        Button(action: {
            pulseActive = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pulseActive = false
            }
        }) {
            HStack(spacing: OverwatchTheme.Spacing.sm) {
                Text(emoji)
                    .font(.system(size: 14))
                Text(name.uppercased())
                    .font(Typography.hudLabel)
                    .foregroundStyle(isSelected ? OverwatchTheme.textPrimary : OverwatchTheme.textSecondary)
                    .tracking(1.2)
            }
            .padding(.horizontal, OverwatchTheme.Spacing.md)
            .padding(.vertical, OverwatchTheme.Spacing.sm)
            .background(
                HUDFrameShape(chamferSize: 6)
                    .fill(isSelected ? OverwatchTheme.accentCyan.opacity(0.15) : OverwatchTheme.surface)
            )
            .overlay(
                HUDFrameShape(chamferSize: 6)
                    .stroke(
                        isSelected ? OverwatchTheme.accentCyan : OverwatchTheme.accentCyan.opacity(0.3),
                        lineWidth: isSelected ? 1.5 : 0.8
                    )
            )
            .clipShape(HUDFrameShape(chamferSize: 6))
        }
        .buttonStyle(.plain)
        .glowPulseEffect(trigger: pulseActive, color: OverwatchTheme.accentCyan)
        .animation(Animations.quick, value: isSelected)
    }
}

// MARK: - HUD Button

private struct HUDButton: View {
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.textPrimary)
                .tracking(2)
                .padding(.horizontal, OverwatchTheme.Spacing.xl)
                .padding(.vertical, OverwatchTheme.Spacing.md)
                .background(
                    HUDFrameShape(chamferSize: 8)
                        .fill(isHovered ? OverwatchTheme.accentCyan.opacity(0.2) : OverwatchTheme.surface)
                )
                .overlay(
                    HUDFrameShape(chamferSize: 8)
                        .stroke(OverwatchTheme.accentCyan.opacity(0.7), lineWidth: 1.2)
                )
                .clipShape(HUDFrameShape(chamferSize: 8))
                .shadow(color: OverwatchTheme.accentCyan.opacity(isHovered ? 0.4 : 0.15), radius: 8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Animations.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Progress Dots

private struct ProgressDots: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep
                          ? OverwatchTheme.accentCyan
                          : step < currentStep
                          ? OverwatchTheme.accentCyan.opacity(0.4)
                          : OverwatchTheme.textSecondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .shadow(
                        color: step == currentStep
                            ? OverwatchTheme.accentCyan.opacity(0.6)
                            : .clear,
                        radius: 4
                    )
                    .animation(Animations.quick, value: currentStep)
            }
        }
    }
}

// MARK: - Flow Layout (for habit chips)

/// Simple horizontal wrapping layout for habit suggestion chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { total, row in
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return total + rowHeight + (total > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            let rowWidth = row.reduce(CGFloat.zero) { total, sub in
                total + sub.sizeThatFits(.unspecified).width + (total > 0 ? spacing : 0)
            }
            var x = bounds.minX + (bounds.width - rowWidth) / 2 // center

            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width + spacing > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([subview])
                currentWidth = size.width
            } else {
                rows[rows.count - 1].append(subview)
                currentWidth += size.width + (currentWidth > 0 ? spacing : 0)
            }
        }
        return rows
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
        .modelContainer(for: [Habit.self, HabitEntry.self], inMemory: true)
}
