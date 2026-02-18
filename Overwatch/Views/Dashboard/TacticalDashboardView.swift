import SwiftUI
import SwiftData

struct TacticalDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()
    @State private var sectionsVisible = false
    @State private var showingAddHabit = false

    var body: some View {
        ScrollView {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                headerSection
                    .materializeEffect(isVisible: sectionsVisible, delay: 0)

                todaysOpsSection
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.12)

                biometricStatusSection
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.24)

                heatMapPreview
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.36)

                fieldLogSection
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.48)
            }
            .padding(OverwatchTheme.Spacing.xl)
        }
        .onAppear {
            viewModel.loadData(from: modelContext)
            sectionsVisible = true
        }
        .sheet(isPresented: $showingAddHabit) {
            AddHabitSheet { name, emoji in
                viewModel.addHabit(name: name, emoji: emoji, to: modelContext)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                    Text("OVERWATCH")
                        .font(Typography.largeTitle)
                        .tracking(6)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .textGlow(OverwatchTheme.accentCyan, radius: 20)

                    Text("TACTICAL PERFORMANCE SYSTEM")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                        .tracking(5)
                        .textGlow(OverwatchTheme.accentCyan, radius: 4)
                }

                Spacer()

                syncStatusBadge
            }

            HUDDivider(color: OverwatchTheme.accentCyan)
        }
    }

    private var syncStatusBadge: some View {
        HStack(spacing: OverwatchTheme.Spacing.xs) {
            Circle()
                .fill(syncStatusColor)
                .frame(width: 8, height: 8)
                .pulsingGlow(color: syncStatusColor, radius: 6)

            Text(syncStatusText)
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.md)
        .padding(.vertical, OverwatchTheme.Spacing.sm)
        .background(OverwatchTheme.surface)
        .clipShape(.capsule)
        .overlay(Capsule().stroke(syncStatusColor.opacity(0.5), lineWidth: 1))
        .hudGlow(color: syncStatusColor)
    }

    private var syncStatusColor: Color {
        switch viewModel.syncStatus {
        case .idle: OverwatchTheme.textSecondary
        case .syncing: OverwatchTheme.accentPrimary
        case .synced: OverwatchTheme.accentSecondary
        case .error: OverwatchTheme.alert
        }
    }

    private var syncStatusText: String {
        switch viewModel.syncStatus {
        case .idle: "IDLE"
        case .syncing: "SYNCING"
        case .synced(let date):
            "SYNCED \(DateFormatters.relative.localizedString(for: date, relativeTo: .now))"
        case .error: "ERROR"
        }
    }

    // MARK: - TODAY'S OPS (Hero Section)

    private var todaysOpsSection: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            // Section header with summary and add button
            HStack {
                sectionLabel("TODAY'S OPS")

                Spacer()

                // Today's completion summary
                HStack(spacing: OverwatchTheme.Spacing.xs) {
                    Text("\(viewModel.habitSummary.completedToday)")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.accentSecondary)
                        .contentTransition(.numericText())
                    Text("/")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                    Text("\(viewModel.habitSummary.totalHabits)")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .contentTransition(.numericText())
                }

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
                    .overlay(
                        HUDFrameShape(chamferSize: 6)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Habit toggle buttons
            if viewModel.trackedHabits.isEmpty {
                emptyHabitsState
            } else {
                habitToggleGrid
            }
        }
    }

    private var habitToggleGrid: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            ForEach(Array(viewModel.trackedHabits.enumerated()), id: \.element.id) { index, habit in
                HabitToggleButton(
                    habit: habit,
                    isExpanded: viewModel.expandedHabitID == habit.id,
                    onToggle: {
                        withAnimation(Animations.dataStream) {
                            viewModel.toggleHabitCompletion(habit.id, in: modelContext)
                        }
                    },
                    onExpand: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.toggleExpandedHabit(habit.id)
                        }
                    },
                    onConfirm: { value, notes in
                        withAnimation(Animations.dataStream) {
                            viewModel.confirmHabitEntry(
                                habit.id,
                                value: value,
                                notes: notes,
                                in: modelContext
                            )
                        }
                    }
                )
                .staggerEffect(index: index, delayPerItem: 0.08)
            }
        }
    }

    private var emptyHabitsState: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.md) {
                Text("NO ACTIVE OPERATIONS")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.3))
                    .tracking(3)
                    .textGlow(OverwatchTheme.accentCyan, radius: 3)

                Text("Add habits to begin tracking daily operations")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)

                Button {
                    showingAddHabit = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("ADD FIRST OPERATION")
                            .font(Typography.hudLabel)
                            .tracking(1)
                    }
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(OverwatchTheme.accentCyan.opacity(0.08))
                    .clipShape(HUDFrameShape(chamferSize: 8))
                    .overlay(
                        HUDFrameShape(chamferSize: 8)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OverwatchTheme.Spacing.lg)
        }
    }

    // MARK: - BIOMETRIC STATUS (Compact Strip)

    private var biometricStatusSection: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("BIOMETRIC STATUS")

            CompactWhoopStrip(
                metrics: viewModel.whoopMetrics,
                hasData: viewModel.hasWhoopData,
                isExpanded: $viewModel.isWhoopExpanded
            )
        }
    }

    // MARK: - Heat Map Preview (30-day mini)

    private var heatMapPreview: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("PERFORMANCE MATRIX")

            TacticalCard {
                VStack(spacing: OverwatchTheme.Spacing.md) {
                    HStack {
                        Image(systemName: "square.grid.3x3.fill")
                            .foregroundStyle(OverwatchTheme.accentCyan)
                            .symbolRenderingMode(.hierarchical)
                            .textGlow(OverwatchTheme.accentCyan, radius: 4)
                        Text("30-DAY HEAT MAP")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.accentCyan)
                            .tracking(3)
                            .textGlow(OverwatchTheme.accentCyan, radius: 3)
                        Spacer()
                        Text("VIEW FULL →")
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                            .tracking(1)
                    }

                    // Mini heat map placeholder — will be replaced in Phase 4.4
                    miniHeatMapGrid
                }
            }
        }
    }

    /// 30-day mini heat map grid (4 rows × ~8 columns) using Canvas for performance.
    /// Shows aggregate daily completion as color intensity.
    /// Replaced by full HabitHeatMapView in Phase 4.4.
    private var miniHeatMapGrid: some View {
        Canvas { context, size in
            let cols = 8
            let rows = 4
            let spacing: CGFloat = 3
            let cellSize = min(
                (size.width - CGFloat(cols - 1) * spacing) / CGFloat(cols),
                (size.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            )

            let totalHabits = max(viewModel.habitSummary.totalHabits, 1)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)

            for row in 0..<rows {
                for col in 0..<cols {
                    let dayIndex = row * cols + col
                    guard dayIndex < 30 else { continue }

                    let x = CGFloat(col) * (cellSize + spacing)
                    let y = CGFloat(row) * (cellSize + spacing)
                    let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)

                    // Calculate completion for this day from tracked habits
                    let dayDate = calendar.date(byAdding: .day, value: -(29 - dayIndex), to: today)!
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayDate)!
                    let completedCount = viewModel.trackedHabits.filter { habit in
                        // Rough approximation — uses weekly/monthly rate as proxy
                        // Real implementation will query HabitEntry directly (Phase 4.4)
                        habit.completedToday && dayIndex == 29
                    }.count

                    let rate = dayIndex == 29
                        ? Double(completedCount) / Double(totalHabits)
                        : Double(dayIndex % 3 == 0 ? 0 : dayIndex) / 30.0 // Placeholder gradient

                    let color = heatMapCellColor(rate: rate)
                    let roundedRect = Path(roundedRect: rect, cornerRadius: 2)
                    context.fill(roundedRect, with: .color(color))

                    // Glow on high-completion cells
                    if rate > 0.8 {
                        context.drawLayer { ctx in
                            ctx.addFilter(.shadow(
                                color: OverwatchTheme.accentCyan.opacity(0.3),
                                radius: 3
                            ))
                            ctx.fill(roundedRect, with: .color(color))
                        }
                    }
                }
            }
        }
        .frame(height: 64)
        .frame(maxWidth: .infinity)
    }

    private func heatMapCellColor(rate: Double) -> Color {
        switch rate {
        case 0:
            Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
        case 0.01..<0.34:
            OverwatchTheme.accentCyan.opacity(0.2)
        case 0.34..<0.67:
            OverwatchTheme.accentCyan.opacity(0.5)
        case 0.67..<1.0:
            OverwatchTheme.accentCyan.opacity(0.8)
        default:
            OverwatchTheme.accentCyan
        }
    }

    // MARK: - FIELD LOG (Quick Input)

    private var fieldLogSection: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("FIELD LOG")

            QuickInputView(viewModel: viewModel)
        }
    }

    // MARK: - Shared Components

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            Rectangle()
                .fill(OverwatchTheme.accentCyan.opacity(0.6))
                .frame(width: 3, height: 12)
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.6), radius: 4)
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.2), radius: 12)

            Text("// \(text)")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(4)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Spacer()
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
                        .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.textSecondary))

                    Button("ACTIVATE") {
                        onAdd(
                            name.trimmingCharacters(in: .whitespaces),
                            emoji.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.accentCyan))
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

#Preview {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        ScanLineOverlay().ignoresSafeArea()
        TacticalDashboardView()
    }
    .modelContainer(for: [Habit.self, HabitEntry.self, JournalEntry.self, WhoopCycle.self],
                    inMemory: true)
    .frame(width: 900, height: 800)
}
