import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Habits View

/// Full habit management page — master-detail layout with CRUD,
/// category filtering, drag-and-drop reordering, and detail panel.
struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HabitsViewModel()
    @State private var activeSheet: SheetMode?
    @State private var showingDeleteAlert = false
    @State private var habitToDelete: HabitsViewModel.HabitItem?
    @State private var draggedHabitID: UUID?
    @State private var sectionsVisible = false
    @State private var journalExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            headerArea
                .materializeEffect(isVisible: sectionsVisible, delay: 0)

            if viewModel.habits.isEmpty {
                Spacer()
                emptyState
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.12)
                Spacer()
            } else {
                categoryFilter
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.08)
                    .padding(.horizontal, OverwatchTheme.Spacing.xl)
                    .padding(.bottom, OverwatchTheme.Spacing.md)

                masterDetailLayout

                journalToggleBar
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.16)

                if journalExpanded {
                    JournalTimelineView()
                        .padding(.horizontal, OverwatchTheme.Spacing.xl)
                        .frame(minHeight: 200, maxHeight: 320)
                        .slideRevealEffect(isExpanded: journalExpanded)
                }
            }
        }
        .onAppear {
            viewModel.loadData(from: modelContext)
            sectionsVisible = true
        }
        .onChange(of: viewModel.selectedTrendRange) { _, _ in
            viewModel.loadTrendChartData(from: modelContext)
        }
        .onChange(of: viewModel.showWhoopOverlay) { _, _ in
            viewModel.loadTrendChartData(from: modelContext)
        }
        .sheet(item: $activeSheet) { mode in
            switch mode {
            case .add:
                HabitFormSheet(mode: .add) { name, emoji, category, frequency, isQuant, unit in
                    viewModel.addHabit(
                        name: name, emoji: emoji, category: category,
                        targetFrequency: frequency, isQuantitative: isQuant,
                        unitLabel: unit, to: modelContext
                    )
                }
            case .edit(let habit):
                HabitFormSheet(mode: .edit(habit)) { name, emoji, category, frequency, isQuant, unit in
                    viewModel.updateHabit(
                        habit.id, name: name, emoji: emoji, category: category,
                        targetFrequency: frequency, isQuantitative: isQuant,
                        unitLabel: unit, in: modelContext
                    )
                }
            }
        }
        .alert(
            "DECOMMISSION OPERATION?",
            isPresented: $showingDeleteAlert,
            presenting: habitToDelete
        ) { habit in
            Button("CONFIRM", role: .destructive) {
                withAnimation(Animations.dataStream) {
                    viewModel.deleteHabit(habit.id, from: modelContext)
                }
            }
            Button("CANCEL", role: .cancel) {}
        } message: { habit in
            Text("All entries for \"\(habit.name)\" will be permanently purged. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                    Text("HABITS")
                        .font(Typography.largeTitle)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(6)
                        .textGlow(OverwatchTheme.accentCyan, radius: 20)

                    Text("OPERATION MANAGEMENT")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.45))
                        .tracking(5)
                        .textGlow(OverwatchTheme.accentCyan, radius: 4)
                }

                Spacer()

                // Habit count
                HStack(spacing: OverwatchTheme.Spacing.xs) {
                    Text("\(viewModel.habits.count)")
                        .font(Typography.metricMedium)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .contentTransition(.numericText())
                    Text("OPS")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(2)
                }

                // Add button
                Button {
                    activeSheet = .add
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("NEW OP")
                            .font(Typography.hudLabel)
                            .tracking(1)
                    }
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(OverwatchTheme.accentCyan.opacity(0.08))
                    .clipShape(HUDFrameShape(chamferSize: 6))
                    .overlay(
                        HUDFrameShape(chamferSize: 6)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            HUDDivider(color: OverwatchTheme.accentCyan)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.xl)
        .padding(.top, OverwatchTheme.Spacing.xl)
        .padding(.bottom, OverwatchTheme.Spacing.sm)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OverwatchTheme.Spacing.sm) {
                CategoryChip(
                    label: "ALL",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    withAnimation(Animations.quick) {
                        viewModel.selectedCategory = nil
                    }
                }

                ForEach(viewModel.availableCategories, id: \.self) { category in
                    CategoryChip(
                        label: category.uppercased(),
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        withAnimation(Animations.quick) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    // MARK: - Master-Detail Layout

    private var masterDetailLayout: some View {
        HStack(alignment: .top, spacing: OverwatchTheme.Spacing.lg) {
            // Left: habit list
            ScrollView {
                VStack(spacing: OverwatchTheme.Spacing.sm) {
                    ForEach(Array(viewModel.filteredHabits.enumerated()), id: \.element.id) { index, habit in
                        HabitListRow(
                            habit: habit,
                            isSelected: viewModel.selectedHabitID == habit.id,
                            onSelect: {
                                withAnimation(Animations.quick) {
                                    viewModel.selectedHabitID = habit.id
                                }
                                viewModel.loadSelectedHabitHeatMap(from: modelContext)
                            },
                            onEdit: {
                                activeSheet = .edit(habit)
                            },
                            onDelete: {
                                habitToDelete = habit
                                showingDeleteAlert = true
                            }
                        )
                        .opacity(draggedHabitID == habit.id ? 0.4 : 1)
                        .onDrag {
                            draggedHabitID = habit.id
                            return NSItemProvider(object: habit.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: HabitReorderDropDelegate(
                                targetHabitID: habit.id,
                                draggedHabitID: $draggedHabitID,
                                onMove: { sourceID in
                                    withAnimation(Animations.quick) {
                                        viewModel.moveHabit(from: sourceID, toPositionOf: habit.id)
                                    }
                                },
                                onDrop: {
                                    viewModel.commitReorder(in: modelContext)
                                }
                            )
                        )
                        .staggerEffect(index: index, delayPerItem: 0.06)
                    }
                }
                .padding(.bottom, OverwatchTheme.Spacing.xl)
            }
            .frame(minWidth: 280, idealWidth: 360, maxWidth: 400)

            // Right: detail panel
            ScrollView {
                HabitDetailPanel(
                    habit: viewModel.selectedHabit,
                    heatMapDays: viewModel.selectedHabitHeatMapDays,
                    trendChartData: viewModel.trendChartData,
                    trendDateRange: $viewModel.selectedTrendRange,
                    showWhoopOverlay: $viewModel.showWhoopOverlay,
                    onEdit: { habit in
                        activeSheet = .edit(habit)
                    }
                )
                .padding(.bottom, OverwatchTheme.Spacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.xl)
    }

    // MARK: - Journal Toggle Bar

    private var journalToggleBar: some View {
        Button {
            withAnimation(Animations.standard) {
                journalExpanded.toggle()
            }
        } label: {
            HStack(spacing: OverwatchTheme.Spacing.sm) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .light))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                    .rotationEffect(.degrees(journalExpanded ? 90 : 0))
                    .animation(Animations.quick, value: journalExpanded)

                Rectangle()
                    .fill(OverwatchTheme.accentCyan.opacity(0.5))
                    .frame(width: 3, height: 12)
                    .shadow(color: OverwatchTheme.accentCyan.opacity(0.4), radius: 3)

                Text("FIELD LOG")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.6))
                    .tracking(3)
                    .textGlow(OverwatchTheme.accentCyan, radius: 3)

                HUDDivider(color: OverwatchTheme.accentCyan)
            }
            .padding(.horizontal, OverwatchTheme.Spacing.xl)
            .padding(.vertical, OverwatchTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.lg) {
                Image(systemName: "target")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.2))
                    .shadow(color: OverwatchTheme.accentCyan.opacity(0.15), radius: 12)

                Text("NO ACTIVE OPERATIONS")
                    .font(Typography.title)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                    .tracking(4)
                    .textGlow(OverwatchTheme.accentCyan, radius: 8)

                Text("Add your first habit to begin tracking performance")
                    .font(Typography.caption)
                    .foregroundStyle(OverwatchTheme.textSecondary)

                Button {
                    activeSheet = .add
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("ESTABLISH FIRST OPERATION")
                            .font(Typography.hudLabel)
                            .tracking(1.5)
                    }
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
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
            .padding(.vertical, OverwatchTheme.Spacing.xxl)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.xl)
    }
}

// MARK: - Sheet Mode

private enum SheetMode: Identifiable {
    case add
    case edit(HabitsViewModel.HabitItem)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let item): "edit-\(item.id)"
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.hudLabel)
                .tracking(1.5)
                .foregroundStyle(
                    isSelected
                        ? OverwatchTheme.accentCyan
                        : OverwatchTheme.textSecondary
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected
                        ? OverwatchTheme.accentCyan.opacity(0.1)
                        : (isHovered ? OverwatchTheme.surfaceElevated : .clear)
                )
                .clipShape(HUDFrameShape(chamferSize: 5))
                .overlay(
                    HUDFrameShape(chamferSize: 5)
                        .stroke(
                            isSelected
                                ? OverwatchTheme.accentCyan.opacity(0.5)
                                : OverwatchTheme.accentCyan.opacity(isHovered ? 0.2 : 0.1),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected ? OverwatchTheme.accentCyan.opacity(0.2) : .clear,
                    radius: 6
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Habit List Row

private struct HabitListRow: View {
    let habit: HabitsViewModel.HabitItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: OverwatchTheme.Spacing.md) {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundStyle(OverwatchTheme.textSecondary.opacity(isHovered ? 0.5 : 0.2))

                // Emoji
                Text(habit.emoji.isEmpty ? "●" : habit.emoji)
                    .font(.system(size: 18))
                    .frame(width: 24)

                // Name + category
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name.uppercased())
                        .font(Typography.hudLabel)
                        .foregroundStyle(
                            isSelected ? OverwatchTheme.textPrimary : OverwatchTheme.textSecondary
                        )
                        .tracking(2)
                        .textGlow(isSelected ? OverwatchTheme.accentCyan : .clear, radius: 3)
                        .lineLimit(1)

                    Text(habit.category.uppercased())
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                        .tracking(1)
                }

                Spacer()

                // Streak badge
                if habit.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(OverwatchTheme.accentPrimary)
                        Text("\(habit.currentStreak)")
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.accentPrimary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(OverwatchTheme.accentPrimary.opacity(0.08))
                    .clipShape(.capsule)
                }

                // Weekly rate indicator
                rateIndicator(habit.weeklyRate)
                    .frame(width: 56)
            }
            .padding(.horizontal, OverwatchTheme.Spacing.md)
            .padding(.vertical, OverwatchTheme.Spacing.sm + 2)
            .background(
                isSelected
                    ? OverwatchTheme.surfaceElevated.opacity(0.6)
                    : (isHovered ? OverwatchTheme.surfaceElevated.opacity(0.3) : .clear)
            )
            .clipShape(HUDFrameShape(chamferSize: 8))
            .overlay(
                HUDFrameShape(chamferSize: 8)
                    .stroke(
                        isSelected
                            ? OverwatchTheme.accentCyan.opacity(0.5)
                            : OverwatchTheme.accentCyan.opacity(isHovered ? 0.2 : 0.08),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? OverwatchTheme.accentCyan.opacity(0.12) : .clear,
                radius: 8
            )
            .contentShape(HUDFrameShape(chamferSize: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Operation", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Decommission", systemImage: "trash")
            }
        }
    }

    private func rateIndicator(_ rate: Double) -> some View {
        HStack(spacing: 4) {
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(OverwatchTheme.background)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(rateColor(rate))
                        .frame(width: geo.size.width * min(rate, 1), height: 3)
                        .shadow(color: rateColor(rate).opacity(0.5), radius: 2)
                }
            }
            .frame(width: 24, height: 3)

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

// MARK: - Habit Detail Panel

private struct HabitDetailPanel: View {
    let habit: HabitsViewModel.HabitItem?
    let heatMapDays: [HeatMapDay]
    let trendChartData: HabitsViewModel.TrendChartData?
    @Binding var trendDateRange: HabitsViewModel.TrendDateRange
    @Binding var showWhoopOverlay: Bool
    var onEdit: ((HabitsViewModel.HabitItem) -> Void)?

    @State private var milestoneBurstTrigger = false
    @State private var panelVisible = false

    var body: some View {
        TacticalCard {
            if let habit {
                selectedContent(habit)
                    .onChange(of: habit.id) {
                        panelVisible = false
                        milestoneBurstTrigger = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            panelVisible = true
                            if HabitsViewModel.currentMilestone(for: habit.currentStreak) != nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    milestoneBurstTrigger = true
                                }
                            }
                        }
                    }
                    .onAppear {
                        panelVisible = true
                        if HabitsViewModel.currentMilestone(for: habit.currentStreak) != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                milestoneBurstTrigger = true
                            }
                        }
                    }
            } else {
                emptySelection
            }
        }
    }

    private func selectedContent(_ habit: HabitsViewModel.HabitItem) -> some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
            // Header
            detailHeader(habit)
                .materializeEffect(isVisible: panelVisible, delay: 0)

            HUDDivider()

            // Milestone celebration
            if let milestone = HabitsViewModel.currentMilestone(for: habit.currentStreak) {
                milestoneBanner(streak: habit.currentStreak, milestone: milestone)
                    .materializeEffect(isVisible: panelVisible, delay: 0.06)
            }

            // Goal status indicator
            goalStatusBanner(habit)
                .materializeEffect(isVisible: panelVisible, delay: 0.09)

            // Stats grid
            statsSection(habit)
                .materializeEffect(isVisible: panelVisible, delay: 0.12)

            HUDDivider()

            // Heat map
            heatMapSection(habit)
                .materializeEffect(isVisible: panelVisible, delay: 0.18)

            HUDDivider()

            // Trend chart
            if let trendData = trendChartData {
                HabitTrendChartView(
                    chartData: trendData,
                    dateRange: $trendDateRange,
                    showWhoopOverlay: $showWhoopOverlay
                )
                .materializeEffect(isVisible: panelVisible, delay: 0.24)
            }
        }
    }

    // MARK: - Header

    private func detailHeader(_ habit: HabitsViewModel.HabitItem) -> some View {
        HStack(spacing: OverwatchTheme.Spacing.md) {
            Text(habit.emoji.isEmpty ? "●" : habit.emoji)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                Text(habit.name.uppercased())
                    .font(Typography.title)
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .tracking(4)
                    .textGlow(OverwatchTheme.accentCyan, radius: 12)

                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    categoryBadge(habit.category)

                    if habit.isQuantitative {
                        modeBadge("QUANTITY", unit: habit.unitLabel)
                    }

                    frequencyBadge(habit.targetFrequency)
                }
            }

            Spacer()

            Button {
                onEdit?(habit)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .medium))
                    Text("EDIT OP")
                        .font(Typography.hudLabel)
                        .tracking(1)
                }
                .foregroundStyle(OverwatchTheme.accentCyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(OverwatchTheme.accentCyan.opacity(0.08))
                .clipShape(HUDFrameShape(chamferSize: 6))
                .overlay(
                    HUDFrameShape(chamferSize: 6)
                        .stroke(OverwatchTheme.accentCyan.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Milestone Banner

    private func milestoneBanner(streak: Int, milestone: Int) -> some View {
        let milestoneLabel: String = switch milestone {
        case 365: "YEAR-LONG STREAK"
        case 100: "CENTURY STREAK"
        case 30: "30-DAY STREAK"
        default: "7-DAY STREAK"
        }

        return HStack(spacing: OverwatchTheme.Spacing.md) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(OverwatchTheme.accentPrimary)
                .textGlow(OverwatchTheme.accentPrimary, radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(milestoneLabel)
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentPrimary)
                    .tracking(3)
                    .textGlow(OverwatchTheme.accentPrimary, radius: 4)

                Text("\(streak) CONSECUTIVE DAYS")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.6))
                    .monospacedDigit()
            }

            Spacer()

            Text("🔥")
                .font(.system(size: 28))
        }
        .padding(OverwatchTheme.Spacing.md)
        .background(OverwatchTheme.accentPrimary.opacity(0.06))
        .clipShape(HUDFrameShape(chamferSize: 8))
        .overlay(
            HUDFrameShape(chamferSize: 8)
                .stroke(OverwatchTheme.accentPrimary.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: OverwatchTheme.accentPrimary.opacity(0.15), radius: 8)
        .shadow(color: OverwatchTheme.accentPrimary.opacity(0.08), radius: 20)
        .particleScatter(
            trigger: $milestoneBurstTrigger,
            particleCount: 12,
            burstRadius: 50,
            color: OverwatchTheme.accentPrimary
        )
        .glowPulseEffect(trigger: milestoneBurstTrigger, color: OverwatchTheme.accentPrimary)
    }

    // MARK: - Stats Section

    private func statsSection(_ habit: HabitsViewModel.HabitItem) -> some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
            sectionLabel("// OPERATIONAL METRICS")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: OverwatchTheme.Spacing.md
            ) {
                MetricTile(
                    icon: "flame.fill",
                    label: "Current Streak",
                    value: "\(habit.currentStreak)",
                    color: habit.currentStreak > 0
                        ? OverwatchTheme.accentPrimary
                        : OverwatchTheme.textSecondary
                )

                MetricTile(
                    icon: "trophy.fill",
                    label: "Longest Streak",
                    value: "\(habit.longestStreak)",
                    color: habit.longestStreak > 0
                        ? OverwatchTheme.accentCyan
                        : OverwatchTheme.textSecondary
                )

                MetricTile(
                    icon: "checkmark.circle.fill",
                    label: "Total Entries",
                    value: "\(habit.totalCompletions)",
                    color: OverwatchTheme.accentCyan
                )

                MetricTile(
                    icon: "calendar.badge.clock",
                    label: "7-Day Rate",
                    value: String(format: "%.0f%%", habit.weeklyRate * 100),
                    color: rateColor(habit.weeklyRate),
                    progress: habit.weeklyRate
                )

                MetricTile(
                    icon: "calendar",
                    label: "30-Day Rate",
                    value: String(format: "%.0f%%", habit.monthlyRate * 100),
                    color: rateColor(habit.monthlyRate),
                    progress: habit.monthlyRate
                )

                MetricTile(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "All-Time Rate",
                    value: String(format: "%.0f%%", habit.allTimeRate * 100),
                    color: rateColor(habit.allTimeRate),
                    progress: habit.allTimeRate
                )
            }
        }
    }

    // MARK: - Heat Map Section

    private func heatMapSection(_ habit: HabitsViewModel.HabitItem) -> some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
            sectionLabel("// PERFORMANCE MATRIX")

            if heatMapDays.isEmpty {
                heatMapEmptyState
            } else {
                HabitHeatMapView(days: heatMapDays, mode: .full)
            }
        }
    }

    private var heatMapEmptyState: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))

            Text("INSUFFICIENT DATA")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                .tracking(2)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Text("Log more entries to see the performance matrix")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }

    // MARK: - Empty Selection

    private var emptySelection: some View {
        VStack(spacing: OverwatchTheme.Spacing.lg) {
            Image(systemName: "target")
                .font(.system(size: 42, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.1), radius: 8)

            Text("SELECT AN OPERATION")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Text("Choose a habit from the list to view performance data")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl * 2)
    }

    // MARK: - Goal Status Banner

    private func goalStatusBanner(_ habit: HabitsViewModel.HabitItem) -> some View {
        let avgRate = (habit.weeklyRate + habit.monthlyRate) / 2.0
        let status: (label: String, icon: String, color: Color) = {
            switch avgRate {
            case 1.0...: ("ON TARGET", "checkmark.shield.fill", OverwatchTheme.accentSecondary)
            case 0.5..<1.0: ("APPROACHING TARGET", "exclamationmark.triangle.fill", OverwatchTheme.accentPrimary)
            default: ("BELOW TARGET", "xmark.shield.fill", OverwatchTheme.alert)
            }
        }()

        return HStack(spacing: OverwatchTheme.Spacing.sm) {
            Image(systemName: status.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(status.color)
                .textGlow(status.color, radius: 4)

            Text(status.label)
                .font(Typography.hudLabel)
                .foregroundStyle(status.color)
                .tracking(2)
                .textGlow(status.color, radius: 3)

            Spacer()

            let freqLabel = habit.targetFrequency == 7 ? "DAILY" : "\(habit.targetFrequency)×/WK"
            Text("GOAL: \(freqLabel)")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
                .tracking(1)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.md)
        .padding(.vertical, OverwatchTheme.Spacing.sm)
        .background(status.color.opacity(0.06))
        .clipShape(HUDFrameShape(chamferSize: 6))
        .overlay(
            HUDFrameShape(chamferSize: 6)
                .stroke(status.color.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            Rectangle()
                .fill(OverwatchTheme.accentCyan.opacity(0.6))
                .frame(width: 3, height: 12)
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.6), radius: 4)

            Text(text)
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Spacer()
        }
    }

    private func categoryBadge(_ category: String) -> some View {
        Text(category.uppercased())
            .font(Typography.metricTiny)
            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.6))
            .tracking(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(OverwatchTheme.accentCyan.opacity(0.06))
            .clipShape(.capsule)
            .overlay(Capsule().stroke(OverwatchTheme.accentCyan.opacity(0.15), lineWidth: 1))
    }

    private func modeBadge(_ mode: String, unit: String) -> some View {
        Text(unit.isEmpty ? mode : "\(mode) (\(unit.uppercased()))")
            .font(Typography.metricTiny)
            .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.6))
            .tracking(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(OverwatchTheme.accentPrimary.opacity(0.06))
            .clipShape(.capsule)
            .overlay(Capsule().stroke(OverwatchTheme.accentPrimary.opacity(0.15), lineWidth: 1))
    }

    private func frequencyBadge(_ frequency: Int) -> some View {
        let text = frequency == 7 ? "DAILY" : "\(frequency)×/WK"
        return Text(text)
            .font(Typography.metricTiny)
            .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.6))
            .tracking(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(OverwatchTheme.textSecondary.opacity(0.06))
            .clipShape(.capsule)
            .overlay(Capsule().stroke(OverwatchTheme.textSecondary.opacity(0.15), lineWidth: 1))
    }

    private func rateColor(_ rate: Double) -> Color {
        switch rate {
        case 0.67...: OverwatchTheme.accentSecondary
        case 0.34..<0.67: OverwatchTheme.accentPrimary
        default: OverwatchTheme.alert
        }
    }
}

// MARK: - Habit Form Sheet

private struct HabitFormSheet: View {
    let mode: FormMode
    let onSave: (String, String, String, Int, Bool, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var category: String
    @State private var targetFrequency: Int
    @State private var isQuantitative: Bool
    @State private var unitLabel: String
    @State private var showCustomEmoji = false

    enum FormMode {
        case add
        case edit(HabitsViewModel.HabitItem)
    }

    init(
        mode: FormMode,
        onSave: @escaping (String, String, String, Int, Bool, String) -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _emoji = State(initialValue: "")
            _category = State(initialValue: "General")
            _targetFrequency = State(initialValue: 7)
            _isQuantitative = State(initialValue: false)
            _unitLabel = State(initialValue: "")
        case .edit(let habit):
            _name = State(initialValue: habit.name)
            _emoji = State(initialValue: habit.emoji)
            _category = State(initialValue: habit.category)
            _targetFrequency = State(initialValue: habit.targetFrequency)
            _isQuantitative = State(initialValue: habit.isQuantitative)
            _unitLabel = State(initialValue: habit.unitLabel)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            OverwatchTheme.background.ignoresSafeArea()
            ScanLineOverlay().ignoresSafeArea()

            ScrollView {
                VStack(spacing: OverwatchTheme.Spacing.xl) {
                    // Header
                    VStack(spacing: OverwatchTheme.Spacing.sm) {
                        Text(isEditing ? "MODIFY OPERATION" : "NEW OPERATION")
                            .font(Typography.title)
                            .foregroundStyle(OverwatchTheme.accentCyan)
                            .tracking(4)
                            .textGlow(OverwatchTheme.accentCyan, radius: 12)

                        HUDDivider(color: OverwatchTheme.accentCyan)
                    }

                    // Form fields
                    VStack(spacing: OverwatchTheme.Spacing.lg) {
                        formField(label: "DESIGNATION", placeholder: "Habit name", text: $name)
                        iconPicker
                        categoryPicker
                        frequencyPicker
                        trackingModePicker
                    }

                    Spacer(minLength: OverwatchTheme.Spacing.lg)

                    // Actions
                    HStack(spacing: OverwatchTheme.Spacing.md) {
                        Button("CANCEL") { dismiss() }
                            .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.textSecondary))

                        Button(isEditing ? "UPDATE" : "ACTIVATE") {
                            onSave(
                                name.trimmingCharacters(in: .whitespaces),
                                emoji.trimmingCharacters(in: .whitespaces),
                                category,
                                targetFrequency,
                                isQuantitative,
                                unitLabel.trimmingCharacters(in: .whitespaces)
                            )
                            dismiss()
                        }
                        .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.accentCyan))
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                    }
                }
                .padding(OverwatchTheme.Spacing.xl)
            }
        }
        .frame(width: 460, height: 640)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
            Text("CLASSIFICATION")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 2)

            // Wrap categories in rows
            let columns = [
                GridItem(.adaptive(minimum: 80), spacing: 6)
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(HabitsViewModel.defaultCategories, id: \.self) { cat in
                    Button {
                        category = cat
                    } label: {
                        Text(cat.uppercased())
                            .font(Typography.metricTiny)
                            .tracking(1)
                            .foregroundStyle(
                                category == cat
                                    ? OverwatchTheme.accentCyan
                                    : OverwatchTheme.textSecondary
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                category == cat
                                    ? OverwatchTheme.accentCyan.opacity(0.1)
                                    : OverwatchTheme.surface
                            )
                            .clipShape(HUDFrameShape(chamferSize: 4))
                            .overlay(
                                HUDFrameShape(chamferSize: 4)
                                    .stroke(
                                        category == cat
                                            ? OverwatchTheme.accentCyan.opacity(0.5)
                                            : OverwatchTheme.accentCyan.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Frequency Picker

    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
            Text("FREQUENCY")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 2)

            HStack(spacing: OverwatchTheme.Spacing.sm) {
                frequencyChip("DAILY", isSelected: targetFrequency == 7) {
                    targetFrequency = 7
                }

                frequencyChip("WEEKLY", isSelected: targetFrequency < 7) {
                    if targetFrequency == 7 { targetFrequency = 3 }
                }
            }

            if targetFrequency < 7 {
                HStack(spacing: OverwatchTheme.Spacing.md) {
                    Button {
                        if targetFrequency > 1 { targetFrequency -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(OverwatchTheme.accentCyan)
                            .frame(width: 24, height: 24)
                            .background(OverwatchTheme.accentCyan.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(OverwatchTheme.accentCyan.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Text("\(targetFrequency)× PER WEEK")
                        .font(Typography.metricSmall)
                        .foregroundStyle(OverwatchTheme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Button {
                        if targetFrequency < 6 { targetFrequency += 1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(OverwatchTheme.accentCyan)
                            .frame(width: 24, height: 24)
                            .background(OverwatchTheme.accentCyan.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(OverwatchTheme.accentCyan.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, OverwatchTheme.Spacing.xs)
            }
        }
    }

    // MARK: - Tracking Mode Picker

    private var trackingModePicker: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
            Text("TRACKING MODE")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 2)

            HStack(spacing: OverwatchTheme.Spacing.sm) {
                frequencyChip("TOGGLE ○/●", isSelected: !isQuantitative) {
                    isQuantitative = false
                }

                frequencyChip("QUANTITY 123", isSelected: isQuantitative) {
                    isQuantitative = true
                }
            }

            if isQuantitative {
                formField(label: "UNIT", placeholder: "e.g., L, min, km", text: $unitLabel)
                    .padding(.top, OverwatchTheme.Spacing.xs)
            }
        }
    }

    // MARK: - Icon Picker

    private static let curatedIcons: [(group: String, icons: [String])] = [
        ("FITNESS", ["🏋️", "🏃", "🚴", "🏊", "🧗", "⚽", "🎾", "🥊"]),
        ("HEALTH", ["💧", "😴", "💊", "🩺", "🧘", "🫁", "🦷", "👁️"]),
        ("NUTRITION", ["🥗", "🍎", "🥦", "🍳", "☕", "🫖", "🧃", "🍽️"]),
        ("MIND", ["📖", "✍️", "🧠", "🎵", "🎨", "📝", "🙏", "🌅"]),
        ("PRODUCTIVITY", ["💻", "📊", "⏰", "📧", "🎯", "📋", "🗂️", "✅"]),
        ("SOCIAL", ["📱", "👥", "💬", "🤝", "❤️", "📞", "🎉", "👨‍👩‍👧"]),
    ]

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
            HStack {
                Text("ICON")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                    .tracking(3)
                    .textGlow(OverwatchTheme.accentCyan, radius: 2)

                Spacer()

                if !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 22))
                }

                Button {
                    showCustomEmoji.toggle()
                } label: {
                    Text("CUSTOM")
                        .font(Typography.metricTiny)
                        .tracking(1)
                        .foregroundStyle(
                            showCustomEmoji
                                ? OverwatchTheme.accentCyan
                                : OverwatchTheme.textSecondary
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            showCustomEmoji
                                ? OverwatchTheme.accentCyan.opacity(0.1)
                                : .clear
                        )
                        .clipShape(HUDFrameShape(chamferSize: 4))
                        .overlay(
                            HUDFrameShape(chamferSize: 4)
                                .stroke(
                                    OverwatchTheme.accentCyan.opacity(showCustomEmoji ? 0.4 : 0.15),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            if showCustomEmoji {
                TextField("Paste emoji", text: $emoji)
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
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                        ForEach(Self.curatedIcons, id: \.group) { section in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.group)
                                    .font(Typography.metricTiny)
                                    .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.5))
                                    .tracking(1)

                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8),
                                    spacing: 4
                                ) {
                                    ForEach(section.icons, id: \.self) { icon in
                                        Button {
                                            emoji = icon
                                        } label: {
                                            Text(icon)
                                                .font(.system(size: 20))
                                                .frame(width: 36, height: 36)
                                                .background(
                                                    emoji == icon
                                                        ? OverwatchTheme.accentCyan.opacity(0.12)
                                                        : OverwatchTheme.surface
                                                )
                                                .clipShape(HUDFrameShape(chamferSize: 4))
                                                .overlay(
                                                    HUDFrameShape(chamferSize: 4)
                                                        .stroke(
                                                            emoji == icon
                                                                ? OverwatchTheme.accentCyan.opacity(0.6)
                                                                : OverwatchTheme.accentCyan.opacity(0.08),
                                                            lineWidth: 1
                                                        )
                                                )
                                                .shadow(
                                                    color: emoji == icon
                                                        ? OverwatchTheme.accentCyan.opacity(0.25)
                                                        : .clear,
                                                    radius: 6
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    // MARK: - Helpers

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

    private func frequencyChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typography.metricTiny)
                .tracking(1)
                .foregroundStyle(
                    isSelected ? OverwatchTheme.accentCyan : OverwatchTheme.textSecondary
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected ? OverwatchTheme.accentCyan.opacity(0.1) : OverwatchTheme.surface
                )
                .clipShape(HUDFrameShape(chamferSize: 5))
                .overlay(
                    HUDFrameShape(chamferSize: 5)
                        .stroke(
                            isSelected
                                ? OverwatchTheme.accentCyan.opacity(0.5)
                                : OverwatchTheme.accentCyan.opacity(0.1),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reorder Drop Delegate

private struct HabitReorderDropDelegate: DropDelegate {
    let targetHabitID: UUID
    @Binding var draggedHabitID: UUID?
    let onMove: (UUID) -> Void
    let onDrop: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedHabitID = nil
        onDrop()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedHabitID, draggedID != targetHabitID else { return }
        onMove(draggedID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedHabitID != nil
    }
}

// MARK: - Preview

#Preview("Habits Page") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        HabitsView()
    }
    .modelContainer(
        for: [Habit.self, HabitEntry.self, JournalEntry.self, WhoopCycle.self],
        inMemory: true
    )
    .frame(width: 900, height: 700)
}
