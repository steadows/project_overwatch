import SwiftUI
import Charts

/// Per-habit trend chart with optional WHOOP recovery overlay.
///
/// - Boolean habits: 7-day rolling average completion rate (0–100%)
/// - Quantity habits: actual daily values (e.g., liters of water)
/// - WHOOP overlay: dashed green line showing recovery % for correlation
struct HabitTrendChartView: View {
    let chartData: HabitsViewModel.TrendChartData
    @Binding var dateRange: HabitsViewModel.TrendDateRange
    @Binding var showWhoopOverlay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
            headerRow
            dateRangeSelector

            if chartData.hasEnoughData {
                chartContent
                    .frame(height: 200)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: chartData.habitPoints.count
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: showWhoopOverlay
                    )

                if showWhoopOverlay {
                    chartLegend
                }
            } else {
                emptyState
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            HStack(spacing: OverwatchTheme.Spacing.sm) {
                Rectangle()
                    .fill(OverwatchTheme.accentCyan.opacity(0.6))
                    .frame(width: 3, height: 12)
                    .shadow(color: OverwatchTheme.accentCyan.opacity(0.6), radius: 4)

                Text("// TREND ANALYSIS")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                    .tracking(3)
                    .textGlow(OverwatchTheme.accentCyan, radius: 3)

                Spacer()
            }

            whoopToggle
        }
    }

    // MARK: - Date Range Selector

    private var dateRangeSelector: some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            ForEach(HabitsViewModel.TrendDateRange.allCases) { range in
                Button {
                    withAnimation(Animations.standard) {
                        dateRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(Typography.hudLabel)
                        .tracking(1.5)
                        .foregroundStyle(
                            dateRange == range
                                ? OverwatchTheme.accentCyan
                                : OverwatchTheme.textSecondary
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            dateRange == range
                                ? OverwatchTheme.accentCyan.opacity(0.1)
                                : .clear
                        )
                        .clipShape(HUDFrameShape(chamferSize: 5))
                        .overlay(
                            HUDFrameShape(chamferSize: 5)
                                .stroke(
                                    dateRange == range
                                        ? OverwatchTheme.accentCyan.opacity(0.5)
                                        : OverwatchTheme.accentCyan.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - WHOOP Toggle

    private var whoopToggle: some View {
        Button {
            withAnimation(Animations.quick) {
                showWhoopOverlay.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 10, weight: .medium))
                Text("RECOVERY")
                    .font(Typography.hudLabel)
                    .tracking(1)
            }
            .foregroundStyle(
                showWhoopOverlay
                    ? OverwatchTheme.accentSecondary
                    : OverwatchTheme.textSecondary
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                showWhoopOverlay
                    ? OverwatchTheme.accentSecondary.opacity(0.08)
                    : .clear
            )
            .clipShape(HUDFrameShape(chamferSize: 4))
            .overlay(
                HUDFrameShape(chamferSize: 4)
                    .stroke(
                        showWhoopOverlay
                            ? OverwatchTheme.accentSecondary.opacity(0.4)
                            : OverwatchTheme.accentCyan.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        if chartData.isQuantitative {
            quantityChart
        } else {
            booleanChart
        }
    }

    /// Boolean habit: rolling average (0–100%) with area fill glow.
    private var booleanChart: some View {
        Chart {
            // Area fill beneath line for glow effect
            ForEach(chartData.habitPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Rate", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            OverwatchTheme.accentCyan.opacity(0.12),
                            OverwatchTheme.accentCyan.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Main line
            ForEach(chartData.habitPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Rate", point.value)
                )
                .foregroundStyle(OverwatchTheme.accentCyan)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Data points
            ForEach(chartData.habitPoints) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Rate", point.value)
                )
                .foregroundStyle(OverwatchTheme.accentCyan)
                .symbolSize(16)
            }

            // WHOOP recovery overlay
            if showWhoopOverlay {
                ForEach(chartData.whoopPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Recovery", point.value)
                    )
                    .foregroundStyle(OverwatchTheme.accentSecondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxisLabel(position: .leading) {
            Text("%")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .chartStyling()
    }

    /// Quantity habit: actual values with unit label.
    private var quantityChart: some View {
        let maxY = max(chartData.maxHabitValue * 1.15, 1)
        let whoopScaleFactor = chartData.maxHabitValue > 0
            ? chartData.maxHabitValue / 100.0
            : 1.0

        return Chart {
            // Area fill
            ForEach(chartData.habitPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            OverwatchTheme.accentCyan.opacity(0.12),
                            OverwatchTheme.accentCyan.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Main line
            ForEach(chartData.habitPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(OverwatchTheme.accentCyan)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Data points
            ForEach(chartData.habitPoints) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(OverwatchTheme.accentCyan)
                .symbolSize(16)
            }

            // WHOOP overlay — normalized to habit value range
            if showWhoopOverlay {
                ForEach(chartData.whoopPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value * whoopScaleFactor)
                    )
                    .foregroundStyle(OverwatchTheme.accentSecondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartYScale(domain: 0...maxY)
        .chartYAxisLabel(position: .leading) {
            Text(chartData.unitLabel.isEmpty ? "VALUE" : chartData.unitLabel.uppercased())
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .chartStyling()
    }

    // MARK: - Legend

    private var chartLegend: some View {
        HStack(spacing: OverwatchTheme.Spacing.lg) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(OverwatchTheme.accentCyan)
                    .frame(width: 16, height: 2)
                    .shadow(color: OverwatchTheme.accentCyan.opacity(0.5), radius: 3)
                Text(
                    chartData.isQuantitative
                        ? (chartData.unitLabel.isEmpty ? "VALUE" : chartData.unitLabel.uppercased())
                        : "COMPLETION RATE"
                )
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
            }

            HStack(spacing: 6) {
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(OverwatchTheme.accentSecondary.opacity(0.6))
                            .frame(width: 4, height: 1.5)
                    }
                }
                .frame(width: 16)

                Text("RECOVERY %")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }

            if chartData.whoopPoints.isEmpty {
                Text("NO BIOMETRIC DATA")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.5))
                    .tracking(1)
            }

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))

            Text("INSUFFICIENT DATA")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                .tracking(2)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Text("Log more entries to see trends (minimum 7 data points)")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }
}

// MARK: - Chart Styling Modifier

private extension View {
    /// Applies consistent HUD styling to a SwiftUI Chart.
    func chartStyling() -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.08))
                    AxisValueLabel()
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .font(Typography.metricTiny)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.08))
                    AxisValueLabel()
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .font(Typography.metricTiny)
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(OverwatchTheme.background.opacity(0.5))
                    .border(OverwatchTheme.accentCyan.opacity(0.1), width: 0.5)
            }
    }
}

// MARK: - Preview

#Preview("Trend Chart — Boolean Habit") {
    @Previewable @State var range: HabitsViewModel.TrendDateRange = .month
    @Previewable @State var whoop = true

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let habitPoints = (0..<30).map { offset in
        let date = calendar.date(byAdding: .day, value: -(29 - offset), to: today)!
        let value = 40.0 + Double.random(in: -15...25)
        return HabitsViewModel.TrendDataPoint(id: date, date: date, value: min(100, max(0, value)))
    }

    let whoopPoints = (0..<30).map { offset in
        let date = calendar.date(byAdding: .day, value: -(29 - offset), to: today)!
        let value = 55.0 + Double.random(in: -20...30)
        return HabitsViewModel.TrendDataPoint(id: date, date: date, value: min(100, max(0, value)))
    }

    let chartData = HabitsViewModel.TrendChartData(
        habitPoints: habitPoints,
        whoopPoints: whoopPoints,
        isQuantitative: false,
        unitLabel: "",
        habitName: "Meditation",
        hasEnoughData: true,
        maxHabitValue: 100,
        minHabitValue: 0
    )

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            HabitTrendChartView(
                chartData: chartData,
                dateRange: $range,
                showWhoopOverlay: $whoop
            )
        }
        .padding(24)
    }
    .frame(width: 700, height: 400)
}

#Preview("Trend Chart — Quantity Habit") {
    @Previewable @State var range: HabitsViewModel.TrendDateRange = .month
    @Previewable @State var whoop = false

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let habitPoints = (0..<30).compactMap { offset -> HabitsViewModel.TrendDataPoint? in
        let date = calendar.date(byAdding: .day, value: -(29 - offset), to: today)!
        guard Bool.random() || Bool.random() else { return nil }
        let value = 2.0 + Double.random(in: -0.5...1.5)
        return HabitsViewModel.TrendDataPoint(id: date, date: date, value: value)
    }

    let chartData = HabitsViewModel.TrendChartData(
        habitPoints: habitPoints,
        whoopPoints: [],
        isQuantitative: true,
        unitLabel: "L",
        habitName: "Water",
        hasEnoughData: true,
        maxHabitValue: habitPoints.map(\.value).max() ?? 3.5,
        minHabitValue: habitPoints.map(\.value).min() ?? 0
    )

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            HabitTrendChartView(
                chartData: chartData,
                dateRange: $range,
                showWhoopOverlay: $whoop
            )
        }
        .padding(24)
    }
    .frame(width: 700, height: 400)
}

#Preview("Trend Chart — Empty State") {
    @Previewable @State var range: HabitsViewModel.TrendDateRange = .month
    @Previewable @State var whoop = false

    let chartData = HabitsViewModel.TrendChartData(
        habitPoints: [],
        whoopPoints: [],
        isQuantitative: false,
        unitLabel: "",
        habitName: "Exercise",
        hasEnoughData: false,
        maxHabitValue: 0,
        minHabitValue: 0
    )

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            HabitTrendChartView(
                chartData: chartData,
                dateRange: $range,
                showWhoopOverlay: $whoop
            )
        }
        .padding(24)
    }
    .frame(width: 700, height: 400)
}
