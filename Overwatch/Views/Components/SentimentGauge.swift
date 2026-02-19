import SwiftUI

/// Wellbeing index gauge — arc gauge showing average sentiment score
/// for the currently visible window. Receives pre-filtered data from
/// the parent (driven by SentimentTrendChart's range controls).
/// Color shifts dynamically from red (-1.0) through amber (0.0) to green (+1.0).
/// War Room-ready (Phase 6.5.12).
struct SentimentGauge: View {
    let sentimentData: [JournalViewModel.SentimentDataPoint]

    private var averageScore: Double {
        guard !sentimentData.isEmpty else { return 0 }
        return sentimentData.map(\.score).reduce(0, +) / Double(sentimentData.count)
    }

    /// Maps -1.0...+1.0 to 0...100 for arc fill percentage.
    private var arcPercentage: Double {
        ((averageScore + 1.0) / 2.0) * 100
    }

    private var gaugeColor: Color {
        if averageScore >= 0.33 { return OverwatchTheme.accentSecondary }
        if averageScore >= -0.33 { return OverwatchTheme.accentPrimary }
        return OverwatchTheme.alert
    }

    private var formattedScore: String {
        let sign = averageScore >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", averageScore))"
    }

    private let ringSize: CGFloat = 74
    private let trackWidth: CGFloat = 3.5
    private let fillWidth: CGFloat = 5

    var body: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            headerRow
            gaugeRing
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

            Text("// WELLBEING INDEX")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Spacer()

            Text("\(sentimentData.count) ENTRIES")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
                .tracking(1)
        }
    }

    // MARK: - Gauge Ring

    private var gaugeRing: some View {
        ZStack {
            // Outer decorative ring
            Circle()
                .stroke(gaugeColor.opacity(0.06), lineWidth: 1)
                .frame(width: ringSize + 12, height: ringSize + 12)

            // Tick marks
            ArcTickMarks(color: gaugeColor.opacity(0.2), count: 24)
                .frame(width: ringSize + 6, height: ringSize + 6)

            // Background track (270 degrees)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    gaugeColor.opacity(0.1),
                    style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            // Value fill arc
            Circle()
                .trim(from: 0, to: 0.75 * min(max(arcPercentage / 100, 0), 1))
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: fillWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: gaugeColor.opacity(0.7), radius: 8)
                .shadow(color: gaugeColor.opacity(0.3), radius: 20)

            // Center readout — shows actual score, not percentage
            VStack(spacing: 0) {
                Text(formattedScore)
                    .font(Typography.metricMedium)
                    .foregroundStyle(gaugeColor)
                    .textGlow(gaugeColor, radius: 10)
                Text("SCORE")
                    .font(Typography.metricTiny)
                    .foregroundStyle(gaugeColor.opacity(0.5))
                    .textGlow(gaugeColor, radius: 3)
            }
        }
        .frame(width: ringSize + 14, height: ringSize + 14)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: averageScore)
    }

}

// MARK: - Preview

#Preview("Sentiment Gauge") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let data = (0..<30).map { offset in
        let date = calendar.date(
            byAdding: .day, value: -(29 - offset), to: today
        )!
        let score = 0.3 + Double.random(in: -0.4...0.3)
        return JournalViewModel.SentimentDataPoint(
            id: date, date: date, score: max(-1, min(1, score))
        )
    }

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            SentimentGauge(sentimentData: data)
        }
        .frame(width: 220)
        .padding(24)
    }
    .frame(width: 400, height: 300)
}

#Preview("Sentiment Gauge — Negative") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let data = (0..<14).map { offset in
        let date = calendar.date(
            byAdding: .day, value: -(13 - offset), to: today
        )!
        let score = -0.5 + Double.random(in: -0.3...0.2)
        return JournalViewModel.SentimentDataPoint(
            id: date, date: date, score: max(-1, min(1, score))
        )
    }

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            SentimentGauge(sentimentData: data)
        }
        .frame(width: 220)
        .padding(24)
    }
    .frame(width: 400, height: 300)
}
