import SwiftUI

/// Stub — full habit management page (Phase 5.1).
struct HabitsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                stubHeader("HABITS", subtitle: "OPERATION MANAGEMENT")

                TacticalCard {
                    VStack(spacing: OverwatchTheme.Spacing.lg) {
                        Image(systemName: "target")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.3))
                            .shadow(color: OverwatchTheme.accentCyan.opacity(0.2), radius: 8)

                        Text("AWAITING DEPLOYMENT")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                            .tracking(2)

                        Text("Full habit management, heat maps, and trend analysis.")
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
        HabitsView()
    }
    .frame(width: 700, height: 500)
}
