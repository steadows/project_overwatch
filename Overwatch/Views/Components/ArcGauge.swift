import SwiftUI

/// Circular ring gauge for percentage metrics — the sci-fi instrument dial.
/// 270° arc with glowing fill, value in center, label below.
struct ArcGauge: View {
    let value: Double   // 0–100
    let label: String
    let icon: String
    let color: Color

    private let ringSize: CGFloat = 74
    private let trackWidth: CGFloat = 3.5
    private let fillWidth: CGFloat = 5

    var body: some View {
        TacticalCard(glowColor: color) {
            VStack(spacing: OverwatchTheme.Spacing.sm) {
                gaugeRing
                labelRow
            }
        }
    }

    // MARK: - Ring

    private var gaugeRing: some View {
        ZStack {
            // Outer decorative ring (faint)
            Circle()
                .stroke(color.opacity(0.06), lineWidth: 1)
                .frame(width: ringSize + 12, height: ringSize + 12)

            // Tick marks around the arc
            ArcTickMarks(color: color.opacity(0.2), count: 24)
                .frame(width: ringSize + 6, height: ringSize + 6)

            // Background track (270°)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(color.opacity(0.1), style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Value fill arc
            Circle()
                .trim(from: 0, to: 0.75 * min(max(value / 100, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: fillWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: color.opacity(0.7), radius: 8)
                .shadow(color: color.opacity(0.3), radius: 20)

            // Center readout
            VStack(spacing: 0) {
                Text(String(format: "%.0f", value))
                    .font(Typography.metricMedium)
                    .foregroundStyle(color)
                    .textGlow(color, radius: 10)
                Text("%")
                    .font(Typography.metricTiny)
                    .foregroundStyle(color.opacity(0.5))
                    .textGlow(color, radius: 3)
            }
        }
        .frame(width: ringSize + 14, height: ringSize + 14)
    }

    // MARK: - Label

    private var labelRow: some View {
        HStack(spacing: OverwatchTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .textGlow(color, radius: 4)

            Text(label)
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan)
                .tracking(3)
                .textCase(.uppercase)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)
        }
    }
}

// MARK: - Tick Marks

/// Small radial tick marks around the gauge arc — adds mechanical precision detail.
struct ArcTickMarks: View {
    var color: Color
    var count: Int = 24

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let startAngle = 135.0   // degrees
            let sweep = 270.0

            for i in 0...count {
                let fraction = Double(i) / Double(count)
                let angle = (startAngle + sweep * fraction) * .pi / 180
                let innerRadius = radius - 4
                let outerRadius = radius

                let inner = CGPoint(
                    x: center.x + innerRadius * cos(angle),
                    y: center.y + innerRadius * sin(angle)
                )
                let outer = CGPoint(
                    x: center.x + outerRadius * cos(angle),
                    y: center.y + outerRadius * sin(angle)
                )

                var tick = Path()
                tick.move(to: inner)
                tick.addLine(to: outer)
                context.stroke(tick, with: .color(color), lineWidth: i % 6 == 0 ? 1.5 : 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        ScanLineOverlay().ignoresSafeArea()

        HStack(spacing: 16) {
            ArcGauge(
                value: 87,
                label: "Recovery",
                icon: "heart.fill",
                color: OverwatchTheme.accentSecondary
            )

            ArcGauge(
                value: 42,
                label: "Sleep",
                icon: "moon.fill",
                color: OverwatchTheme.alert
            )
        }
        .padding()
    }
    .frame(width: 500, height: 300)
}
