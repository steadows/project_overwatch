import SwiftUI

/// Compact horizontal WHOOP metrics strip — single row of mini metric tiles.
///
/// Three states:
/// 1. **Data** — full metrics strip, tap to expand arc gauges
/// 2. **Error** — dimmed cached data + "BIOMETRIC SIGNAL LOST" overlay + retry
/// 3. **No connection** — "LINK BIOMETRIC SOURCE" prompt + navigate to Settings
struct CompactWhoopStrip: View {
    let metrics: DashboardViewModel.WhoopMetrics
    let hasData: Bool
    let errorMessage: String?
    @Binding var isExpanded: Bool
    var onRetry: (() -> Void)?
    var onNavigateToSettings: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if hasData {
                if let errorMessage {
                    // State 2: API error — show dimmed data + error badge
                    compactStrip
                        .opacity(0.4)
                    HUDStatusBadge.whoopSignalLost(detail: errorMessage) {
                        onRetry?()
                    }
                    .padding(.top, OverwatchTheme.Spacing.sm)
                } else {
                    // State 1: Healthy data
                    compactStrip
                    expandedGauges
                }
            } else {
                // State 3: No connection
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
        Button {
            onNavigateToSettings?()
        } label: {
            HUDStatusBadge.linkBiometricSource {
                onNavigateToSettings?()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Compact WHOOP Strip") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        VStack(spacing: 20) {
            // Healthy data
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
                errorMessage: nil,
                isExpanded: .constant(false)
            )

            // API error with cached data
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
                errorMessage: "Connection timed out",
                isExpanded: .constant(false),
                onRetry: {}
            )

            // No connection
            CompactWhoopStrip(
                metrics: .empty,
                hasData: false,
                errorMessage: nil,
                isExpanded: .constant(false),
                onNavigateToSettings: {}
            )
        }
        .padding()
        .frame(width: 600)
    }
    .frame(width: 700, height: 600)
}
