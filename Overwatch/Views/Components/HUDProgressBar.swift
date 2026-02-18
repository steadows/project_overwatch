import SwiftUI

/// Glowing instrument gauge bar — fills proportionally with a visible glow halo.
struct HUDProgressBar: View {
    let progress: Double  // 0.0 to 1.0
    var color: Color = OverwatchTheme.accentCyan

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(OverwatchTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5)
                            .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
                    )

                // Fill with glow
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: geometry.size.width * clampedProgress)
                    .shadow(color: color.opacity(0.7), radius: 4)
            }
        }
        .frame(height: 3)
    }
}

#Preview {
    VStack(spacing: 16) {
        HUDProgressBar(progress: 0.87, color: OverwatchTheme.accentSecondary)
        HUDProgressBar(progress: 0.52, color: OverwatchTheme.accentPrimary)
        HUDProgressBar(progress: 0.15, color: OverwatchTheme.alert)
        HUDProgressBar(progress: 0.70, color: OverwatchTheme.accentCyan)
    }
    .padding(24)
    .background(OverwatchTheme.surface)
    .background(OverwatchTheme.background)
}
