import SwiftUI

/// Compact horizontal WHOOP metrics strip — single row of mini metric tiles.
///
/// Tap to expand into full ArcGauge view. Shows "CONNECT WHOOP" prompt
/// when no biometric data is available.
struct CompactWhoopStrip: View {
    let metrics: DashboardViewModel.WhoopMetrics
    let hasData: Bool
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            if hasData {
                compactStrip
                expandedGauges
            } else {
                connectPrompt
            }
        }
    }

    // MARK: - Compact Strip

    private var compactStrip: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: OverwatchTheme.Spacing.md) {
                miniMetric(
                    icon: "heart.fill",
                    label: "REC",
                    value: String(format: "%.0f%%", metrics.recoveryScore),
                    color: OverwatchTheme.performanceColor(for: metrics.recoveryScore)
                )

                miniDivider

                miniMetric(
                    icon: "moon.fill",
                    label: "SLP",
                    value: String(format: "%.0f%%", metrics.sleepPerformance),
                    color: OverwatchTheme.performanceColor(for: metrics.sleepPerformance)
                )

                miniDivider

                miniMetric(
                    icon: "flame.fill",
                    label: "STR",
                    value: String(format: "%.1f", metrics.strain),
                    color: OverwatchTheme.accentPrimary
                )

                miniDivider

                miniMetric(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: String(format: "%.0f", metrics.hrvRmssd),
                    color: OverwatchTheme.accentCyan
                )

                Spacer()

                // Expand indicator
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            }
            .padding(.horizontal, OverwatchTheme.Spacing.lg)
            .padding(.vertical, OverwatchTheme.Spacing.md)
            .background(OverwatchTheme.surfaceTranslucent)
            .clipShape(HUDFrameShape(chamferSize: 10))
            .overlay(
                HUDFrameShape(chamferSize: 10)
                    .stroke(OverwatchTheme.accentCyan.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mini Metric

    private func miniMetric(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: OverwatchTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                    .tracking(1)

                Text(value)
                    .font(Typography.metricTiny)
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .textGlow(color, radius: 3)
            }
        }
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(OverwatchTheme.accentCyan.opacity(0.15))
            .frame(width: 1, height: 24)
    }

    // MARK: - Expanded Gauges

    @ViewBuilder
    private var expandedGauges: some View {
        if isExpanded {
            HStack(alignment: .center, spacing: OverwatchTheme.Spacing.md) {
                ArcGauge(
                    value: metrics.recoveryScore,
                    label: "Recovery",
                    icon: "heart.fill",
                    color: OverwatchTheme.performanceColor(for: metrics.recoveryScore)
                )

                ArcGauge(
                    value: metrics.sleepPerformance,
                    label: "Sleep",
                    icon: "moon.fill",
                    color: OverwatchTheme.performanceColor(for: metrics.sleepPerformance)
                )

                MetricTile(
                    icon: "flame.fill",
                    label: "Strain",
                    value: String(format: "%.1f", metrics.strain),
                    color: OverwatchTheme.accentPrimary
                )

                MetricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: String(format: "%.0f", metrics.hrvRmssd),
                    color: OverwatchTheme.accentCyan
                )
            }
            .padding(.top, OverwatchTheme.Spacing.sm)
            .slideRevealEffect(isExpanded: isExpanded)
        }
    }

    // MARK: - Connect Prompt

    private var connectPrompt: some View {
        HStack(spacing: OverwatchTheme.Spacing.md) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 16, weight: .ultraLight))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.3))

            VStack(alignment: .leading, spacing: 2) {
                Text("BIOMETRIC SOURCE OFFLINE")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                    .tracking(2)
                    .textGlow(OverwatchTheme.accentCyan, radius: 2)

                Text("Connect WHOOP in Settings to enable biometric tracking")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }

            Spacer()

            Text("LINK")
                .font(Typography.hudLabel)
                .tracking(1.5)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(OverwatchTheme.accentCyan.opacity(0.06))
                .clipShape(HUDFrameShape(chamferSize: 6))
                .overlay(
                    HUDFrameShape(chamferSize: 6)
                        .stroke(OverwatchTheme.accentCyan.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal, OverwatchTheme.Spacing.lg)
        .padding(.vertical, OverwatchTheme.Spacing.md)
        .background(OverwatchTheme.surfaceTranslucent)
        .clipShape(HUDFrameShape(chamferSize: 10))
        .overlay(
            HUDFrameShape(chamferSize: 10)
                .stroke(OverwatchTheme.accentCyan.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview("Compact WHOOP Strip") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        VStack(spacing: 20) {
            CompactWhoopStrip(
                metrics: .init(
                    recoveryScore: 78,
                    strain: 12.4,
                    sleepPerformance: 85,
                    restingHeartRate: 52,
                    hrvRmssd: 67,
                    lastSyncedAt: .now
                ),
                hasData: true,
                isExpanded: .constant(false)
            )

            CompactWhoopStrip(
                metrics: .empty,
                hasData: false,
                isExpanded: .constant(false)
            )
        }
        .padding()
        .frame(width: 600)
    }
    .frame(width: 700, height: 400)
}
