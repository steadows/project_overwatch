import SwiftUI

/// Reusable SF Symbol icon for habits — replaces Text(emoji) everywhere.
/// Renders as a glowing monoline icon in accentCyan by default.
/// Falls back to emoji text if no iconName is set, or a default dot if both are empty.
struct HabitIcon: View {
    let iconName: String
    let emoji: String
    var size: CGFloat = 16
    var color: Color = OverwatchTheme.accentCyan

    var body: some View {
        if !iconName.isEmpty {
            Image(systemName: iconName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.4), radius: 4)
        } else if !emoji.isEmpty {
            Text(emoji).font(.system(size: size))
        } else {
            Image(systemName: "circle.fill")
                .font(.system(size: size * 0.5))
                .foregroundStyle(color.opacity(0.5))
        }
    }
}

#Preview("Habit Icons") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()

        HStack(spacing: 20) {
            HabitIcon(iconName: "brain.head.profile", emoji: "")
            HabitIcon(iconName: "figure.run", emoji: "")
            HabitIcon(iconName: "drop", emoji: "", size: 20)
            HabitIcon(iconName: "", emoji: "🧘")
            HabitIcon(iconName: "", emoji: "")
        }
    }
    .frame(width: 400, height: 100)
}
