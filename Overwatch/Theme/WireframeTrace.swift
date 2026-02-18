import SwiftUI

// MARK: - Wireframe Trace Effect

/// Animatable border that "draws itself" along its path via `trim(from:to:)`.
/// Like a laser tracing the shape — used for Materialize animations, boot sequences, loading indicators.
struct WireframeTrace<S: Shape>: ViewModifier {
    let shape: S
    var isVisible: Bool
    var duration: Double
    var strokeWidth: CGFloat
    var color: Color

    @State private var trimEnd: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                shape
                    .trim(from: 0, to: trimEnd)
                    .stroke(color, lineWidth: strokeWidth)
                    .shadow(color: color.opacity(0.5), radius: 4)
            )
            .onChange(of: isVisible) { _, visible in
                if visible {
                    withAnimation(.easeOut(duration: duration)) {
                        trimEnd = 1
                    }
                } else {
                    withAnimation(.easeIn(duration: duration * 0.6)) {
                        trimEnd = 0
                    }
                }
            }
            .onAppear {
                if isVisible {
                    withAnimation(.easeOut(duration: duration)) {
                        trimEnd = 1
                    }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Draws a shape's border via animated `trim(from:to:)` — laser tracing effect.
    ///
    /// - Parameters:
    ///   - shape: The shape to trace (e.g., `HUDFrameShape()`, `RoundedRectangle(cornerRadius: 8)`)
    ///   - isVisible: When true, the border traces in; when false, it traces out
    ///   - duration: Trace-in duration (default 0.4s). Trace-out is 60% of this
    ///   - strokeWidth: Border line width (default 1.5pt)
    ///   - color: Stroke color (default: accentCyan)
    func wireframeTrace<S: Shape>(
        _ shape: S,
        isVisible: Bool,
        duration: Double = 0.4,
        strokeWidth: CGFloat = 1.5,
        color: Color = OverwatchTheme.accentCyan
    ) -> some View {
        modifier(WireframeTrace(
            shape: shape,
            isVisible: isVisible,
            duration: duration,
            strokeWidth: strokeWidth,
            color: color
        ))
    }
}

// MARK: - Preview

#Preview("Wireframe Trace") {
    struct Demo: View {
        @State private var show = false

        var body: some View {
            VStack(spacing: 40) {
                Text("WIREFRAME TRACE")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .tracking(2)

                RoundedRectangle(cornerRadius: 8)
                    .fill(OverwatchTheme.surface)
                    .frame(width: 200, height: 120)
                    .wireframeTrace(
                        RoundedRectangle(cornerRadius: 8),
                        isVisible: show
                    )

                Rectangle()
                    .fill(OverwatchTheme.surface)
                    .frame(width: 200, height: 120)
                    .clipShape(HUDFrameShape())
                    .wireframeTrace(
                        HUDFrameShape(),
                        isVisible: show,
                        duration: 0.6,
                        strokeWidth: 2,
                        color: OverwatchTheme.accentSecondary
                    )

                Circle()
                    .fill(OverwatchTheme.surface)
                    .frame(width: 100, height: 100)
                    .wireframeTrace(
                        Circle(),
                        isVisible: show,
                        color: OverwatchTheme.accentPrimary
                    )

                Button(show ? "HIDE" : "TRACE") {
                    show.toggle()
                }
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan)
                .tracking(1.5)
            }
            .padding(40)
            .frame(width: 400, height: 600)
            .background(OverwatchTheme.background)
        }
    }
    return Demo()
}
