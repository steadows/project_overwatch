import SwiftUI

// MARK: - HUD Frame Shape

/// Custom frame with chamfered (45° diagonal cut) corners on top-right and bottom-left.
/// This is the signature sci-fi panel shape — NOT a rounded rectangle.
struct HUDFrameShape: Shape {
    var chamferSize: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let cs = chamferSize
        var path = Path()

        // Top-left (sharp)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top edge → top-right chamfer diagonal
        path.addLine(to: CGPoint(x: rect.maxX - cs, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cs))

        // Right edge → bottom-right (sharp)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // Bottom edge → bottom-left chamfer diagonal
        path.addLine(to: CGPoint(x: rect.minX + cs, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cs))

        path.closeSubpath()
        return path
    }
}

// MARK: - Frame Accent Decorations

/// Decorative lines, dots, and tick marks at chamfer inflection points.
/// Adds the "circuit board / targeting computer" detail to card frames.
struct FrameAccents: View {
    var color: Color = OverwatchTheme.accentCyan
    var chamferSize: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cs = chamferSize

            // --- Accent lines along edges near chamfer points ---
            var lines = Path()

            // Top edge: short accent line inside frame, near top-right chamfer
            lines.move(to: CGPoint(x: w - cs - 28, y: 3.5))
            lines.addLine(to: CGPoint(x: w - cs - 2, y: 3.5))

            // Bottom edge: short accent line inside frame, near bottom-left chamfer
            lines.move(to: CGPoint(x: cs + 2, y: h - 3.5))
            lines.addLine(to: CGPoint(x: cs + 28, y: h - 3.5))

            // Left edge: small vertical tick mark near top
            lines.move(to: CGPoint(x: 3.5, y: 6))
            lines.addLine(to: CGPoint(x: 3.5, y: 18))

            // Right edge: small vertical tick mark near bottom
            lines.move(to: CGPoint(x: w - 3.5, y: h - 6))
            lines.addLine(to: CGPoint(x: w - 3.5, y: h - 18))

            context.stroke(lines, with: .color(color.opacity(0.3)), lineWidth: 1)

            // --- Dots at chamfer diagonal midpoints ---
            let dotSize: CGFloat = 3
            let dots = [
                CGPoint(x: w - cs / 2, y: cs / 2),
                CGPoint(x: cs / 2, y: h - cs / 2),
            ]
            for dot in dots {
                let rect = CGRect(x: dot.x - dotSize / 2, y: dot.y - dotSize / 2,
                                  width: dotSize, height: dotSize)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.5)))
            }

            // --- Small corner marks at sharp corners ---
            var corners = Path()

            // Top-left: small L mark
            corners.move(to: CGPoint(x: 0, y: 8))
            corners.addLine(to: CGPoint(x: 0, y: 0))
            corners.addLine(to: CGPoint(x: 8, y: 0))

            // Bottom-right: small L mark
            corners.move(to: CGPoint(x: w, y: h - 8))
            corners.addLine(to: CGPoint(x: w, y: h))
            corners.addLine(to: CGPoint(x: w - 8, y: h))

            context.stroke(corners, with: .color(color.opacity(0.2)), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Scan Line Overlay

/// Horizontal scan lines with continuous upward drift — alive CRT texture.
/// Drift speed: 0.5pt/sec per Visual Design Spec.
struct ScanLineOverlay: View {
    var color: Color = OverwatchTheme.scanLine
    var drifting: Bool = true

    var body: some View {
        if drifting {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let spacing: CGFloat = 3
                    let lineHeight: CGFloat = 0.5
                    // 0.5pt/sec upward drift
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let offset = CGFloat(elapsed * 0.5).truncatingRemainder(dividingBy: spacing)

                    var y: CGFloat = -offset
                    while y < size.height + spacing {
                        let rect = CGRect(x: 0, y: y, width: size.width, height: lineHeight)
                        context.fill(Path(rect), with: .color(color))
                        y += spacing
                    }
                }
                .allowsHitTesting(false)
            }
        } else {
            Canvas { context, size in
                let spacing: CGFloat = 3
                let lineHeight: CGFloat = 0.5
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: lineHeight)
                    context.fill(Path(rect), with: .color(color))
                    y += spacing
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Grid Backdrop

/// Dot grid across the full background — digital space depth.
struct GridBackdrop: View {
    var dotColor: Color = OverwatchTheme.accentCyan.opacity(0.05)
    var spacing: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 1
            var x: CGFloat = spacing
            while x < size.width {
                var y: CGFloat = spacing
                while y < size.height {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2,
                                      width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    y += spacing
                }
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - HUD Divider

/// Decorative divider with diamond center marker.
struct HUDDivider: View {
    var color: Color = OverwatchTheme.accentCyan

    var body: some View {
        HStack(spacing: 0) {
            // Left line
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(height: 1)

            // Center diamond
            Diamond()
                .fill(color.opacity(0.7))
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.4), radius: 3)
                .padding(.horizontal, 8)

            // Right line
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(height: 1)
        }
        .frame(height: 6)
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - HUD Boot Effect

/// Fade-up entrance — starts 14pt below and transparent.
struct HUDBootEffect: ViewModifier {
    var delay: Double = 0
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
            .onAppear { appeared = true }
    }
}

// MARK: - Pulsing Glow

/// Animated glow that breathes — for active status indicators.
struct PulsingGlow: ViewModifier {
    var color: Color
    var radius: CGFloat = 8
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(glowing ? 0.8 : 0.2), radius: glowing ? radius : radius / 3)
            .animation(Animations.glowPulse, value: glowing)
            .onAppear { glowing = true }
    }
}

// MARK: - View Extensions

extension View {
    /// Dual-layer glow shadow (tight inner + wide outer bloom). Cranked for holographic feel.
    func hudGlow(color: Color = OverwatchTheme.accentCyan) -> some View {
        self
            .shadow(color: color.opacity(0.5), radius: 8)
            .shadow(color: color.opacity(0.25), radius: 28)
    }

    /// Makes text look like it's emitting light — projected, not painted.
    /// Use on colored text: cyan labels, green values, amber warnings.
    func textGlow(_ color: Color = OverwatchTheme.accentCyan, radius: CGFloat = 8) -> some View {
        self
            .shadow(color: color.opacity(0.6), radius: radius)
            .shadow(color: color.opacity(0.2), radius: radius * 2.5)
    }

    /// Boot-up fade-in animation.
    func hudBoot(delay: Double = 0) -> some View {
        modifier(HUDBootEffect(delay: delay))
    }

    /// Pulsing glow animation.
    func pulsingGlow(color: Color, radius: CGFloat = 8) -> some View {
        modifier(PulsingGlow(color: color, radius: radius))
    }
}
