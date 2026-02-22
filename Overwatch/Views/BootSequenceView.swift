import SwiftUI

// MARK: - Boot Sequence View

/// Cinematic 2-3 second boot intro using the HUD effects library.
///
/// Phases:
/// 1. Black void + cursor blink
/// 2. Grid lines trace from center outward
/// 3. Data stream fades in + system init text staggers line-by-line
/// 4. "OVERWATCH" logo materializes with glow bloom
/// 5. Dissolve → transition to NavigationShell
struct BootSequenceView: View {
    var isAbbreviated: Bool = false
    var onComplete: () -> Void

    @State private var phase: BootPhase = .void
    @State private var cursorVisible = true
    @State private var gridProgress: CGFloat = 0
    @State private var dataStreamOpacity: Double = 0
    @State private var visibleLines: Int = 0
    @State private var onlineFlags: [Bool] = Array(repeating: false, count: 3)
    @State private var logoVisible = false
    @State private var logoGlowRadius: CGFloat = 0
    @State private var dissolving = false

    private let initLines: [(label: String, status: String)] = [
        ("HABIT ENGINE", "ONLINE"),
        ("BIOMETRIC SYNC", "ONLINE"),
        ("INTELLIGENCE CORE", "ONLINE"),
    ]

    var body: some View {
        ZStack {
            OverwatchTheme.background
                .ignoresSafeArea()

            if !dissolving {
                gridLayer
                dataStreamLayer
                contentLayer
            }
        }
        .opacity(dissolving ? 0 : 1)
        .scaleEffect(dissolving ? 0.98 : 1.0)
        .onAppear(perform: isAbbreviated ? runAbbreviated : runFullSequence)
    }

    // MARK: - Grid Lines (Phase 2)

    private var gridLayer: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let maxSpan = max(size.width, size.height)

            let lineColor = OverwatchTheme.accentCyan
            let hCount = Int(size.height / 40)
            let vCount = Int(size.width / 40)

            for i in 0...hCount {
                let y = CGFloat(i) * 40
                let dist = abs(y - cy) / (size.height / 2)
                let lineProgress = max(0, min(1, (gridProgress - dist * 0.3) / 0.7))
                guard lineProgress > 0 else { continue }

                let halfW = (size.width / 2) * lineProgress
                var path = Path()
                path.move(to: CGPoint(x: cx - halfW, y: y))
                path.addLine(to: CGPoint(x: cx + halfW, y: y))
                context.stroke(path, with: .color(lineColor.opacity(0.06 * lineProgress)), lineWidth: 0.5)
            }

            for i in 0...vCount {
                let x = CGFloat(i) * 40
                let dist = abs(x - cx) / (size.width / 2)
                let lineProgress = max(0, min(1, (gridProgress - dist * 0.3) / 0.7))
                guard lineProgress > 0 else { continue }

                let halfH = (size.height / 2) * lineProgress
                var path = Path()
                path.move(to: CGPoint(x: x, y: cy - halfH))
                path.addLine(to: CGPoint(x: x, y: cy + halfH))
                context.stroke(path, with: .color(lineColor.opacity(0.06 * lineProgress)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - Data Stream (Phase 3)

    private var dataStreamLayer: some View {
        DataStreamTexture(opacity: 0.08)
            .opacity(dataStreamOpacity)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    // MARK: - Content (Phases 1, 3, 4)

    private var contentLayer: some View {
        VStack(spacing: 0) {
            Spacer()

            if phase.rawValue >= BootPhase.initText.rawValue {
                initTextBlock
                    .transition(.opacity)
            }

            if phase.rawValue >= BootPhase.logo.rawValue {
                logoBlock
                    .padding(.top, 32)
                    .transition(.opacity)
            }

            Spacer()

            if phase == .void || phase == .grid {
                cursorBlock
                    .transition(.opacity)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cursor Blink (Phase 1)

    private var cursorBlock: some View {
        Text("_")
            .font(.system(size: 16, weight: .light, design: .monospaced))
            .foregroundStyle(OverwatchTheme.accentCyan)
            .opacity(cursorVisible ? 1 : 0)
            .onAppear { startCursorBlink() }
    }

    // MARK: - Init Text (Phase 3)

    private var initTextBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if visibleLines >= 1 {
                bootTextLine("OVERWATCH v1.0 // SYSTEM INITIALIZATION", index: 0)
            }
            if visibleLines >= 2 {
                bootTextLine("LOADING MODULES...", index: 1)
            }

            ForEach(Array(initLines.enumerated()), id: \.offset) { i, line in
                if visibleLines >= i + 3 {
                    subsystemLine(label: line.label, status: line.status, isOnline: onlineFlags[i], index: i + 2)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func bootTextLine(_ text: String, index: Int) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .light, design: .monospaced))
            .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.8))
            .tracking(1.5)
            .opacity(visibleLines > index ? 1 : 0)
            .offset(y: visibleLines > index ? 0 : 6)
            .animation(.easeOut(duration: 0.2), value: visibleLines)
    }

    private func subsystemLine(label: String, status: String, isOnline: Bool, index: Int) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13, weight: .light, design: .monospaced))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.8))
                .tracking(1.5)

            Text(String(repeating: ".", count: 20 - label.count))
                .font(.system(size: 13, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.3))

            Text(" ")

            Text(status)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(isOnline ? OverwatchTheme.accentSecondary : OverwatchTheme.accentCyan.opacity(0.3))
                .textGlow(isOnline ? OverwatchTheme.accentSecondary : .clear, radius: 6)
                .tracking(2)
                .animation(.easeOut(duration: 0.3), value: isOnline)
        }
        .opacity(visibleLines > index ? 1 : 0)
        .offset(y: visibleLines > index ? 0 : 6)
        .animation(.easeOut(duration: 0.2), value: visibleLines)
    }

    // MARK: - Logo (Phase 4)

    private var logoBlock: some View {
        VStack(spacing: 8) {
            Text("OVERWATCH")
                .font(.custom("Futura-Medium", size: 48))
                .foregroundStyle(OverwatchTheme.accentCyan)
                .tracking(12)
                .opacity(logoVisible ? 1 : 0)
                .scaleEffect(logoVisible ? 1.0 : 0.9)
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.6), radius: logoGlowRadius)
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.2), radius: logoGlowRadius * 2.5)

            Text("TACTICAL PERFORMANCE INTELLIGENCE")
                .font(.system(size: 10, weight: .ultraLight, design: .default))
                .foregroundStyle(OverwatchTheme.textSecondary)
                .tracking(5)
                .opacity(logoVisible ? 1 : 0)
        }
    }

    // MARK: - Sequencing

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { timer in
            if phase.rawValue >= BootPhase.initText.rawValue {
                timer.invalidate()
                return
            }
            cursorVisible.toggle()
        }
    }

    private func runFullSequence() {
        // Phase 1 (0.0s): Void + cursor — already showing

        // Phase 2 (0.3s): Grid lines trace from center
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            phase = .grid
            withAnimation(.easeOut(duration: 0.8)) {
                gridProgress = 1.0
            }
        }

        // Phase 3 (0.6s): Data stream + init text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { phase = .initText }
            withAnimation(.easeIn(duration: 0.5)) {
                dataStreamOpacity = 1.0
            }
            staggerInitLines()
        }

        // Phase 4 (1.5s): Logo materialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { phase = .logo }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                logoVisible = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                logoGlowRadius = 32
            }
            withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
                logoGlowRadius = 16
            }
        }

        // Phase 5 (2.8s): Dissolve → complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeIn(duration: 0.5)) {
                dissolving = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
            onComplete()
        }
    }

    private func runAbbreviated() {
        phase = .logo

        // Fade in atmosphere
        withAnimation(.easeOut(duration: 0.6)) {
            gridProgress = 1.0
            dataStreamOpacity = 0.4
        }

        // Logo materializes
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            logoVisible = true
        }
        withAnimation(.easeOut(duration: 0.4)) {
            logoGlowRadius = 28
        }
        // Glow settles
        withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
            logoGlowRadius = 14
        }
        // Gentle glow pulse while holding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.5)) {
                logoGlowRadius = 20
            }
        }

        // Dissolve out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeIn(duration: 0.5)) {
                dissolving = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            onComplete()
        }
    }

    private func staggerInitLines() {
        let lineDelay = 0.1
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * lineDelay) {
                withAnimation {
                    visibleLines = i + 1
                }
            }
        }

        let subsystemBaseDelay = 5.0 * lineDelay
        for i in 0..<initLines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + subsystemBaseDelay + Double(i) * 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    onlineFlags[i] = true
                }
            }
        }
    }
}

// MARK: - Boot Phase

private enum BootPhase: Int, Comparable {
    case void = 0
    case grid = 1
    case initText = 2
    case logo = 3

    static func < (lhs: BootPhase, rhs: BootPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Root View (manages boot → app transition)

/// Wraps the boot sequence, onboarding, and NavigationShell.
/// Flow: Boot → Onboarding (first launch only) → NavigationShell
struct RootView: View {
    @AppStorage("hasCompletedFirstBoot") private var hasCompletedFirstBoot = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var bootComplete = false
    @State private var showOnboarding = false
    @State private var showApp = false
    @State private var appState = AppState()

    var body: some View {
        ZStack {
            if showApp {
                NavigationShell()
                    .transition(.opacity)
            }

            if showOnboarding {
                OnboardingView(onComplete: finishOnboarding)
                    .transition(.opacity)
            }

            if !bootComplete {
                BootSequenceView(
                    isAbbreviated: hasCompletedFirstBoot,
                    onComplete: finishBoot
                )
                .transition(.opacity)
            }
        }
        .environment(appState)
        .animation(.easeInOut(duration: 0.5), value: bootComplete)
        .animation(.easeInOut(duration: 0.4), value: showOnboarding)
    }

    private func finishBoot() {
        if !hasCompletedFirstBoot {
            hasCompletedFirstBoot = true
        }

        if hasCompletedOnboarding {
            // Returning user — go straight to app
            showApp = true
            withAnimation(.easeInOut(duration: 0.5)) {
                bootComplete = true
            }
        } else {
            // First launch — show onboarding
            showOnboarding = true
            withAnimation(.easeInOut(duration: 0.5)) {
                bootComplete = true
            }
        }
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
        showApp = true
        withAnimation(.easeIn(duration: 0.3)) {
            showOnboarding = false
        }
    }
}

// MARK: - Preview

#Preview("Boot Sequence — Full") {
    BootSequenceView(onComplete: {})
        .frame(width: 900, height: 600)
}

#Preview("Boot Sequence — Abbreviated") {
    BootSequenceView(isAbbreviated: true, onComplete: {})
        .frame(width: 900, height: 600)
}

#Preview("Root View — First Launch") {
    RootView()
        .frame(width: 900, height: 600)
}
