import Foundation

/// Centralized date formatting for consistent display across the app.
///
/// Formatters are created once and reused. Marked `nonisolated(unsafe)` because
/// they are configured at init time and then only read — safe for concurrent access.
enum DateFormatters {

    // MARK: - ISO 8601 (API communication)

    /// Full ISO 8601 — used for WHOOP API requests/responses
    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Display Formats

    /// "Feb 17, 2026" — used in report headers, date labels
    nonisolated(unsafe) static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// "Mon, Feb 17" — used in heat map tooltips, short labels
    nonisolated(unsafe) static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    /// "08:00" — used for timestamps in 24h format
    nonisolated(unsafe) static let time24h: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// "Feb 10 – Feb 17, 2026" — used for weekly report headers
    @MainActor
    static func weekRange(from startDate: Date, to endDate: Date) -> String {
        let start = shortDate.string(from: startDate)
        let end = displayDate.string(from: endDate)
        return "\(start) – \(end)"
    }

    // MARK: - Relative

    /// "2 hours ago", "just now" — used for sync timestamps
    nonisolated(unsafe) static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
