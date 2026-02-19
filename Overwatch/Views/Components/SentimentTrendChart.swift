import SwiftUI
import Charts

/// Sentiment score trend chart — line chart with green/red zone fills,
/// neutral baseline, and date range selector. Follows HabitTrendChartView pattern.
struct SentimentTrendChart: View {
    let data: [JournalViewModel.SentimentDataPoint]

    @State private var dateRange: DateRange = .month

    enum DateRange: String, CaseIterable, Identifiable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"
        case all = "ALL"

        var id: String { rawValue }

        var dayCount: Int? {
            switch self {
            case .week: 7
            case .month: 30
            case .quarter: 90
            case .all: nil
            }
        }
    }

    private var filteredData: [JournalViewModel.SentimentDataPoint] {
        guard let days = dateRange.dayCount else { return data }
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -days,
            to: Calendar.current.startOfDay(for: .now)
        )!
        return data.filter { $0.date >= cutoff }
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
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: filteredData.count
                    )

                chartLegend
            } else {
                emptyState
            }
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
        }
    }

    // MARK: - Date Range Selector

    private var dateRangeSelector: some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            ForEach(DateRange.allCases) { range in
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
    }

    // MARK: - Chart

    private var sentimentChart: some View {
        Chart {
            // Positive area fill (green zone above 0)
            ForEach(filteredData) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Base", 0.0),
                    yEnd: .value("PosScore", max(0, point.score))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            OverwatchTheme.accentSecondary.opacity(0.12),
                            OverwatchTheme.accentSecondary.opacity(0.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Negative area fill (red zone below 0)
            ForEach(filteredData) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Base", 0.0),
                    yEnd: .value("NegScore", min(0, point.score))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            OverwatchTheme.alert.opacity(0.0),
                            OverwatchTheme.alert.opacity(0.12),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Neutral baseline
            RuleMark(y: .value("Neutral", 0))
                .foregroundStyle(
                    OverwatchTheme.textSecondary.opacity(0.3)
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Main line
            ForEach(filteredData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(OverwatchTheme.accentCyan)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Data points
            ForEach(filteredData) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(OverwatchTheme.accentCyan)
                .symbolSize(16)
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

    // MARK: - Legend

    private var chartLegend: some View {
        HStack(spacing: OverwatchTheme.Spacing.lg) {
            // Line legend
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(OverwatchTheme.accentCyan)
                    .frame(width: 16, height: 2)
                    .shadow(
                        color: OverwatchTheme.accentCyan.opacity(0.5),
                        radius: 3
                    )
                Text("SENTIMENT")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }

            // Positive zone legend
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(OverwatchTheme.accentSecondary.opacity(0.4))
                    .frame(width: 16, height: 6)
                Text("POSITIVE")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }

            // Negative zone legend
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(OverwatchTheme.alert.opacity(0.4))
                    .frame(width: 16, height: 6)
                Text("NEGATIVE")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
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

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            SentimentTrendChart(data: data)
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
