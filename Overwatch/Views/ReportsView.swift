import SwiftUI

/// Stub — weekly AI intel briefings archive (Phase 7.3).
struct ReportsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                stubHeader("REPORTS", subtitle: "INTEL BRIEFINGS")

                TacticalCard {
                    VStack(spacing: OverwatchTheme.Spacing.lg) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.3))
                            .shadow(color: OverwatchTheme.accentCyan.opacity(0.2), radius: 8)

                        Text("NO BRIEFINGS YET")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                            .tracking(2)

                        Text("Your first intel report generates after one week of tracking data.")
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
        ReportsView()
    }
    .frame(width: 700, height: 500)
}
