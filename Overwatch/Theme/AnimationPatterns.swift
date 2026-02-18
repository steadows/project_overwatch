import SwiftUI

// MARK: - Materialize Effect

/// Element "powers on" — wireframe traces in, fill sweeps, content fades up, glow flashes.
/// Used for: new panels appearing, dashboard sections on load, onboarding steps entering.
struct MaterializeEffect: ViewModifier {
    var isVisible: Bool
    var delay: Double

    @State private var frameVisible = false
    @State private var fillVisible = false
    @State private var contentVisible = false
    @State private var glowFlash = false

    func body(content: Content) -> some View {
        content
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 6)
            .brightness(glowFlash ? 0.15 : 0)
            .onChange(of: isVisible) { _, visible in
                runSequence(visible: visible)
            }
            .onAppear {
                if isVisible {
                    runSequence(visible: true)
                }
            }
    }

    private func runSequence(visible: Bool) {
        if visible {
            // Phase 1: Frame trace (0.0-0.3s) — handled by wireframeTrace if applied
            withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                frameVisible = true
            }
            // Phase 2: Fill sweep (0.2-0.4s)
            withAnimation(.easeOut(duration: 0.2).delay(delay + 0.2)) {
                fillVisible = true
            }
            // Phase 3: Content fade + drift (0.3-0.5s)
            withAnimation(.easeOut(duration: 0.2).delay(delay + 0.3)) {
                contentVisible = true
            }
            // Phase 4: Glow flash (0.4-0.6s)
            withAnimation(.easeIn(duration: 0.1).delay(delay + 0.4)) {
                glowFlash = true
            }
            withAnimation(.easeOut(duration: 0.2).delay(delay + 0.5)) {
                glowFlash = false
            }
        } else {
            // Reverse — quick dissolve
            withAnimation(.easeIn(duration: 0.15)) {
                contentVisible = false
                fillVisible = false
            }
            withAnimation(.easeIn(duration: 0.1).delay(0.1)) {
                frameVisible = false
                glowFlash = false
            }
        }
    }
}

// MARK: - Dissolve Effect

/// Reverse of materialize — content fades, fill dissolves, frame fades.
/// Used for: panels being removed, navigating away, dismissing sheets.
struct DissolveEffect: ViewModifier {
    var isVisible: Bool

    @State private var contentOpacity: Double = 0
    @State private var frameOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(contentOpacity)
            .scaleEffect(isVisible ? 1.0 : 0.98)
            .onChange(of: isVisible) { _, visible in
                runSequence(visible: visible)
            }
            .onAppear {
                if isVisible {
                    withAnimation(.easeOut(duration: 0.2)) {
                        contentOpacity = 1
                        frameOpacity = 1
                    }
                }
            }
    }

    private func runSequence(visible: Bool) {
        if visible {
            withAnimation(.easeOut(duration: 0.25)) {
                frameOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                contentOpacity = 1
            }
        } else {
            // Phase 1: Content fade (0.0-0.15s)
            withAnimation(.easeIn(duration: 0.15)) {
                contentOpacity = 0
            }
            // Phase 2: Frame fade (0.2-0.35s)
            withAnimation(.easeIn(duration: 0.15).delay(0.2)) {
                frameOpacity = 0
            }
        }
    }
}

// MARK: - Slide Reveal / Retract Effect

/// Panel slides open to reveal content — like a Jarvis interface splitting.
/// Used for: habit toggle expand, WHOOP strip expanding, report card detail.
struct SlideRevealEffect: ViewModifier {
    var isExpanded: Bool

    func body(content: Content) -> some View {
        content
            .clipShape(Rectangle())
            .scaleEffect(y: isExpanded ? 1 : 0, anchor: .top)
            .opacity(isExpanded ? 1 : 0)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.85),
                value: isExpanded
            )
    }
}

// MARK: - Glow Pulse Effect (One-Shot)

/// Brief bright flash that confirms an action — spike + decay.
/// Used for: habit toggle completion, button presses, data sync complete.
struct GlowPulseEffect: ViewModifier {
    var trigger: Bool
    var color: Color

    @State private var pulseActive = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(pulseActive ? 0.8 : 0),
                radius: pulseActive ? 16 : 0
            )
            .brightness(pulseActive ? 0.12 : 0)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    // Spike
                    withAnimation(.easeIn(duration: 0.1)) {
                        pulseActive = true
                    }
                    // Decay
                    withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                        pulseActive = false
                    }
                }
            }
    }
}

// MARK: - Stagger Effect

/// Delays appearance based on index — for sequential list/grid animations.
/// Used for: dashboard sections, habit list rows, chart data points, onboarding steps.
struct StaggerEffect: ViewModifier {
    var index: Int
    var delayPerItem: Double

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.8)
                    .delay(Double(index) * delayPerItem),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

// MARK: - Section Transition Effect

/// Sidebar navigation transition — fade + subtle scale for view switching.
/// Used for: every sidebar section change. Fast — total ≤0.3s.
struct SectionTransitionEffect: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1.0 : 0.98)
            .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - View Extensions

extension View {
    /// Materialize animation — element "powers on" with phased trace → fill → content → glow.
    func materializeEffect(isVisible: Bool, delay: Double = 0) -> some View {
        modifier(MaterializeEffect(isVisible: isVisible, delay: delay))
    }

    /// Dissolve animation — reverse of materialize. Content fades → fill dissolves → frame fades.
    func dissolveEffect(isVisible: Bool) -> some View {
        modifier(DissolveEffect(isVisible: isVisible))
    }

    /// Slide-reveal animation — panel expands open with spring physics.
    /// Apply to the **revealed content**, not the parent.
    func slideRevealEffect(isExpanded: Bool) -> some View {
        modifier(SlideRevealEffect(isExpanded: isExpanded))
    }

    /// One-shot glow pulse — bright flash on trigger for action confirmation.
    func glowPulseEffect(trigger: Bool, color: Color = OverwatchTheme.accentCyan) -> some View {
        modifier(GlowPulseEffect(trigger: trigger, color: color))
    }

    /// Stagger effect — delays appearance by index for sequential animations.
    func staggerEffect(index: Int, delayPerItem: Double = 0.1) -> some View {
        modifier(StaggerEffect(index: index, delayPerItem: delayPerItem))
    }

    /// Section transition — fade + scale for sidebar view switching.
    func sectionTransition(isActive: Bool) -> some View {
        modifier(SectionTransitionEffect(isActive: isActive))
    }
}

// MARK: - Preview

#Preview("Animation Patterns") {
    struct Demo: View {
        @State private var showCards = false
        @State private var expandDetail = false
        @State private var pulseConfirm = false

        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    Text("ANIMATION PATTERNS")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(2)

                    HUDDivider()

                    // Materialize demo
                    Text("MATERIALIZE")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(1.5)

                    ForEach(0..<3, id: \.self) { i in
                        TacticalCard {
                            HStack {
                                Image(systemName: "diamond.fill")
                                    .foregroundStyle(OverwatchTheme.accentCyan)
                                Text("PANEL \(i + 1)")
                                    .font(Typography.metricMedium)
                                    .foregroundStyle(OverwatchTheme.textPrimary)
                            }
                        }
                        .frame(width: 260)
                        .materializeEffect(isVisible: showCards, delay: Double(i) * 0.12)
                    }

                    HUDDivider()

                    // Slide Reveal demo
                    Text("SLIDE REVEAL")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(1.5)

                    VStack(spacing: 0) {
                        Button(action: { expandDetail.toggle() }) {
                            HStack {
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(expandDetail ? 90 : 0))
                                    .animation(.spring(response: 0.3), value: expandDetail)
                                Text("EXPAND DETAIL")
                                    .font(Typography.hudLabel)
                                    .tracking(1.5)
                            }
                            .foregroundStyle(OverwatchTheme.accentCyan)
                        }
                        .buttonStyle(.plain)

                        if expandDetail {
                            TacticalCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("REVEALED CONTENT")
                                        .font(Typography.hudLabel)
                                        .foregroundStyle(OverwatchTheme.accentCyan)
                                        .tracking(1.5)
                                    Text("This panel slides open with spring physics.")
                                        .font(Typography.caption)
                                        .foregroundStyle(OverwatchTheme.textSecondary)
                                }
                            }
                            .frame(width: 260)
                            .slideRevealEffect(isExpanded: expandDetail)
                        }
                    }

                    HUDDivider()

                    // Glow Pulse demo
                    Text("GLOW PULSE")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(1.5)

                    Button("CONFIRM ACTION") {
                        pulseConfirm = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            pulseConfirm = false
                        }
                    }
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .tracking(1.5)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        HUDFrameShape(chamferSize: 8)
                            .fill(OverwatchTheme.surface)
                    )
                    .overlay(
                        HUDFrameShape(chamferSize: 8)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.5), lineWidth: 1)
                    )
                    .glowPulseEffect(trigger: pulseConfirm)

                    Spacer(minLength: 20)

                    Button(showCards ? "DISSOLVE" : "MATERIALIZE") {
                        showCards.toggle()
                    }
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.textPrimary)
                    .tracking(1.5)
                }
                .padding(32)
            }
            .frame(width: 400, height: 700)
            .background(OverwatchTheme.background)
        }
    }
    return Demo()
}
