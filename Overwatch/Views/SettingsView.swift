import SwiftUI

/// Stub — connections, API keys, preferences (Phase 9.1).
struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                stubHeader("SETTINGS", subtitle: "SYSTEM CONFIGURATION")

                TacticalCard {
                    VStack(spacing: OverwatchTheme.Spacing.lg) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.3))
                            .shadow(color: OverwatchTheme.accentCyan.opacity(0.2), radius: 8)

                        Text("CONFIGURATION PENDING")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                            .tracking(2)

                        Text("Connections, API keys, report schedules, and data management.")
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
        SettingsView()
    }
    .frame(width: 700, height: 500)
}
