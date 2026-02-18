import SwiftUI

// MARK: - Data Stream Texture

/// Cascading character rain effect — subtle Matrix-style background texture.
/// Uses `TimelineView` + `Canvas` for GPU-friendly continuous animation.
/// Characters fade in at top and fade out at bottom via gradient mask.
struct DataStreamTexture: View {
    var color: Color = OverwatchTheme.accentCyan
    var opacity: Double = 0.04
    var scrollSpeed: CGFloat = 10 // pt per second
    var columnSpacing: CGFloat = 20
    var characterSet: [Character] = Array("0123456789ABCDEF>|.:+*#")

    @State private var columns: [StreamColumn] = []
    @State private var lastSize: CGSize = .zero

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                if columns.isEmpty { return }

                let now = timeline.date.timeIntervalSinceReferenceDate

                for column in columns {
                    for row in column.cells {
                        let yOffset = CGFloat(now - row.spawnTime) * scrollSpeed
                        let y = row.startY + yOffset.truncatingRemainder(dividingBy: size.height + 20) - 20

                        // Fade based on vertical position: fade in at top, fade out at bottom
                        let normalizedY = y / size.height
                        let fadeAlpha: CGFloat
                        if normalizedY < 0.1 {
                            fadeAlpha = normalizedY / 0.1
                        } else if normalizedY > 0.85 {
                            fadeAlpha = (1.0 - normalizedY) / 0.15
                        } else {
                            fadeAlpha = 1.0
                        }

                        guard fadeAlpha > 0.01 else { continue }

                        let text = Text(String(row.character))
                            .font(.system(size: 10, weight: .light, design: .monospaced))
                            .foregroundStyle(color.opacity(opacity * fadeAlpha * row.brightnessVariation))

                        context.draw(
                            context.resolve(text),
                            at: CGPoint(x: column.x, y: y)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { buildColumns(for: geo.size) }
                    .onChange(of: geo.size) { _, newSize in
                        if newSize != lastSize {
                            buildColumns(for: newSize)
                        }
                    }
            }
        )
    }

    private func buildColumns(for size: CGSize) {
        lastSize = size
        let columnCount = Int(size.width / columnSpacing)
        let rowsPerColumn = Int(size.height / 16) + 4 // 16pt per character row + overflow

        columns = (0..<columnCount).map { i in
            let x = CGFloat(i) * columnSpacing + columnSpacing / 2
            let cells = (0..<rowsPerColumn).map { j in
                StreamCell(
                    character: characterSet.randomElement() ?? "0",
                    startY: CGFloat(j) * 16 - 20,
                    spawnTime: Double.random(in: -100...0),
                    brightnessVariation: Double.random(in: 0.4...1.0)
                )
            }
            return StreamColumn(x: x, cells: cells)
        }
    }
}

// MARK: - Data Types

private struct StreamColumn: Identifiable {
    let id = UUID()
    let x: CGFloat
    let cells: [StreamCell]
}

private struct StreamCell {
    let character: Character
    let startY: CGFloat
    let spawnTime: TimeInterval
    let brightnessVariation: Double
}

// MARK: - View Extension

extension View {
    /// Adds a subtle cascading character rain background texture.
    func dataStreamTexture(
        color: Color = OverwatchTheme.accentCyan,
        opacity: Double = 0.04,
        speed: CGFloat = 10
    ) -> some View {
        self.background(
            DataStreamTexture(color: color, opacity: opacity, scrollSpeed: speed)
        )
    }
}

// MARK: - Preview

#Preview("Data Stream Texture") {
    ZStack {
        OverwatchTheme.background
            .ignoresSafeArea()

        DataStreamTexture()
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("DATA STREAM TEXTURE")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan)
                .tracking(2)

            Text("Subtle character rain behind content")
                .font(Typography.caption)
                .foregroundStyle(OverwatchTheme.textSecondary)

            TacticalCard {
                Text("CONTENT READS THROUGH")
                    .font(Typography.metricMedium)
                    .foregroundStyle(OverwatchTheme.textPrimary)
            }
            .frame(width: 300)
        }
    }
    .frame(width: 500, height: 400)
}
