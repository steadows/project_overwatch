import SwiftUI

/// Typography system — holographic projection feel.
///
/// Font hierarchy:
/// - **Futura Medium** — hero titles, app name. Geometric, iconic, sci-fi.
/// - **Avenir Next Ultra Light** — section headers, subtitles. Sleek, projected, ethereal.
/// - **SF Pro Ultra Light** — HUD labels, instrument panel text. Thin strokes = laser-etched.
/// - **SF Mono Light** — data values, metrics. Readable monospace, but thin = projected, not printed.
///
/// Everything is thinner than normal. Wide tracking on labels. Text should look projected, not painted.
enum Typography {

    // MARK: - Headers (Futura — geometric sci-fi)

    /// Hero title — "OVERWATCH". Futura Medium, wide tracked.
    static let largeTitle = Font.custom("Futura-Medium", size: 34)

    /// View title — page names, major headers. Avenir Next Ultra Light for projected feel.
    static let title = Font.custom("AvenirNext-UltraLight", size: 22)

    /// Subtitle — card headers, sub-sections. Avenir Next Light, slightly more present.
    static let subtitle = Font.custom("AvenirNext-Light", size: 18)

    /// Caption — labels, metadata. SF Pro ultra light for laser-etched feel.
    static let caption = Font.system(size: 11, weight: .ultraLight, design: .default)

    /// HUD label — instrument panel labels (small, tracked, uppercase). Thin and wide.
    static let hudLabel = Font.system(size: 10, weight: .light, design: .default)

    // MARK: - Data / Metrics (SF Mono — readable but light)

    /// Large metric — hero numbers (Recovery %, Strain score). Light weight = projected.
    static let metricLarge = Font.system(.title, design: .monospaced, weight: .light)

    /// Medium metric — secondary data points
    static let metricMedium = Font.system(.title3, design: .monospaced, weight: .light)

    /// Small metric — tertiary data, timestamps
    static let metricSmall = Font.system(.body, design: .monospaced, weight: .light)

    /// Tiny metric — fine print data
    static let metricTiny = Font.system(.caption, design: .monospaced, weight: .ultraLight)

    // MARK: - Command Line (SF Mono — terminal)

    /// Command line input — ultra light for projected terminal
    static let commandLine = Font.system(.body, design: .monospaced, weight: .ultraLight)

    /// Command line prompt — the ">" character, slightly more present
    static let commandPrompt = Font.system(.body, design: .monospaced, weight: .light)
}
