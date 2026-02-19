import Foundation
import SwiftData

@Model
final class WeeklyInsight {
    var id: UUID
    var dateRangeStart: Date
    var dateRangeEnd: Date
    var summary: String
    var forceMultiplierHabit: String
    var correlations: [HabitCoefficient]
    var averageSentiment: Double?
    var sentimentTrend: String?
    var generatedAt: Date

    // JSON-backed storage (avoids CoreData Array<String> materialization errors)
    var recommendationsJSON: String

    init(
        id: UUID = UUID(),
        dateRangeStart: Date,
        dateRangeEnd: Date,
        summary: String = "",
        forceMultiplierHabit: String = "",
        recommendations: [String] = [],
        correlations: [HabitCoefficient] = [],
        averageSentiment: Double? = nil,
        sentimentTrend: String? = nil,
        generatedAt: Date = .now
    ) {
        self.id = id
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.summary = summary
        self.forceMultiplierHabit = forceMultiplierHabit
        self.recommendationsJSON = Self.encodeStringArray(recommendations)
        self.correlations = correlations
        self.averageSentiment = averageSentiment
        self.sentimentTrend = sentimentTrend
        self.generatedAt = generatedAt
    }
}

// MARK: - Array Accessors (outside @Model macro scope)

extension WeeklyInsight {
    var recommendations: [String] {
        get { Self.decodeStringArray(recommendationsJSON) }
        set { recommendationsJSON = Self.encodeStringArray(newValue) }
    }

    static func encodeStringArray(_ array: [String]) -> String {
        (try? String(data: JSONEncoder().encode(array), encoding: .utf8)) ?? "[]"
    }

    static func decodeStringArray(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
