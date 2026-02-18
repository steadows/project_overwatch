import SwiftUI

/// Overwatch Design System — Sci-Fi Cockpit HUD
/// Dark blue-black backdrop, glowing borders, scan-line textures, data readout feel.
enum OverwatchTheme {

    // MARK: - Colors

    /// Dark blue-black background — "powered-on screen"
    static let background = Color(red: 0.039, green: 0.039, blue: 0.059) // #0A0A0F

    /// Cool-tinted dark panel surface
    static let surface = Color(red: 0.067, green: 0.071, blue: 0.098) // #111219

    /// Slightly elevated surface for nested elements
    static let surfaceElevated = Color(red: 0.098, green: 0.102, blue: 0.137) // #191A23

    /// Electric Amber — primary accent for high-performance indicators
    static let accentPrimary = Color(red: 1.0, green: 0.722, blue: 0.0) // #FFB800

    /// HUD Cyan — instrument labels, scan lines, secondary data
    static let accentCyan = Color(red: 0, green: 0.831, blue: 1.0) // #00D4FF

    /// Neon Green — secondary accent for positive signals
    static let accentSecondary = Color(red: 0.224, green: 1.0, blue: 0.078) // #39FF14

    /// Muted Red — alerts, warnings, low performance
    static let alert = Color(red: 1.0, green: 0.271, blue: 0.227) // #FF453A

    /// Primary text — high contrast white
    static let textPrimary = Color.white

    /// Secondary text — muted grey for labels and metadata
    static let textSecondary = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93

    /// Translucent panel surface — lets background grid/data stream show through
    static let surfaceTranslucent = surface.opacity(0.55)

    // MARK: - Glow Helpers

    /// Amber glow — for primary border glow
    static let glowPrimary = accentPrimary.opacity(0.5)

    /// Cyan glow — for instrument label glow
    static let glowCyan = accentCyan.opacity(0.5)

    /// Scan line color — visible cyan
    static let scanLine = accentCyan.opacity(0.08)

    // MARK: - Performance Thresholds

    /// Returns the appropriate color for a 0-100 performance score
    static func performanceColor(for score: Double) -> Color {
        switch score {
        case 67...100: return accentSecondary  // Green — high performance
        case 34..<67:  return accentPrimary     // Amber — moderate
        default:       return alert             // Red — low / alert
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radii

    enum CornerRadius {
        static let sm: CGFloat = 3
        static let md: CGFloat = 5
        static let lg: CGFloat = 6
        static let xl: CGFloat = 10
    }
}
