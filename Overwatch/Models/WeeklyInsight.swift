import Foundation
import SwiftData

@Model
final class WeeklyInsight {
    var id: UUID
    var dateRangeStart: Date
    var dateRangeEnd: Date
    var summary: String
    var forceMultiplierHabit: String
    var recommendations: [String]
    var correlations: [HabitCoefficient]
    var averageSentiment: Double?
    var sentimentTrend: String?
    var generatedAt: Date

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
        self.recommendations = recommendations
        self.correlations = correlations
        self.averageSentiment = averageSentiment
        self.sentimentTrend = sentimentTrend
        self.generatedAt = generatedAt
    }
}
