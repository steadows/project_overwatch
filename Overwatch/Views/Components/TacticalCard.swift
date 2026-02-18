import SwiftUI

/// HUD panel container — chamfered frame, bright border, scan-line texture, decorative accents.
/// NOT a rounded rectangle. Uses HUDFrameShape for the distinctive angular sci-fi look.
struct TacticalCard<Content: View>: View {
    var glowColor: Color = OverwatchTheme.accentCyan
    var chamferSize: CGFloat = 14
    let content: Content

    @State private var appeared = false

    init(
        glowColor: Color = OverwatchTheme.accentCyan,
        chamferSize: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) {
        self.glowColor = glowColor
        self.chamferSize = chamferSize
        self.content = content()
    }

    private var frameShape: HUDFrameShape {
        HUDFrameShape(chamferSize: chamferSize)
    }

    var body: some View {
        content
            .padding(OverwatchTheme.Spacing.lg)
            // Translucent background — grid and data stream bleed through for depth
            .background(OverwatchTheme.surfaceTranslucent)
            // Subtle inner glow gradient at top edge — holographic light spill
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [glowColor.opacity(0.06), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 40)
                .clipShape(frameShape)
                .allowsHitTesting(false)
            }
            // Scan lines clipped to frame — drifting for alive feel
            .overlay(ScanLineOverlay(drifting: true).clipShape(frameShape))
            // Clip content to chamfered shape
            .clipShape(frameShape)
            // Wireframe trace — border draws itself on appear
            .wireframeTrace(
                frameShape,
                isVisible: appeared,
                duration: 0.5,
                strokeWidth: 1.5,
                color: glowColor.opacity(0.8)
            )
            // Frame accent decorations (lines, dots, tick marks)
            .overlay(
                FrameAccents(color: glowColor, chamferSize: chamferSize)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.35), value: appeared)
            )
            // Glow bloom — cranked for holographic feel
            .shadow(color: glowColor.opacity(appeared ? 0.5 : 0), radius: 8)
            .shadow(color: glowColor.opacity(appeared ? 0.25 : 0), radius: 28)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
            .onAppear { appeared = true }
    }
}

#Preview {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        ScanLineOverlay().ignoresSafeArea()

        VStack(spacing: 20) {
            TacticalCard {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                    Text("RECOVERY")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(1.5)
                    Text("87%")
                        .font(Typography.metricLarge)
                        .foregroundStyle(OverwatchTheme.accentSecondary)
                        .shadow(color: OverwatchTheme.accentSecondary.opacity(0.4), radius: 6)
                }
                .frame(width: 160)
            }

            TacticalCard(glowColor: OverwatchTheme.accentPrimary) {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                    Text("STRAIN")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(1.5)
                    Text("14.2")
                        .font(Typography.metricLarge)
                        .foregroundStyle(OverwatchTheme.accentPrimary)
                        .shadow(color: OverwatchTheme.accentPrimary.opacity(0.4), radius: 6)
                }
                .frame(width: 160)
            }
        }
    }
    .frame(width: 300, height: 320)
}
