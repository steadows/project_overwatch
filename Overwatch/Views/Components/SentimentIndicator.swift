import SwiftUI

// MARK: - Sentiment Dot

/// 6pt color-coded circle with glow — green (positive), red (negative), gray (neutral).
struct SentimentDot: View {
    let label: String
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.6), radius: size / 2)
    }

    private var color: Color {
        switch label {
        case "positive": OverwatchTheme.accentSecondary
        case "negative": OverwatchTheme.alert
        default: OverwatchTheme.textSecondary
        }
    }
}

// MARK: - Sentiment Badge

/// Compact badge showing sentiment score, optional trend arrow, and label.
/// Displays as a capsule with color-coded background.
struct SentimentBadge: View {
    let score: Double
    let label: String
    var previousScore: Double? = nil

    var body: some View {
        HStack(spacing: OverwatchTheme.Spacing.xs) {
            SentimentDot(label: label)

            Text(String(format: "%+.2f", score))
                .font(Typography.metricTiny)
                .foregroundStyle(color)
                .monospacedDigit()

            if let previous = previousScore {
                let delta = score - previous
                Image(
                    systemName: delta > 0.05
                        ? "arrow.up.right"
                        : (delta < -0.05 ? "arrow.down.right" : "arrow.right")
                )
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(
                    delta > 0.05
                        ? OverwatchTheme.accentSecondary
                        : (delta < -0.05
                            ? OverwatchTheme.alert
                            : OverwatchTheme.textSecondary)
                )
            }

            Text(label.uppercased())
                .font(Typography.metricTiny)
                .foregroundStyle(color)
                .tracking(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.08))
        .clipShape(.capsule)
        .overlay(
            Capsule().stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    private var color: Color {
        switch label {
        case "positive": OverwatchTheme.accentSecondary
        case "negative": OverwatchTheme.alert
        default: OverwatchTheme.textSecondary
        }
    }
}

// MARK: - Preview

#Preview("Sentiment Indicators") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        VStack(spacing: OverwatchTheme.Spacing.xl) {
            HStack(spacing: OverwatchTheme.Spacing.lg) {
                SentimentDot(label: "positive")
                SentimentDot(label: "neutral")
                SentimentDot(label: "negative")
            }

            VStack(spacing: OverwatchTheme.Spacing.md) {
                SentimentBadge(
                    score: 0.42, label: "positive", previousScore: 0.28
                )
                SentimentBadge(score: -0.15, label: "negative")
                SentimentBadge(
                    score: 0.02, label: "neutral", previousScore: 0.04
                )
            }
        }
    }
    .frame(width: 400, height: 300)
}
