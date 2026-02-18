import SwiftUI

/// Rectangular metric display — icon, label, value, optional trend and progress bar.
/// HUD instrument style: cyan tracked labels, glowing data readout.
/// For percentage metrics, prefer ArcGauge instead.
struct MetricTile: View {
    let icon: String        // SF Symbol name
    let label: String       // e.g., "STRAIN"
    let value: String       // e.g., "14.2"
    let color: Color        // Performance-based color
    var trend: Trend?       // Optional trend indicator
    var progress: Double?   // Optional 0-1 progress bar

    enum Trend {
        case up, down, flat

        var icon: String {
            switch self {
            case .up: "arrow.up.right"
            case .down: "arrow.down.right"
            case .flat: "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: OverwatchTheme.accentSecondary
            case .down: OverwatchTheme.alert
            case .flat: OverwatchTheme.textSecondary
            }
        }
    }

    var body: some View {
        TacticalCard(glowColor: color) {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                // Header: icon + label
                HStack(spacing: OverwatchTheme.Spacing.xs) {
                    Image(systemName: icon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(color)
                        .font(.system(size: 14, weight: .medium))
                        .textGlow(color, radius: 4)

                    Text(label)
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .textCase(.uppercase)
                        .tracking(3)
                        .textGlow(OverwatchTheme.accentCyan, radius: 3)
                }

                // Value + trend
                HStack(alignment: .lastTextBaseline, spacing: OverwatchTheme.Spacing.xs) {
                    Text(value)
                        .font(Typography.metricLarge)
                        .foregroundStyle(color)
                        .textGlow(color, radius: 10)
                        .contentTransition(.numericText())

                    if let trend {
                        Image(systemName: trend.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(trend.color)
                            .textGlow(trend.color, radius: 4)
                    }
                }

                // Optional progress bar
                if let progress {
                    HUDProgressBar(progress: progress, color: color)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        ScanLineOverlay().ignoresSafeArea()

        HStack(spacing: OverwatchTheme.Spacing.md) {
            MetricTile(
                icon: "flame.fill",
                label: "Strain",
                value: "14.2",
                color: OverwatchTheme.accentPrimary,
                trend: .flat
            )

            MetricTile(
                icon: "waveform.path.ecg",
                label: "HRV",
                value: "67",
                color: OverwatchTheme.accentCyan
            )
        }
        .padding()
    }
    .frame(width: 500, height: 200)
}
