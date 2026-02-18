import SwiftUI

/// Stub — split-pane analytics with AI briefing + charts (Phase 7.4).
struct WarRoomView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                stubHeader("WAR ROOM", subtitle: "STRATEGIC INTELLIGENCE")

                TacticalCard {
                    VStack(spacing: OverwatchTheme.Spacing.lg) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.3))
                            .shadow(color: OverwatchTheme.accentCyan.opacity(0.2), radius: 8)

                        Text("AWAITING INTELLIGENCE DATA")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                            .tracking(2)

                        Text("AI-powered analytics, correlation charts, and performance insights.")
                            .font(Typography.caption)
                            .foregroundStyle(OverwatchTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OverwatchTheme.Spacing.xxl)
                }
            }
            .padding(OverwatchTheme.Spacing.xl)
        }
    }
}

#Preview {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        WarRoomView()
    }
    .frame(width: 700, height: 500)
}
