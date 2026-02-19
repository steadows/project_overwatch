import Foundation
import SwiftData

@Model
final class MonthlyAnalysis {
    #Unique<MonthlyAnalysis>([\.month, \.year])

    var id: UUID
    var month: Int
    var year: Int
    var startDate: Date
    var endDate: Date
    var habitCoefficients: [HabitCoefficient]
    var forceMultiplierHabit: String
    var modelR2: Double
    var averageSentiment: Double
    var entryCount: Int
    var summary: String
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        startDate: Date,
        endDate: Date,
        habitCoefficients: [HabitCoefficient] = [],
        forceMultiplierHabit: String = "",
        modelR2: Double = 0.0,
        averageSentiment: Double = 0.0,
        entryCount: Int = 0,
        summary: String = "",
        generatedAt: Date = .now
    ) {
        self.id = id
        self.month = month
        self.year = year
        self.startDate = startDate
        self.endDate = endDate
        self.habitCoefficients = habitCoefficients
        self.forceMultiplierHabit = forceMultiplierHabit
        self.modelR2 = modelR2
        self.averageSentiment = averageSentiment
        self.entryCount = entryCount
        self.summary = summary
        self.generatedAt = generatedAt
    }
}
