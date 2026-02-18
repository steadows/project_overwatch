import SwiftUI

/// Large HUD-styled habit toggle button with tap-to-expand inline panel.
///
/// States: incomplete (dim border) → completed (bright glow + checkmark).
/// Tap toggles completion. Long-press or chevron tap expands detail panel
/// with value/notes fields and confirm/cancel buttons.
struct HabitToggleButton: View {
    let habit: DashboardViewModel.TrackedHabit
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void
    let onConfirm: (Double?, String) -> Void

    @State private var particleTrigger = false
    @State private var glowTrigger = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var valueText = ""
    @State private var notesText = ""

    private var isComplete: Bool { habit.completedToday }

    var body: some View {
        VStack(spacing: 0) {
            mainButton
            expandedPanel
        }
    }

    // MARK: - Main Button

    private var mainButton: some View {
        HStack(spacing: OverwatchTheme.Spacing.md) {
            // Emoji
            Text(habit.emoji.isEmpty ? "●" : habit.emoji)
                .font(.system(size: 24))
                .frame(width: 36)

            // Name + status
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name.uppercased())
                    .font(Typography.hudLabel)
                    .foregroundStyle(isComplete ? OverwatchTheme.textPrimary : OverwatchTheme.textSecondary)
                    .tracking(2)
                    .textGlow(isComplete ? OverwatchTheme.accentCyan : .clear, radius: 3)

                HStack(spacing: OverwatchTheme.Spacing.xs) {
                    Text(String(format: "%.0f%%", habit.weeklyRate * 100))
                        .font(Typography.metricTiny)
                        .foregroundStyle(rateColor(habit.weeklyRate))
                    Text("7D")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.5))
                }
            }

            Spacer()

            // Completion indicator
            completionIndicator

            // Expand chevron
            Button(action: onExpand) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.lg)
        .padding(.vertical, OverwatchTheme.Spacing.md)
        .background(OverwatchTheme.surfaceTranslucent)
        .clipShape(HUDFrameShape(chamferSize: 10))
        .overlay(
            HUDFrameShape(chamferSize: 10)
                .stroke(
                    isComplete
                        ? OverwatchTheme.accentCyan.opacity(0.7)
                        : OverwatchTheme.accentCyan.opacity(0.25),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: isComplete ? OverwatchTheme.accentCyan.opacity(0.3) : .clear,
            radius: isComplete ? 8 : 0
        )
        .shadow(
            color: isComplete ? OverwatchTheme.accentCyan.opacity(0.12) : .clear,
            radius: isComplete ? 20 : 0
        )
        .glowPulseEffect(trigger: glowTrigger, color: OverwatchTheme.accentSecondary)
        .particleScatter(
            trigger: $particleTrigger,
            particleCount: 10,
            burstRadius: 50,
            color: OverwatchTheme.accentSecondary
        )
        .contentShape(HUDFrameShape(chamferSize: 10))
        .onTapGesture {
            onToggle()
            if !isComplete {
                // Becoming complete — fire celebration
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    checkmarkScale = 1
                }
                particleTrigger = true
                glowTrigger = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    glowTrigger = false
                }
            } else {
                // Uncompleting
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    checkmarkScale = 0
                }
            }
        }
    }

    // MARK: - Completion Indicator

    private var completionIndicator: some View {
        ZStack {
            Circle()
                .stroke(
                    isComplete
                        ? OverwatchTheme.accentSecondary.opacity(0.6)
                        : OverwatchTheme.accentCyan.opacity(0.2),
                    lineWidth: 1.5
                )
                .frame(width: 24, height: 24)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(OverwatchTheme.accentSecondary)
                    .scaleEffect(checkmarkScale)
                    .textGlow(OverwatchTheme.accentSecondary, radius: 6)
            }
        }
        .onAppear {
            checkmarkScale = isComplete ? 1 : 0
        }
        .onChange(of: habit.completedToday) { _, completed in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                checkmarkScale = completed ? 1 : 0
            }
        }
    }

    // MARK: - Expanded Panel

    @ViewBuilder
    private var expandedPanel: some View {
        if isExpanded {
            VStack(spacing: OverwatchTheme.Spacing.md) {
                HUDDivider(color: OverwatchTheme.accentCyan.opacity(0.3))

                // Value field
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                    Text("VALUE")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                        .tracking(2)
                        .textGlow(OverwatchTheme.accentCyan, radius: 2)

                    TextField("e.g., 3L, 30 min", text: $valueText)
                        .textFieldStyle(.plain)
                        .font(Typography.commandLine)
                        .foregroundStyle(OverwatchTheme.textPrimary)
                        .padding(OverwatchTheme.Spacing.sm)
                        .background(OverwatchTheme.surface)
                        .clipShape(HUDFrameShape(chamferSize: 6))
                        .overlay(
                            HUDFrameShape(chamferSize: 6)
                                .stroke(OverwatchTheme.accentCyan.opacity(0.2), lineWidth: 1)
                        )
                }

                // Notes field
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                    Text("NOTES")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                        .tracking(2)
                        .textGlow(OverwatchTheme.accentCyan, radius: 2)

                    TextField("Optional notes...", text: $notesText)
                        .textFieldStyle(.plain)
                        .font(Typography.commandLine)
                        .foregroundStyle(OverwatchTheme.textPrimary)
                        .padding(OverwatchTheme.Spacing.sm)
                        .background(OverwatchTheme.surface)
                        .clipShape(HUDFrameShape(chamferSize: 6))
                        .overlay(
                            HUDFrameShape(chamferSize: 6)
                                .stroke(OverwatchTheme.accentCyan.opacity(0.2), lineWidth: 1)
                        )
                }

                // Actions
                HStack(spacing: OverwatchTheme.Spacing.md) {
                    Spacer()

                    Button("CANCEL") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            onExpand() // collapses
                        }
                        valueText = ""
                        notesText = ""
                    }
                    .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.textSecondary))

                    Button("CONFIRM") {
                        let value = Double(valueText.filter { $0.isNumber || $0 == "." })
                        onConfirm(value, notesText)
                        valueText = ""
                        notesText = ""
                    }
                    .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.accentCyan))
                }
            }
            .padding(.horizontal, OverwatchTheme.Spacing.lg)
            .padding(.bottom, OverwatchTheme.Spacing.md)
            .padding(.top, OverwatchTheme.Spacing.sm)
            .slideRevealEffect(isExpanded: isExpanded)
        }
    }

    // MARK: - Helpers

    private func rateColor(_ rate: Double) -> Color {
        switch rate {
        case 0.67...: OverwatchTheme.accentSecondary
        case 0.34..<0.67: OverwatchTheme.accentPrimary
        default: OverwatchTheme.alert
        }
    }
}

// MARK: - Compact HUD Button Style

struct HUDCompactButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.hudLabel)
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.15 : 0.06))
            .clipShape(HUDFrameShape(chamferSize: 6))
            .overlay(
                HUDFrameShape(chamferSize: 6)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Animations.quick, value: configuration.isPressed)
    }
}

#Preview("Habit Toggle") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        VStack(spacing: 12) {
            HabitToggleButton(
                habit: .init(
                    id: UUID(),
                    name: "Water",
                    emoji: "💧",
                    completedToday: false,
                    weeklyRate: 0.71,
                    monthlyRate: 0.63
                ),
                isExpanded: false,
                onToggle: {},
                onExpand: {},
                onConfirm: { _, _ in }
            )

            HabitToggleButton(
                habit: .init(
                    id: UUID(),
                    name: "Exercise",
                    emoji: "🏋️",
                    completedToday: true,
                    weeklyRate: 0.86,
                    monthlyRate: 0.80
                ),
                isExpanded: false,
                onToggle: {},
                onExpand: {},
                onConfirm: { _, _ in }
            )

            HabitToggleButton(
                habit: .init(
                    id: UUID(),
                    name: "Meditation",
                    emoji: "🧘",
                    completedToday: false,
                    weeklyRate: 0.29,
                    monthlyRate: 0.20
                ),
                isExpanded: true,
                onToggle: {},
                onExpand: {},
                onConfirm: { _, _ in }
            )
        }
        .padding()
        .frame(width: 400)
    }
    .frame(width: 500, height: 600)
}
