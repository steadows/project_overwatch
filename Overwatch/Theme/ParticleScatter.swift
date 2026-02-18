import SwiftUI

// MARK: - Particle Scatter

/// Burst particle animation triggered on interaction.
/// Particles explode outward from center and fade — used for habit completions,
/// streak milestones, button confirmations.
struct ParticleScatterView: View {
    @Binding var trigger: Bool
    var particleCount: Int = 10
    var burstRadius: CGFloat = 40
    var fadeDuration: Double = 0.5
    var color: Color = OverwatchTheme.accentCyan

    @State private var particles: [Particle] = []
    @State private var animationStart: Date = .distantPast

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(animationStart)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for particle in particles {
                    let t = elapsed / fadeDuration
                    guard t <= 1.2 else { continue } // small buffer past fade

                    // Ease-out position
                    let easedT = 1 - pow(1 - min(t, 1.0), 2)
                    let x = center.x + particle.dx * burstRadius * easedT
                    let y = center.y + particle.dy * burstRadius * easedT

                    // Fade from full to zero
                    let alpha = max(0, 1 - t)

                    let dotSize = particle.size
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )

                    // Glow shadow
                    context.drawLayer { ctx in
                        ctx.addFilter(.shadow(color: color.opacity(alpha * 0.6), radius: 3))
                        ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: trigger) { _, newValue in
            if newValue {
                spawnParticles()
                DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration + 0.1) {
                    trigger = false
                }
            }
        }
    }

    private func spawnParticles() {
        animationStart = Date()
        particles = (0..<particleCount).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 0.5...1.0)
            return Particle(
                dx: CGFloat(cos(angle) * speed),
                dy: CGFloat(sin(angle) * speed),
                size: CGFloat.random(in: 2...3.5)
            )
        }
    }
}

// MARK: - Particle Data

private struct Particle {
    let dx: CGFloat
    let dy: CGFloat
    let size: CGFloat
}

// MARK: - View Extension

extension View {
    /// Overlays a particle scatter burst, triggered when `trigger` becomes true.
    /// Trigger resets automatically after the animation completes.
    func particleScatter(
        trigger: Binding<Bool>,
        particleCount: Int = 10,
        burstRadius: CGFloat = 40,
        color: Color = OverwatchTheme.accentCyan
    ) -> some View {
        self.overlay(
            ParticleScatterView(
                trigger: trigger,
                particleCount: particleCount,
                burstRadius: burstRadius,
                color: color
            )
        )
    }
}

// MARK: - Preview

#Preview("Particle Scatter") {
    struct Demo: View {
        @State private var trigger = false

        var body: some View {
            VStack(spacing: 40) {
                Text("PARTICLE SCATTER")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .tracking(2)

                ZStack {
                    Circle()
                        .fill(OverwatchTheme.surface)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(OverwatchTheme.accentCyan.opacity(0.5), lineWidth: 1.5)
                        )

                    Image(systemName: "checkmark")
                        .font(.title2)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                }
                .particleScatter(trigger: $trigger, burstRadius: 50)

                HStack(spacing: 20) {
                    Button("CYAN BURST") { trigger = true }

                    BurstButton(label: "GREEN", color: .green)
                    BurstButton(label: "AMBER", color: OverwatchTheme.accentPrimary)
                }
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan)
                .tracking(1.5)
            }
            .padding(40)
            .frame(width: 500, height: 400)
            .background(OverwatchTheme.background)
        }
    }

    struct BurstButton: View {
        let label: String
        let color: Color
        @State private var fire = false

        var body: some View {
            Button(label) { fire = true }
                .particleScatter(trigger: $fire, color: color)
        }
    }

    return Demo()
}
