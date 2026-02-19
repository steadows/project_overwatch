import SwiftUI
import Charts

/// Sentiment score trend chart — colored scatter dots, 7-day rolling average,
/// green/red zone fills, neutral baseline, toggleable habit completion overlay,
/// and date range selector. War Room-ready (Phase 6.5.12).
struct SentimentTrendChart: View {
    let data: [JournalViewModel.SentimentDataPoint]
    var habitCompletionData: [JournalViewModel.DailyHabitCompletion] = []
    /// Called whenever the visible data window changes (range or offset).
    /// Receives the currently filtered sentiment data points.
    var onWindowChanged: (([JournalViewModel.SentimentDataPoint]) -> Void)? = nil

    @State private var dateRange: DateRange = .all
    @State private var showHabitOverlay: Bool = false
    /// Week offset from the latest week in the data. 0 = most recent week, 1 = one week back, etc.
    @State private var weekOffset: Int = 0

    enum DateRange: String, CaseIterable, Identifiable {
        case week = "1W"
        case month = "1M"
        case quarter = "3M"
        case year = "1Y"
        case all = "ALL"

        var id: String { rawValue }

        var dayCount: Int? {
            switch self {
            case .week: 7
            case .month: 30
            case .quarter: 90
            case .year: 365
            case .all: nil
            }
        }
    }

    /// Only show range options that are meaningfully smaller than the data span.
    private var applicableRanges: [DateRange] {
        guard let first = data.map(\.date).min(),
              let last = data.map(\.date).max() else {
            return [.all]
        }
        let span = max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0)

        var ranges: [DateRange] = []
        for range in DateRange.allCases {
            if let days = range.dayCount, days < span - 2 {
                ranges.append(range)
            }
        }
        ranges.append(.all)
        return ranges
    }

    /// The currently active range, clamped to an applicable value.
    private var effectiveRange: DateRange {
        applicableRanges.contains(dateRange) ? dateRange : .all
    }

    /// The date window (start, end) for the current sub-range selection.
    private var currentWindow: (start: Date, end: Date)? {
        guard let days = effectiveRange.dayCount else { return nil }
        guard let latestDate = data.map(\.date).max() else { return nil }
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: latestDate)
        // Shift back by weekOffset * days
        let windowEnd = calendar.date(byAdding: .day, value: -(weekOffset * days) + 1, to: anchor)!
        let windowStart = calendar.date(byAdding: .day, value: -days, to: windowEnd)!
        return (windowStart, windowEnd)
    }

    /// Maximum number of page offsets available for the current range.
    private var maxOffset: Int {
        guard let days = effectiveRange.dayCount,
              let first = data.map(\.date).min(),
              let last = data.map(\.date).max() else { return 0 }
        let span = max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0)
        return max(0, span / days)
    }

    private var filteredData: [JournalViewModel.SentimentDataPoint] {
        guard let window = currentWindow else { return data }
        return data.filter { $0.date >= window.start && $0.date < window.end }
    }

    private var filteredHabitData: [JournalViewModel.DailyHabitCompletion] {
        guard let window = currentWindow else { return habitCompletionData }
        return habitCompletionData.filter { $0.date >= window.start && $0.date < window.end }
    }

    /// Label for the current window (e.g. "Jan 6 — Jan 12").
    private var windowLabel: String? {
        guard let window = currentWindow else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: window.start)) — \(fmt.string(from: window.end))"
    }

    /// 7-day rolling average computed from filtered sentiment data.
    private var rollingAverageData: [JournalViewModel.SentimentDataPoint] {
        let sorted = filteredData.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return [] }

        return sorted.enumerated().map { index, point in
            let windowStart = max(0, index - 6)
            let window = sorted[windowStart...index]
            let avg = window.map(\.score).reduce(0, +) / Double(window.count)
            return JournalViewModel.SentimentDataPoint(
                id: point.date, date: point.date, score: avg
            )
        }
    }

    /// Max habit completion count for scaling bar overlay against secondary Y axis.
    private var maxHabitCount: Int {
        filteredHabitData.map(\.count).max() ?? 1
    }

    private var hasEnoughData: Bool { filteredData.count >= 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
            headerRow
            dateRangeSelector

            if hasEnoughData {
                sentimentChart
                    .frame(height: 200)
                    .animation(
                        .easeInOut(duration: 0.35),
                        value: dateRange
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: weekOffset
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: showHabitOverlay
                    )

                chartLegend
            } else {
                emptyState
            }
        }
        .onChange(of: data.count) {
            weekOffset = 0
            onWindowChanged?(filteredData)
        }
        .onChange(of: dateRange) {
            onWindowChanged?(filteredData)
        }
        .onChange(of: weekOffset) {
            onWindowChanged?(filteredData)
        }
        .onAppear {
            onWindowChanged?(filteredData)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            Rectangle()
                .fill(OverwatchTheme.accentCyan.opacity(0.6))
                .frame(width: 3, height: 12)
                .shadow(
                    color: OverwatchTheme.accentCyan.opacity(0.6), radius: 4
                )

            Text("// SENTIMENT TREND")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Spacer()

            if !habitCompletionData.isEmpty {
                habitOverlayToggle
            }
        }
    }

    // MARK: - Habit Overlay Toggle

    private var habitOverlayToggle: some View {
        Button {
            withAnimation(Animations.quick) {
                showHabitOverlay.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 10, weight: .medium))
                Text("HABITS")
                    .font(Typography.hudLabel)
                    .tracking(1)
            }
            .foregroundStyle(
                showHabitOverlay
                    ? OverwatchTheme.accentPrimary
                    : OverwatchTheme.textSecondary
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                showHabitOverlay
                    ? OverwatchTheme.accentPrimary.opacity(0.08)
                    : .clear
            )
            .clipShape(HUDFrameShape(chamferSize: 4))
            .overlay(
                HUDFrameShape(chamferSize: 4)
                    .stroke(
                        showHabitOverlay
                            ? OverwatchTheme.accentPrimary.opacity(0.4)
                            : OverwatchTheme.accentCyan.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Range Selector

    private var dateRangeSelector: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
            HStack(spacing: OverwatchTheme.Spacing.sm) {
                let ranges = applicableRanges
                let active = effectiveRange

                ForEach(ranges) { range in
                    Button {
                        withAnimation(Animations.standard) {
                            dateRange = range
                            weekOffset = 0
                        }
                    } label: {
                        Text(range.rawValue)
                            .font(Typography.hudLabel)
                            .tracking(1.5)
                            .foregroundStyle(
                                active == range
                                    ? OverwatchTheme.accentCyan
                                    : OverwatchTheme.textSecondary
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                active == range
                                    ? OverwatchTheme.accentCyan.opacity(0.1)
                                    : .clear
                            )
                            .clipShape(HUDFrameShape(chamferSize: 5))
                            .overlay(
                                HUDFrameShape(chamferSize: 5)
                                    .stroke(
                                        active == range
                                            ? OverwatchTheme.accentCyan
                                                .opacity(0.5)
                                            : OverwatchTheme.accentCyan
                                                .opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Window navigation — prev/next arrows with date label
            if effectiveRange != .all, let label = windowLabel {
                windowNavigator(label: label)
            }
        }
    }

    /// Prev/next arrows flanking the current window date label.
    private func windowNavigator(label: String) -> some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            Button {
                weekOffset = min(weekOffset + 1, maxOffset)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        weekOffset < maxOffset
                            ? OverwatchTheme.accentCyan
                            : OverwatchTheme.textSecondary.opacity(0.3)
                    )
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(weekOffset >= maxOffset)

            Text(label)
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
                .tracking(1)
                .frame(minWidth: 120)

            Button {
                weekOffset = max(weekOffset - 1, 0)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        weekOffset > 0
                            ? OverwatchTheme.accentCyan
                            : OverwatchTheme.textSecondary.opacity(0.3)
                    )
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(weekOffset <= 0)

            Spacer()
        }
        .padding(.leading, 2)
    }

    // MARK: - Chart

    private var sentimentChart: some View {
        Chart {
            // Area fill — matches rolling average line exactly (same data + interpolation)
            ForEach(rollingAverageData) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Base", 0.0),
                    yEnd: .value("Score", point.score)
                )
                .foregroundStyle(
                    point.score >= 0
                        ? OverwatchTheme.accentSecondary.opacity(0.08)
                        : OverwatchTheme.alert.opacity(0.08)
                )
                .interpolationMethod(.monotone)
            }

            // Neutral baseline at 0.0
            RuleMark(y: .value("Neutral", 0))
                .foregroundStyle(
                    OverwatchTheme.textSecondary.opacity(0.3)
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Habit completion overlay — semi-transparent bars
            if showHabitOverlay {
                ForEach(filteredHabitData) { day in
                    BarMark(
                        x: .value("Date", day.date),
                        y: .value("Habits", normalizedHabitValue(day.count))
                    )
                    .foregroundStyle(
                        OverwatchTheme.accentPrimary.opacity(0.15)
                    )
                    .cornerRadius(1)
                }
            }

            // 7-day rolling average — smoothed cyan line with glow
            ForEach(rollingAverageData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("RollingAvg", point.score),
                    series: .value("Series", "rolling")
                )
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }

            // Colored scatter dots — green for positive, red for negative
            ForEach(filteredData) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(dotColor(for: point.score))
                .symbolSize(20)
            }
        }
        .chartYScale(domain: -1.0...1.0)
        .chartYAxisLabel(position: .leading) {
            Text("SCORE")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .chartStyling()
    }

    // MARK: - Helpers

    private func dotColor(for score: Double) -> Color {
        if score > 0.05 { return OverwatchTheme.accentSecondary }
        if score < -0.05 { return OverwatchTheme.alert }
        return OverwatchTheme.textSecondary
    }

    /// Normalize habit count to fit within the -1...1 sentiment Y axis.
    /// Maps 0 → 0.0 and maxHabitCount → 0.9 (stays below the chart ceiling).
    private func normalizedHabitValue(_ count: Int) -> Double {
        guard maxHabitCount > 0 else { return 0 }
        return (Double(count) / Double(maxHabitCount)) * 0.9
    }

    // MARK: - Legend

    private var chartLegend: some View {
        HStack(spacing: OverwatchTheme.Spacing.lg) {
            // Rolling average legend
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(OverwatchTheme.accentCyan)
                    .frame(width: 16, height: 2)
                    .shadow(
                        color: OverwatchTheme.accentCyan.opacity(0.5),
                        radius: 3
                    )
                Text("7-DAY AVG")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }

            // Positive dot legend
            HStack(spacing: 6) {
                Circle()
                    .fill(OverwatchTheme.accentSecondary)
                    .frame(width: 6, height: 6)
                Text("POSITIVE")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }

            // Negative dot legend
            HStack(spacing: 6) {
                Circle()
                    .fill(OverwatchTheme.alert)
                    .frame(width: 6, height: 6)
                Text("NEGATIVE")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }

            // Habit overlay legend (when active)
            if showHabitOverlay {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(OverwatchTheme.accentPrimary.opacity(0.4))
                        .frame(width: 16, height: 6)
                    Text("HABITS")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                }
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

            Text(
                "Log more journal entries to see sentiment trends (minimum 3)"
            )
            .font(Typography.metricTiny)
            .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }
}

// MARK: - Preview

#Preview("Sentiment Trend Chart") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let data = (0..<30).map { offset in
        let date = calendar.date(
            byAdding: .day, value: -(29 - offset), to: today
        )!
        let score = sin(Double(offset) * 0.3) * 0.6
            + Double.random(in: -0.2...0.2)
        return JournalViewModel.SentimentDataPoint(
            id: date, date: date, score: max(-1, min(1, score))
        )
    }

    let habitData = (0..<30).compactMap { offset -> JournalViewModel.DailyHabitCompletion? in
        let date = calendar.date(
            byAdding: .day, value: -(29 - offset), to: today
        )!
        let count = Int.random(in: 0...5)
        guard count > 0 else { return nil }
        return JournalViewModel.DailyHabitCompletion(
            id: date, date: date, count: count
        )
    }

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            SentimentTrendChart(
                data: data,
                habitCompletionData: habitData
            )
        }
        .padding(24)
    }
    .frame(width: 700, height: 400)
}

#Preview("Sentiment Trend — Empty") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            SentimentTrendChart(data: [])
        }
        .padding(24)
    }
    .frame(width: 700, height: 400)
}
