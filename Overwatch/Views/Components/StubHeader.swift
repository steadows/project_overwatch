import SwiftUI

/// Shared header for stub/placeholder views. Consistent HUD styling across all future pages.
/// Used by: HabitsView, WarRoomView, ReportsView, SettingsView (until they get their real implementations).
@MainActor
func stubHeader(_ title: String, subtitle: String) -> some View {
    VStack(spacing: OverwatchTheme.Spacing.md) {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                Text(title)
                    .font(Typography.largeTitle)
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .tracking(6)
                    .textGlow(OverwatchTheme.accentCyan, radius: 20)

                Text(subtitle)
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.45))
                    .tracking(5)
                    .textGlow(OverwatchTheme.accentCyan, radius: 4)
            }

            Spacer()
        }

        HUDDivider(color: OverwatchTheme.accentCyan)
    }
}
