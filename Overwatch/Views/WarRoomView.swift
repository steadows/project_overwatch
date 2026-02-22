import SwiftUI
import SwiftData
import Charts

/// Split-pane analytics — AI briefing panel (left) + interactive charts (right).
/// Full HUD treatment with resizable divider. Phase 7.4.
struct WarRoomView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.navigateToSection) private var navigateToSection
    @State private var viewModel = WarRoomViewModel()
    @State private var dividerRatio: CGFloat = 0.4

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left pane — AI Briefing
                briefingPane
                    .frame(width: geo.size.width * dividerRatio)

                // Resizable divider
                resizableDivider(totalWidth: geo.size.width)

                // Right pane — Charts
                chartsPane
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { viewModel.loadData(from: context) }
        .onChange(of: viewModel.selectedDateRange) {
            withAnimation(Animations.standard) {
                viewModel.loadData(from: context)
            }
        }
    }

    // MARK: - Resizable Divider

    private func resizableDivider(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(OverwatchTheme.accentCyan.opacity(0.15))
            .frame(width: 2)
            .overlay(
                Rectangle()
                    .fill(OverwatchTheme.accentCyan.opacity(0.4))
                    .frame(width: 1)
            )
            .contentShape(Rectangle().inset(by: -4))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newRatio = value.location.x / totalWidth + dividerRatio
                        dividerRatio = min(max(newRatio, 0.25), 0.6)
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Left Pane: AI Briefing

    private var briefingPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                briefingHeader

                // Gemini status badges
                if !viewModel.geminiAvailable {
                    HUDStatusBadge.intelligenceOffline {
                        navigateToSection(.settings)
                    }
                }

                if viewModel.isThrottled {
                    HUDStatusBadge.intelligenceThrottled(
                        retryDetail: viewModel.throttleMessage ?? "Rate limit exceeded — try again later"
                    )
                }

                if let insight = viewModel.latestInsight {
                    insightContent(insight)
                } else {
                    awaitingDataPlaceholder
                }
            }
            .padding(OverwatchTheme.Spacing.lg)
        }
    }

    private var briefingHeader: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                    Text("WAR ROOM")
                        .font(Typography.largeTitle)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(6)
                        .textGlow(OverwatchTheme.accentCyan, radius: 20)

                    Text("STRATEGIC INTELLIGENCE")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.45))
                        .tracking(5)
                        .textGlow(OverwatchTheme.accentCyan, radius: 4)
                }

                Spacer()
            }

            HUDDivider(color: OverwatchTheme.accentCyan)
        }
    }

    private func insightContent(_ insight: ReportsViewModel.ReportCard) -> some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
            // Date range
            Text(insight.dateRangeLabel)
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.textSecondary)
                .tracking(2)

            // Narrative summary
            TacticalCard {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                    paneLabel("// BRIEFING")

                    Text(insight.summary)
                        .font(Typography.metricSmall)
                        .foregroundStyle(OverwatchTheme.textPrimary.opacity(0.9))
                        .lineSpacing(4)
                }
            }

            // Force multiplier
            TacticalCard(glowColor: OverwatchTheme.accentPrimary) {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                    paneLabel("// FORCE MULTIPLIER")

                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(OverwatchTheme.accentPrimary)
                            .shadow(color: OverwatchTheme.accentPrimary.opacity(0.6), radius: 8)

                        Text(insight.forceMultiplierHabit)
                            .font(Typography.subtitle)
                            .foregroundStyle(OverwatchTheme.accentPrimary)
                            .textGlow(OverwatchTheme.accentPrimary, radius: 6)
                    }
                }
            }

            // Wellbeing gauge
            if !viewModel.gaugeData.isEmpty {
                TacticalCard {
                    SentimentGauge(sentimentData: viewModel.gaugeData)
                }
            }

            // Recommendations
            if !insight.recommendations.isEmpty {
                TacticalCard {
                    VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                        paneLabel("// RECOMMENDATIONS")

                        ForEach(Array(insight.recommendations.enumerated()), id: \.offset) { index, rec in
                            HStack(alignment: .top, spacing: OverwatchTheme.Spacing.sm) {
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 5))
                                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                                    .padding(.top, 5)

                                Text(rec)
                                    .font(Typography.metricSmall)
                                    .foregroundStyle(OverwatchTheme.textPrimary.opacity(0.85))
                                    .lineSpacing(2)
                            }
                        }
                    }
                }
            }

            // Refresh button
            refreshButton

            Spacer(minLength: OverwatchTheme.Spacing.xl)
        }
    }

    private var awaitingDataPlaceholder: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.lg) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))

                Text("AWAITING INTELLIGENCE DATA")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                    .tracking(2)
                    .textGlow(OverwatchTheme.accentCyan, radius: 3)

                Text("Generate a report from the Reports tab to see AI insights here.")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OverwatchTheme.Spacing.xxl)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refreshAnalysis(from: context) }
        } label: {
            HStack(spacing: 6) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(OverwatchTheme.accentPrimary)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                }
                Text(viewModel.isRefreshing ? (viewModel.refreshProgress ?? "REFRESHING...") : "REFRESH ANALYSIS")
                    .font(Typography.hudLabel)
                    .tracking(2)
            }
            .foregroundStyle(OverwatchTheme.accentPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(OverwatchTheme.accentPrimary.opacity(0.08))
            .clipShape(HUDFrameShape(chamferSize: 6))
            .overlay(
                HUDFrameShape(chamferSize: 6)
                    .stroke(OverwatchTheme.accentPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRefreshing)
    }

    // MARK: - Right Pane: Charts

    private var chartsPane: some View {
        VStack(spacing: 0) {
            chartControls
                .padding(OverwatchTheme.Spacing.lg)

            if chartHasDataForCurrentType {
                chartContent
                    .padding(.horizontal, OverwatchTheme.Spacing.lg)
                    .padding(.bottom, OverwatchTheme.Spacing.lg)
            } else {
                chartEmptyStateForCurrentType
                    .padding(OverwatchTheme.Spacing.lg)
            }
        }
    }

    /// Whether the currently selected chart type has data to display
    private var chartHasDataForCurrentType: Bool {
        switch viewModel.selectedChartType {
        case .recovery: !viewModel.recoveryData.isEmpty
        case .habits: !viewModel.habitDayData.isEmpty
        case .correlation: !viewModel.correlationData.isEmpty
        case .sleep: !viewModel.sleepData.isEmpty
        case .sentiment: !viewModel.sentimentData.isEmpty
        case .habitSentiment: !viewModel.habitSentimentData.isEmpty
        }
    }

    /// Whether the current chart type requires WHOOP data
    private var currentChartNeedsWhoop: Bool {
        switch viewModel.selectedChartType {
        case .recovery, .sleep, .correlation: true
        default: false
        }
    }

    /// Context-aware empty state for the current chart type
    @ViewBuilder
    private var chartEmptyStateForCurrentType: some View {
        if currentChartNeedsWhoop && !viewModel.hasWhoopData {
            // WHOOP-specific: no biometric source linked
            whoopChartEmptyState
        } else {
            // Generic: not enough data for this chart type
            chartEmptyState
        }
    }

    /// Empty state for WHOOP-dependent charts when no biometric data exists
    private var whoopChartEmptyState: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.lg) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))

                Text("LINK BIOMETRIC SOURCE")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                    .tracking(2)
                    .textGlow(OverwatchTheme.accentCyan, radius: 3)

                Text("Connect WHOOP in Settings to view \(viewModel.selectedChartType.rawValue.lowercased()) data")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    navigateToSection(.settings)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .medium))
                        Text("LINK BIOMETRIC SOURCE")
                            .font(Typography.hudLabel)
                            .tracking(1.5)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, OverwatchTheme.Spacing.xxl)
        }
    }

    // MARK: - Chart Controls

    private var chartControls: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            // Chart type switcher
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    ForEach(WarRoomViewModel.ChartType.allCases) { chartType in
                        Button {
                            withAnimation(Animations.standard) {
                                viewModel.selectedChartType = chartType
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: chartType.icon)
                                    .font(.system(size: 9, weight: .medium))
                                Text(chartType.rawValue)
                                    .font(Typography.hudLabel)
                                    .tracking(1)
                            }
                            .foregroundStyle(
                                viewModel.selectedChartType == chartType
                                    ? OverwatchTheme.accentCyan
                                    : OverwatchTheme.textSecondary
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedChartType == chartType
                                    ? OverwatchTheme.accentCyan.opacity(0.1)
                                    : .clear
                            )
                            .clipShape(HUDFrameShape(chamferSize: 5))
                            .overlay(
                                HUDFrameShape(chamferSize: 5)
                                    .stroke(
                                        viewModel.selectedChartType == chartType
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

            // Date range selector
            HStack(spacing: OverwatchTheme.Spacing.sm) {
                ForEach(WarRoomViewModel.DateRange.allCases) { range in
                    Button {
                        withAnimation(Animations.standard) {
                            viewModel.selectedDateRange = range
                        }
                    } label: {
                        Text(range.rawValue)
                            .font(Typography.hudLabel)
                            .tracking(1.5)
                            .foregroundStyle(
                                viewModel.selectedDateRange == range
                                    ? OverwatchTheme.accentPrimary
                                    : OverwatchTheme.textSecondary
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                viewModel.selectedDateRange == range
                                    ? OverwatchTheme.accentPrimary.opacity(0.1)
                                    : .clear
                            )
                            .clipShape(HUDFrameShape(chamferSize: 5))
                            .overlay(
                                HUDFrameShape(chamferSize: 5)
                                    .stroke(
                                        viewModel.selectedDateRange == range
                                            ? OverwatchTheme.accentPrimary.opacity(0.5)
                                            : OverwatchTheme.accentCyan.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            HUDDivider(color: OverwatchTheme.accentCyan)
        }
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        TacticalCard {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
                paneLabel("// \(viewModel.selectedChartType.rawValue)")

                Group {
                    switch viewModel.selectedChartType {
                    case .recovery:
                        recoveryChart
                    case .habits:
                        habitsChart
                    case .correlation:
                        correlationChart
                    case .sleep:
                        sleepChart
                    case .sentiment:
                        sentimentChart
                    case .habitSentiment:
                        habitSentimentChart
                    }
                }
                .frame(height: 320)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedChartType)
            }
        }
    }

    // MARK: - Chart: Recovery

    private var recoveryChart: some View {
        Chart {
            ForEach(viewModel.recoveryData) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Recovery", point.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [OverwatchTheme.accentCyan.opacity(0.12), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            ForEach(viewModel.recoveryData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Recovery", point.score)
                )
                .foregroundStyle(OverwatchTheme.accentCyan)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            ForEach(viewModel.recoveryData) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Recovery", point.score)
                )
                .foregroundStyle(performanceColor(point.score))
                .symbolSize(20)
            }

            // Zone lines
            RuleMark(y: .value("Green", 67))
                .foregroundStyle(OverwatchTheme.accentSecondary.opacity(0.2))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            RuleMark(y: .value("Amber", 34))
                .foregroundStyle(OverwatchTheme.alert.opacity(0.2))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        }
        .chartYScale(domain: 0...100)
        .chartStyling()
    }

    // MARK: - Chart: Habits (Stacked Bar)

    private var habitsChart: some View {
        Chart(viewModel.habitDayData) { point in
            BarMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Count", 1)
            )
            .foregroundStyle(by: .value("Habit", point.habitName))
        }
        .chartForegroundStyleScale(range: chartColorPalette)
        .chartLegend(position: .bottom, spacing: 8) {
            chartLegendContent
        }
        .chartStyling()
    }

    @ViewBuilder
    private var chartLegendContent: some View {
        let uniqueHabits = Dictionary(grouping: viewModel.habitDayData, by: \.habitName)
            .keys.sorted()

        HStack(spacing: 12) {
            ForEach(Array(uniqueHabits.enumerated()), id: \.element) { index, name in
                HStack(spacing: 4) {
                    Circle()
                        .fill(chartColorPalette[index % chartColorPalette.count])
                        .frame(width: 6, height: 6)
                    Text(name.uppercased())
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                }
            }
        }
    }

    private var chartColorPalette: [Color] {
        [
            OverwatchTheme.accentCyan,
            OverwatchTheme.accentPrimary,
            OverwatchTheme.accentSecondary,
            Color(red: 0.6, green: 0.4, blue: 1.0),
            Color(red: 1.0, green: 0.5, blue: 0.6),
            Color(red: 0.4, green: 0.8, blue: 0.6),
        ]
    }

    // MARK: - Chart: Correlation (Scatter)

    private var correlationChart: some View {
        Chart(viewModel.correlationData) { point in
            PointMark(
                x: .value("Completion %", point.completionPercent),
                y: .value("Avg Recovery", point.recoveryAvg)
            )
            .foregroundStyle(OverwatchTheme.accentCyan)
            .symbolSize(80)
            .annotation(position: .top, spacing: 4) {
                HabitIcon(iconName: point.iconName, emoji: point.emoji, size: 10, color: OverwatchTheme.accentCyan)
            }
        }
        .chartXAxisLabel(position: .bottom) {
            Text("COMPLETION %")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .chartYAxisLabel(position: .leading) {
            Text("AVG RECOVERY")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .chartStyling()
    }

    // MARK: - Chart: Sleep (Stacked Area)

    private var sleepChart: some View {
        Chart(viewModel.sleepData) { point in
            // SWS (deep sleep) — bottom layer
            BarMark(
                x: .value("Date", point.date, unit: .day),
                yStart: .value("SWS Start", 0),
                yEnd: .value("SWS End", point.swsHours),
                width: .ratio(0.6)
            )
            .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.8).opacity(0.6))

            // REM — stacked on top of SWS
            BarMark(
                x: .value("Date", point.date, unit: .day),
                yStart: .value("REM Start", point.swsHours),
                yEnd: .value("REM End", point.swsHours + point.remHours),
                width: .ratio(0.6)
            )
            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.45))

            // Total sleep line
            LineMark(
                x: .value("Date", point.date),
                y: .value("Total", point.totalHours)
            )
            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .interpolationMethod(.catmullRom)
        }
        .chartYAxisLabel(position: .leading) {
            Text("HOURS")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .chartStyling()
        .overlay(alignment: .bottomTrailing) {
            sleepLegend
                .padding(8)
        }
    }

    private var sleepLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.3, green: 0.3, blue: 0.8).opacity(0.5))
                    .frame(width: 12, height: 6)
                Text("SWS")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(OverwatchTheme.accentCyan.opacity(0.4))
                    .frame(width: 12, height: 6)
                Text("REM")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }
            HStack(spacing: 4) {
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(OverwatchTheme.accentCyan.opacity(0.6))
                            .frame(width: 3, height: 1)
                    }
                }
                .frame(width: 12)
                Text("TOTAL")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }
        }
        .padding(6)
        .background(OverwatchTheme.surface.opacity(0.8))
        .clipShape(HUDFrameShape(chamferSize: 3))
    }

    // MARK: - Chart: Sentiment Time Series

    private var sentimentChart: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            Chart {
                // Daily sentiment dots
                ForEach(viewModel.sentimentData) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Sentiment", point.score)
                    )
                    .foregroundStyle(sentimentDotColor(point.score))
                    .symbolSize(30)
                }

                // 7-day rolling average line
                ForEach(rollingAverage(viewModel.sentimentData, window: 7)) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Avg", point.score)
                    )
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }

                // Habit completion overlay bars
                ForEach(viewModel.habitCompletionOverlay) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Habits", Double(day.count) / 10.0 - 1.0)
                    )
                    .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.15))
                }

                // Zero line
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }
            .chartYScale(domain: -1...1)
            .chartYAxisLabel(position: .leading) {
                Text("SENTIMENT")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }
            .chartStyling()

            // Legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(OverwatchTheme.accentSecondary)
                        .frame(width: 6, height: 6)
                    Text("DAILY SCORE")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(OverwatchTheme.accentCyan)
                        .frame(width: 12, height: 2)
                    Text("7-DAY AVG")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(OverwatchTheme.accentPrimary.opacity(0.3))
                        .frame(width: 12, height: 6)
                    Text("HABIT COUNT")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Chart: Habit x Sentiment Scatter

    private var habitSentimentChart: some View {
        Chart(viewModel.habitSentimentData) { point in
            PointMark(
                x: .value("Completion %", point.completionPercent),
                y: .value("Avg Sentiment", point.avgSentiment)
            )
            .foregroundStyle(sentimentDotColor(point.avgSentiment))
            .symbolSize(80)
            .annotation(position: .top, spacing: 4) {
                HabitIcon(iconName: point.iconName, emoji: point.emoji, size: 10, color: OverwatchTheme.accentCyan)
            }
        }
        .chartYScale(domain: -1...1)
        .chartXAxisLabel(position: .bottom) {
            Text("COMPLETION %")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .chartYAxisLabel(position: .leading) {
            Text("AVG SENTIMENT")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .chartStyling()
        .overlay(alignment: .center) {
            // Zero line
            GeometryReader { geo in
                let yCenter = geo.size.height / 2
                Path { path in
                    path.move(to: CGPoint(x: 0, y: yCenter))
                    path.addLine(to: CGPoint(x: geo.size.width, y: yCenter))
                }
                .stroke(OverwatchTheme.textSecondary.opacity(0.15), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }
        }
    }

    // MARK: - Chart Empty State

    private var chartEmptyState: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.lg) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))

                Text("INSUFFICIENT DATA")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                    .tracking(2)
                    .textGlow(OverwatchTheme.accentCyan, radius: 3)

                Text(chartMinimumThresholdNote)
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, OverwatchTheme.Spacing.xxl)
        }
    }

    /// Minimum data threshold note per chart type
    private var chartMinimumThresholdNote: String {
        switch viewModel.selectedChartType {
        case .recovery:
            "Minimum 3 WHOOP cycles required for recovery trend analysis"
        case .habits:
            "Log habit completions for at least 7 days to see patterns"
        case .correlation:
            "Requires 7+ days of both habit entries and WHOOP recovery data"
        case .sleep:
            "Minimum 3 WHOOP cycles required for sleep stage analysis"
        case .sentiment:
            "Write journal entries for at least 3 days to see sentiment trends"
        case .habitSentiment:
            "Requires 7+ days of both habit entries and journal entries"
        }
    }

    // MARK: - Helpers

    private func paneLabel(_ text: String) -> some View {
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

    private func performanceColor(_ score: Double) -> Color {
        OverwatchTheme.performanceColor(for: score)
    }

    private func sentimentDotColor(_ score: Double) -> Color {
        if score >= 0.33 { return OverwatchTheme.accentSecondary }
        if score >= -0.33 { return OverwatchTheme.accentPrimary }
        return OverwatchTheme.alert
    }

    private func rollingAverage(_ data: [JournalViewModel.SentimentDataPoint], window: Int) -> [JournalViewModel.SentimentDataPoint] {
        guard data.count >= window else { return data }
        let sorted = data.sorted { $0.date < $1.date }
        return sorted.enumerated().map { index, point in
            let start = max(0, index - window + 1)
            let slice = sorted[start...index]
            let avg = slice.map(\.score).reduce(0, +) / Double(slice.count)
            return JournalViewModel.SentimentDataPoint(id: point.id, date: point.date, score: avg)
        }
    }
}

// MARK: - Preview

#Preview("War Room — With Data") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        WarRoomView()
    }
    .frame(width: 1200, height: 800)
}

#Preview("War Room — Empty") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        WarRoomView()
    }
    .frame(width: 1200, height: 800)
}
