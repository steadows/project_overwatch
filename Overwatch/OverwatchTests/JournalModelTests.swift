import Testing
import Foundation
import SwiftData
@testable import Overwatch

// MARK: - Test Helpers

@MainActor
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Habit.self, HabitEntry.self, JournalEntry.self, MonthlyAnalysis.self,
        configurations: config
    )
}

// MARK: - JournalEntry Sentiment Defaults

@Suite("JournalEntry Sentiment Properties")
struct JournalEntrySentimentTests {

    @Test @MainActor
    func defaultSentimentValues() throws {
        let entry = JournalEntry(content: "Test entry")

        #expect(entry.sentimentScore == 0.0)
        #expect(entry.sentimentLabel == "neutral")
        #expect(entry.sentimentMagnitude == 0.0)
        #expect(entry.title == "")
        #expect(entry.wordCount == 0)
        #expect(entry.tags.isEmpty)
    }

    @Test @MainActor
    func customSentimentValues() throws {
        let entry = JournalEntry(
            content: "Had an amazing day today!",
            sentimentScore: 0.85,
            sentimentLabel: "positive",
            sentimentMagnitude: 0.85,
            title: "Great Day",
            wordCount: 5,
            tags: ["mood", "gratitude"]
        )

        #expect(entry.sentimentScore == 0.85)
        #expect(entry.sentimentLabel == "positive")
        #expect(entry.sentimentMagnitude == 0.85)
        #expect(entry.title == "Great Day")
        #expect(entry.wordCount == 5)
        #expect(entry.tags == ["mood", "gratitude"])
    }

    @Test @MainActor
    func persistenceWithSentiment() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let entry = JournalEntry(
            content: "Rough morning but exercise helped",
            sentimentScore: -0.3,
            sentimentLabel: "negative",
            sentimentMagnitude: 0.3,
            title: "Tough Start",
            wordCount: 5,
            tags: ["exercise", "recovery"]
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<JournalEntry>())
        #expect(fetched.count == 1)
        let saved = try #require(fetched.first)
        #expect(saved.sentimentScore == -0.3)
        #expect(saved.sentimentLabel == "negative")
        #expect(saved.title == "Tough Start")
        #expect(saved.tags == ["exercise", "recovery"])
    }
}

// MARK: - HabitCoefficient Codable

@Suite("HabitCoefficient")
struct HabitCoefficientTests {

    @Test
    func codableRoundTrip() throws {
        let coefficient = HabitCoefficient(
            habitName: "Meditation",
            habitEmoji: "🧘",
            coefficient: 0.34,
            pValue: 0.02,
            completionRate: 0.75,
            direction: .positive
        )

        let data = try JSONEncoder().encode(coefficient)
        let decoded = try JSONDecoder().decode(HabitCoefficient.self, from: data)

        #expect(decoded.habitName == "Meditation")
        #expect(decoded.habitEmoji == "🧘")
        #expect(decoded.coefficient == 0.34)
        #expect(decoded.pValue == 0.02)
        #expect(decoded.completionRate == 0.75)
        #expect(decoded.direction == .positive)
    }

    @Test
    func codableArrayRoundTrip() throws {
        let coefficients: [HabitCoefficient] = [
            HabitCoefficient(
                habitName: "Meditation",
                habitEmoji: "🧘",
                coefficient: 0.34,
                pValue: 0.02,
                completionRate: 0.75,
                direction: .positive
            ),
            HabitCoefficient(
                habitName: "Late Night Snacking",
                habitEmoji: "🍕",
                coefficient: -0.22,
                pValue: 0.05,
                completionRate: 0.40,
                direction: .negative
            ),
        ]

        let data = try JSONEncoder().encode(coefficients)
        let decoded = try JSONDecoder().decode([HabitCoefficient].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].direction == .positive)
        #expect(decoded[1].direction == .negative)
        #expect(decoded[1].coefficient == -0.22)
    }

    @Test
    func identifiableUsesHabitName() {
        let coeff = HabitCoefficient(
            habitName: "Exercise",
            habitEmoji: "💪",
            coefficient: 0.5,
            pValue: 0.01,
            completionRate: 0.9,
            direction: .positive
        )

        #expect(coeff.id == "Exercise")
    }

    @Test
    func directionCodable() throws {
        let directions: [HabitCoefficient.Direction] = [.positive, .negative, .neutral]
        let data = try JSONEncoder().encode(directions)
        let decoded = try JSONDecoder().decode([HabitCoefficient.Direction].self, from: data)

        #expect(decoded == directions)
    }
}

// MARK: - MonthlyAnalysis

@Suite("MonthlyAnalysis Model")
struct MonthlyAnalysisTests {

    @Test @MainActor
    func creationWithDefaults() throws {
        let analysis = MonthlyAnalysis(
            month: 2,
            year: 2026,
            startDate: Date(timeIntervalSince1970: 1_738_368_000), // 2026-02-01
            endDate: Date(timeIntervalSince1970: 1_740_787_200)    // 2026-02-28
        )

        #expect(analysis.month == 2)
        #expect(analysis.year == 2026)
        #expect(analysis.habitCoefficients.isEmpty)
        #expect(analysis.forceMultiplierHabit == "")
        #expect(analysis.modelR2 == 0.0)
        #expect(analysis.averageSentiment == 0.0)
        #expect(analysis.entryCount == 0)
        #expect(analysis.summary == "")
    }

    @Test @MainActor
    func creationWithFullData() throws {
        let coefficients: [HabitCoefficient] = [
            HabitCoefficient(
                habitName: "Meditation",
                habitEmoji: "🧘",
                coefficient: 0.34,
                pValue: 0.02,
                completionRate: 0.75,
                direction: .positive
            ),
        ]

        let analysis = MonthlyAnalysis(
            month: 1,
            year: 2026,
            startDate: Date(timeIntervalSince1970: 1_735_689_600),
            endDate: Date(timeIntervalSince1970: 1_738_281_600),
            habitCoefficients: coefficients,
            forceMultiplierHabit: "Meditation",
            modelR2: 0.72,
            averageSentiment: 0.42,
            entryCount: 28,
            summary: "Meditation was your force multiplier this month."
        )

        #expect(analysis.habitCoefficients.count == 1)
        #expect(analysis.forceMultiplierHabit == "Meditation")
        #expect(analysis.modelR2 == 0.72)
        #expect(analysis.averageSentiment == 0.42)
        #expect(analysis.entryCount == 28)
    }

    @Test @MainActor
    func persistenceRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let coefficients: [HabitCoefficient] = [
            HabitCoefficient(
                habitName: "Exercise",
                habitEmoji: "💪",
                coefficient: 0.5,
                pValue: 0.01,
                completionRate: 0.85,
                direction: .positive
            ),
            HabitCoefficient(
                habitName: "Alcohol",
                habitEmoji: "🍺",
                coefficient: -0.3,
                pValue: 0.04,
                completionRate: 0.25,
                direction: .negative
            ),
        ]

        let analysis = MonthlyAnalysis(
            month: 2,
            year: 2026,
            startDate: Date(timeIntervalSince1970: 1_738_368_000),
            endDate: Date(timeIntervalSince1970: 1_740_787_200),
            habitCoefficients: coefficients,
            forceMultiplierHabit: "Exercise",
            modelR2: 0.68,
            averageSentiment: 0.35,
            entryCount: 25,
            summary: "Exercise drives your wellbeing."
        )
        context.insert(analysis)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MonthlyAnalysis>())
        #expect(fetched.count == 1)
        let saved = try #require(fetched.first)
        #expect(saved.month == 2)
        #expect(saved.year == 2026)
        #expect(saved.habitCoefficients.count == 2)
        #expect(saved.forceMultiplierHabit == "Exercise")
        #expect(saved.modelR2 == 0.68)
        #expect(saved.summary == "Exercise drives your wellbeing.")
    }
}
