import SwiftUI

/// Reusable HUD-themed inline status badge for error, warning, and degraded states.
///
/// Follows the tactical HUD aesthetic — chamfered frame, glow, monospace labels.
/// Use in any view where a system state needs to be communicated inline.
struct HUDStatusBadge: View {
    let icon: String
    let label: String
    let detail: String?
    let color: Color
    let action: (() -> Void)?
    let actionLabel: String?

    init(
        icon: String,
        label: String,
        detail: String? = nil,
        color: Color = OverwatchTheme.alert,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.label = label
        self.detail = detail
        self.color = color
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        HStack(spacing: OverwatchTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(color.opacity(0.7))
                .textGlow(color, radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.hudLabel)
                    .foregroundStyle(color.opacity(0.8))
                    .tracking(2)
                    .textGlow(color, radius: 3)

                if let detail {
                    Text(detail)
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                }
            }

            Spacer()

            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Typography.hudLabel)
                        .tracking(1.5)
                        .foregroundStyle(color.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.06))
                        .clipShape(HUDFrameShape(chamferSize: 6))
                        .overlay(
                            HUDFrameShape(chamferSize: 6)
                                .stroke(color.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, OverwatchTheme.Spacing.lg)
        .padding(.vertical, OverwatchTheme.Spacing.md)
        .background(color.opacity(0.04))
        .clipShape(HUDFrameShape(chamferSize: 10))
        .overlay(
            HUDFrameShape(chamferSize: 10)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Preset Constructors

extension HUDStatusBadge {
    /// "BIOMETRIC SIGNAL LOST" — WHOOP API error with retry
    static func whoopSignalLost(
        detail: String? = nil,
        onRetry: @escaping () -> Void
    ) -> HUDStatusBadge {
        HUDStatusBadge(
            icon: "antenna.radiowaves.left.and.right.slash",
            label: "BIOMETRIC SIGNAL LOST",
            detail: detail ?? "WHOOP API error — showing cached data",
            color: OverwatchTheme.alert,
            actionLabel: "RETRY",
            action: onRetry
        )
    }

    /// "LINK BIOMETRIC SOURCE" — no WHOOP connection
    static func linkBiometricSource(
        onLink: @escaping () -> Void
    ) -> HUDStatusBadge {
        HUDStatusBadge(
            icon: "antenna.radiowaves.left.and.right",
            label: "LINK BIOMETRIC SOURCE",
            detail: "Connect WHOOP in Settings to enable biometric tracking",
            color: OverwatchTheme.accentCyan,
            actionLabel: "LINK",
            action: onLink
        )
    }

    /// "INTELLIGENCE CORE OFFLINE" — no Gemini API key
    static func intelligenceOffline(
        onConfigure: (() -> Void)? = nil
    ) -> HUDStatusBadge {
        HUDStatusBadge(
            icon: "brain",
            label: "INTELLIGENCE CORE OFFLINE",
            detail: "Configure Gemini API key in Settings to enable AI insights",
            color: OverwatchTheme.accentPrimary,
            actionLabel: onConfigure != nil ? "CONFIGURE" : nil,
            action: onConfigure
        )
    }

    /// "INTELLIGENCE CORE THROTTLED" — Gemini rate limited
    static func intelligenceThrottled(
        retryDetail: String = "Rate limit exceeded — try again later"
    ) -> HUDStatusBadge {
        HUDStatusBadge(
            icon: "gauge.with.dots.needle.33percent",
            label: "INTELLIGENCE CORE THROTTLED",
            detail: retryDetail,
            color: OverwatchTheme.accentPrimary
        )
    }

    /// "INSUFFICIENT DATA" — not enough data for analysis
    static func insufficientData(
        detail: String = "Continue tracking for deeper insights"
    ) -> HUDStatusBadge {
        HUDStatusBadge(
            icon: "chart.xyaxis.line",
            label: "INSUFFICIENT DATA",
            detail: detail,
            color: OverwatchTheme.accentCyan
        )
    }
}

#Preview("HUD Status Badges") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        VStack(spacing: 16) {
            HUDStatusBadge.whoopSignalLost { }
            HUDStatusBadge.linkBiometricSource { }
            HUDStatusBadge.intelligenceOffline { }
            HUDStatusBadge.intelligenceThrottled()
            HUDStatusBadge.insufficientData(detail: "Minimum 7 days of data required")
        }
        .padding()
        .frame(width: 500)
    }
    .frame(width: 600, height: 500)
}
