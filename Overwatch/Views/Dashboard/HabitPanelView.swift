import SwiftUI
import SwiftData

/// Full habit tracking panel — shows all tracked habits with today toggle,
/// 7-day and 30-day completion rates, and add habit functionality.
struct HabitPanelView: View {
    var viewModel: DashboardViewModel
    var modelContext: ModelContext
    @State private var showingAddHabit = false

    var body: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.md) {
                panelHeader

                if viewModel.trackedHabits.isEmpty {
                    emptyState
                } else {
                    columnHeaders
                    habitList
                }
            }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddHabitSheet { name, emoji in
                viewModel.addHabit(name: name, emoji: emoji, to: modelContext)
            }
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            HStack(spacing: OverwatchTheme.Spacing.xs) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .textGlow(OverwatchTheme.accentCyan, radius: 4)
                Text("ACTIVE OPERATIONS")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .tracking(3)
                    .textGlow(OverwatchTheme.accentCyan, radius: 3)
            }

            Spacer()

            // Habit count
            Text("\(viewModel.trackedHabits.count)")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)

            // Add button
            Button {
                showingAddHabit = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                    Text("ADD")
                        .font(Typography.hudLabel)
                        .tracking(1)
                }
                .foregroundStyle(OverwatchTheme.accentCyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(OverwatchTheme.accentCyan.opacity(0.08))
                .clipShape(HUDFrameShape(chamferSize: 6))
                .overlay(HUDFrameShape(chamferSize: 6).stroke(OverwatchTheme.accentCyan.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 28) // emoji column
            Text("OPERATION")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("TODAY")
                .frame(width: 48)
            Text("7 DAY")
                .frame(width: 90)
            Text("30 DAY")
                .frame(width: 90)
        }
        .font(Typography.hudLabel)
        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
        .tracking(2)
        .textGlow(OverwatchTheme.accentCyan, radius: 2)
    }

    // MARK: - Habit List

    private var habitList: some View {
        VStack(spacing: 2) {
            ForEach(viewModel.trackedHabits) { habit in
                HabitRow(
                    habit: habit,
                    onToggle: {
                        withAnimation(Animations.dataStream) {
                            viewModel.toggleHabitCompletion(habit.id, in: modelContext)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            Text("NO ACTIVE OPERATIONS")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.3))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Text("Add habits to begin tracking")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)

            Button {
                showingAddHabit = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("ADD FIRST HABIT")
                        .font(Typography.hudLabel)
                        .tracking(1)
                }
                .foregroundStyle(OverwatchTheme.accentCyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(OverwatchTheme.accentCyan.opacity(0.08))
                .clipShape(HUDFrameShape(chamferSize: 8))
                .overlay(HUDFrameShape(chamferSize: 8).stroke(OverwatchTheme.accentCyan.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xl)
    }
}

// MARK: - Habit Row

private struct HabitRow: View {
    let habit: DashboardViewModel.TrackedHabit
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Emoji
            Text(habit.emoji.isEmpty ? "●" : habit.emoji)
                .font(.system(size: 14))
                .frame(width: 28)

            // Name
            Text(habit.name.uppercased())
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Today toggle
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(
                            habit.completedToday
                                ? OverwatchTheme.accentSecondary.opacity(0.6)
                                : OverwatchTheme.accentCyan.opacity(0.25),
                            lineWidth: 1
                        )

                    if habit.completedToday {
                        Circle()
                            .fill(OverwatchTheme.accentSecondary)
                            .padding(3)
                            .shadow(color: OverwatchTheme.accentSecondary.opacity(0.7), radius: 4)
                            .shadow(color: OverwatchTheme.accentSecondary.opacity(0.3), radius: 12)
                    }
                }
                .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .frame(width: 48)

            // Weekly completion
            completionCell(rate: habit.weeklyRate)
                .frame(width: 90)

            // Monthly completion
            completionCell(rate: habit.monthlyRate)
                .frame(width: 90)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(OverwatchTheme.surfaceElevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 2))
    }

    private func completionCell(rate: Double) -> some View {
        HStack(spacing: 6) {
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(OverwatchTheme.background)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(rateColor(rate))
                        .frame(width: geo.size.width * min(rate, 1))
                        .shadow(color: rateColor(rate).opacity(0.5), radius: 2)
                }
            }
            .frame(width: 36, height: 3)

            // Percentage
            Text(String(format: "%.0f%%", rate * 100))
                .font(Typography.metricTiny)
                .foregroundStyle(rateColor(rate))
                .monospacedDigit()
        }
    }

    private func rateColor(_ rate: Double) -> Color {
        switch rate {
        case 0.67...: OverwatchTheme.accentSecondary
        case 0.34..<0.67: OverwatchTheme.accentPrimary
        default: OverwatchTheme.alert
        }
    }
}

// MARK: - Add Habit Sheet

private struct AddHabitSheet: View {
    let onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = ""

    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            OverwatchTheme.background.ignoresSafeArea()
            ScanLineOverlay().ignoresSafeArea()

            VStack(spacing: OverwatchTheme.Spacing.xl) {
                // Header
                VStack(spacing: OverwatchTheme.Spacing.sm) {
                    Text("NEW OPERATION")
                        .font(Typography.title)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(4)
                        .textGlow(OverwatchTheme.accentCyan, radius: 12)

                    HUDDivider(color: OverwatchTheme.accentCyan)
                }

                // Form
                VStack(spacing: OverwatchTheme.Spacing.lg) {
                    formField(label: "DESIGNATION", placeholder: "Habit name", text: $name)
                    formField(label: "ICON", placeholder: "Emoji (optional)", text: $emoji)
                }

                Spacer()

                // Actions
                HStack(spacing: OverwatchTheme.Spacing.md) {
                    Button("CANCEL") { dismiss() }
                        .buttonStyle(HUDButtonStyle(color: OverwatchTheme.textSecondary))

                    Button("ACTIVATE") {
                        onAdd(
                            name.trimmingCharacters(in: .whitespaces),
                            emoji.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .buttonStyle(HUDButtonStyle(color: OverwatchTheme.accentCyan))
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : 0.4)
                }
            }
            .padding(OverwatchTheme.Spacing.xl)
        }
        .frame(width: 400, height: 320)
    }

    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
            Text(label)
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 2)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Typography.commandLine)
                .foregroundStyle(OverwatchTheme.textPrimary)
                .padding(OverwatchTheme.Spacing.sm)
                .background(OverwatchTheme.surface)
                .clipShape(HUDFrameShape(chamferSize: 8))
                .overlay(
                    HUDFrameShape(chamferSize: 8)
                        .stroke(OverwatchTheme.accentCyan.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - HUD Button Style

private struct HUDButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.hudLabel)
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(color.opacity(configuration.isPressed ? 0.15 : 0.06))
            .clipShape(HUDFrameShape(chamferSize: 8))
            .overlay(
                HUDFrameShape(chamferSize: 8)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Animations.quick, value: configuration.isPressed)
    }
}
