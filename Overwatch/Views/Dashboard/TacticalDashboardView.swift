import SwiftUI
import SwiftData
import Charts

struct TacticalDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.navigateToSection) private var navigateToSection
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

                sentimentPulseSection
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.30)

                heatMapPreview
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.42)

                fieldLogSection
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.54)
            }
            .padding(OverwatchTheme.Spacing.xl)
        }
        .onAppear {
            viewModel.loadData(from: modelContext)
            viewModel.syncStatus = appState.whoopSyncStatus
            sectionsVisible = true
            // If sync died (session expired overnight), restart it
            appState.ensureSyncRunning(modelContainer: modelContext.container)
        }
        .onChange(of: appState.whoopSyncStatus) { _, newStatus in
            viewModel.syncStatus = newStatus
            // Reload WHOOP metrics when a sync completes so the strip updates live
            if case .synced = newStatus {
                viewModel.loadData(from: modelContext)
            }
            // Surface sync errors to the WHOOP strip
            if case .error(let message) = newStatus {
                viewModel.whoopError = message
            } else {
                viewModel.whoopError = nil
            }
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
        case .error:
            if let lastSync = viewModel.whoopMetrics.lastSyncedAt {
                "LAST SYNC: \(DateFormatters.relative.localizedString(for: lastSync, relativeTo: .now).uppercased())"
            } else {
                "SIGNAL LOST"
            }
        }
    }

    // MARK: - TODAY'S OPS (Hero Section)

    private var todaysOpsSection: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            // Section header with summary and add button
            HStack {
                sectionLabel(viewModel.isViewingToday ? "TODAY'S OPS" : "OPS LOG")

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

            // Date navigation strip
            dateNavigationStrip

            // Habit toggle buttons
            if viewModel.trackedHabits.isEmpty {
                emptyHabitsState
            } else {
                habitToggleGrid
            }
        }
    }

    // MARK: - Date Navigation

    private var dateNavigationStrip: some View {
        HStack(spacing: OverwatchTheme.Spacing.md) {
            // Back one day
            Button {
                withAnimation(Animations.quick) {
                    viewModel.navigateDate(by: -1)
                    viewModel.loadData(from: modelContext)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(OverwatchTheme.accentCyan.opacity(0.06))
                    .clipShape(HUDFrameShape(chamferSize: 5))
                    .overlay(
                        HUDFrameShape(chamferSize: 5)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            // Date label
            Text(viewModel.selectedDateLabel)
                .font(Typography.hudLabel)
                .foregroundStyle(
                    viewModel.isViewingToday
                        ? OverwatchTheme.accentCyan
                        : OverwatchTheme.accentPrimary
                )
                .tracking(3)
                .textGlow(
                    viewModel.isViewingToday
                        ? OverwatchTheme.accentCyan
                        : OverwatchTheme.accentPrimary,
                    radius: 4
                )
                .contentTransition(.numericText())
                .animation(Animations.quick, value: viewModel.selectedDateLabel)

            // Forward one day (disabled if viewing today)
            Button {
                withAnimation(Animations.quick) {
                    viewModel.navigateDate(by: 1)
                    viewModel.loadData(from: modelContext)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        viewModel.isViewingToday
                            ? OverwatchTheme.textSecondary.opacity(0.2)
                            : OverwatchTheme.accentCyan.opacity(0.7)
                    )
                    .frame(width: 28, height: 28)
                    .background(OverwatchTheme.accentCyan.opacity(0.06))
                    .clipShape(HUDFrameShape(chamferSize: 5))
                    .overlay(
                        HUDFrameShape(chamferSize: 5)
                            .stroke(
                                viewModel.isViewingToday
                                    ? OverwatchTheme.textSecondary.opacity(0.1)
                                    : OverwatchTheme.accentCyan.opacity(0.25),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isViewingToday)

            Spacer()

            // TODAY snap-back button (only visible when viewing a past date)
            if !viewModel.isViewingToday {
                Button {
                    withAnimation(Animations.quick) {
                        viewModel.goToToday()
                        viewModel.loadData(from: modelContext)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9, weight: .medium))
                        Text("TODAY")
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
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
                Text("ESTABLISH FIRST OPERATION")
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
                        Text("ESTABLISH FIRST OPERATION")
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
                errorMessage: viewModel.whoopError,
                isExpanded: $viewModel.isWhoopExpanded,
                onRetry: {
                    viewModel.loadData(from: modelContext)
                },
                onNavigateToSettings: {
                    navigateToSection(.settings)
                }
            )
        }
    }

    // MARK: - SENTIMENT PULSE

    private var sentimentPulseSection: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("SENTIMENT PULSE")

            Button {
                navigateToSection(.journal)
            } label: {
                TacticalCard {
                    HStack(spacing: OverwatchTheme.Spacing.lg) {
                        // Today's sentiment
                        if viewModel.sentimentPulse.hasEntriesToday {
                            HStack(spacing: OverwatchTheme.Spacing.sm) {
                                SentimentDot(label: viewModel.sentimentPulse.todayLabel, size: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(format: "%+.2f", viewModel.sentimentPulse.todayScore))
                                        .font(Typography.metricMedium)
                                        .foregroundStyle(sentimentPulseColor)
                                        .monospacedDigit()
                                    Text("TODAY")
                                        .font(Typography.metricTiny)
                                        .foregroundStyle(OverwatchTheme.textSecondary)
                                        .tracking(1)
                                }
                            }
                        } else {
                            HStack(spacing: OverwatchTheme.Spacing.sm) {
                                Circle()
                                    .fill(OverwatchTheme.textSecondary.opacity(0.2))
                                    .frame(width: 10, height: 10)

                                Text("NO ENTRIES TODAY")
                                    .font(Typography.hudLabel)
                                    .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.4))
                                    .tracking(2)
                            }
                        }

                        Spacer()

                        // 7-day sparkline
                        if viewModel.sentimentPulse.sparklineData.contains(where: { $0 != 0 }) {
                            sentimentSparkline
                                .frame(width: 120, height: 32)
                        }

                        // Journal link
                        HStack(spacing: 4) {
                            Text("JOURNAL")
                                .font(Typography.hudLabel)
                                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                                .tracking(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var sentimentSparkline: some View {
        let sparkData = viewModel.sentimentPulse.sparklineData
        return Chart {
            ForEach(Array(sparkData.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Day", index),
                    y: .value("Score", value)
                )
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }

            ForEach(Array(sparkData.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Day", index),
                    yStart: .value("Base", 0),
                    yEnd: .value("Score", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            OverwatchTheme.accentCyan.opacity(0.1),
                            OverwatchTheme.accentCyan.opacity(0.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            RuleMark(y: .value("Neutral", 0))
                .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.2))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: -1.0...1.0)
    }

    private var sentimentPulseColor: Color {
        switch viewModel.sentimentPulse.todayLabel {
        case "positive": OverwatchTheme.accentSecondary
        case "negative": OverwatchTheme.alert
        default: OverwatchTheme.textSecondary
        }
    }

    // MARK: - Heat Map Preview (30-day compact)

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

                    HabitHeatMapView(
                        days: viewModel.compactHeatMapDays,
                        mode: .compact
                    )
                }
            }
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
    .environment(AppState())
    .modelContainer(for: [Habit.self, HabitEntry.self, JournalEntry.self, WhoopCycle.self],
                    inMemory: true)
    .frame(width: 900, height: 800)
}
