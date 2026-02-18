import SwiftUI

/// Standard animation definitions — snappy, physical feel with HUD-specific additions
enum Animations {

    /// Default spring — used for all standard state transitions
    /// Snappy with slight bounce, feels like a physical tap
    static let standard = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Quick spring — for micro-interactions (button presses, toggles)
    static let quick = Animation.spring(response: 0.2, dampingFraction: 0.8)

    /// Smooth spring — for larger transitions (view changes, panel slides)
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)

    /// Entry animation — for staggered card appearances on dashboard load
    static let entry = Animation.spring(response: 0.5, dampingFraction: 0.75)

    /// Pulse — for attention-grabbing alerts (low recovery, etc.)
    static let pulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)

    /// Stagger delay for sequential card animations
    static func staggerDelay(index: Int) -> Animation {
        entry.delay(Double(index) * 0.08)
    }

    // MARK: - HUD Animations

    /// Data stream — snappy spring for value entry / data arrival
    static let dataStream = Animation.spring(response: 0.35, dampingFraction: 0.65)

    /// Glow pulse — slow breathing animation for active border glow
    static let glowPulse = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)

    /// Boot sequence — staggered fade-in for HUD panels on load
    static func bootSequence(index: Int) -> Animation {
        .easeOut(duration: 0.4).delay(Double(index) * 0.12)
    }
}
