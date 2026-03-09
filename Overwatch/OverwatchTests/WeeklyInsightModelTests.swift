import Testing
import Foundation
import SwiftData
@testable import Overwatch

// MARK: - Test Helpers

@MainActor
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: WeeklyInsight.self,
        configurations: config
    )
}

// MARK: - WeeklyInsight Creation

@Suite("WeeklyInsight Model")
struct WeeklyInsightModelTests {

    private let testStart = Date(timeIntervalSince1970: 1_738_368_000) // 2026-02-01
    private let testEnd = Date(timeIntervalSince1970: 1_738_972_800)   // 2026-02-08

    @Test @MainActor
    func creationWithDefaults() throws {
        let insight = WeeklyInsight(
            dateRangeStart: testStart,
            dateRangeEnd: testEnd
        )

        #expect(insight.summary == "")
        #expect(insight.forceMultiplierHabit == "")
        #expect(insight.recommendations.isEmpty)
        #expect(insight.correlations.isEmpty)
        #expect(insight.averageSentiment == nil)
        #expect(insight.sentimentTrend == nil)
        #expect(insight.dateRangeStart == testStart)
        #expect(insight.dateRangeEnd == testEnd)
    }

    @Test @MainActor
    func creationWithFullData() throws {
        let correlations = [
            HabitCoefficient(
                habitName: "Meditation",
                habitEmoji: "🧘",
                coefficient: 0.34,
                pValue: 0.02,
                completionRate: 0.75,
                direction: .positive
            ),
        ]

        let insight = WeeklyInsight(
            dateRangeStart: testStart,
            dateRangeEnd: testEnd,
            summary: "Great week overall.",
            forceMultiplierHabit: "Meditation",
            recommendations: ["Keep meditating", "Try more exercise"],
            correlations: correlations,
            averageSentiment: 0.42,
            sentimentTrend: "improving"
        )

        #expect(insight.summary == "Great week overall.")
        #expect(insight.forceMultiplierHabit == "Meditation")
        #expect(insight.recommendations == ["Keep meditating", "Try more exercise"])
        #expect(insight.correlations.count == 1)
        #expect(insight.averageSentiment == 0.42)
        #expect(insight.sentimentTrend == "improving")
    }

    // MARK: - Recommendations JSON Encoding

    @Test @MainActor
    func recommendationsRoundTrip() throws {
        let insight = WeeklyInsight(
            dateRangeStart: testStart,
            dateRangeEnd: testEnd,
            recommendations: ["Do more", "Rest well", "Stay hydrated"]
        )

        #expect(insight.recommendations.count == 3)
        #expect(insight.recommendations[0] == "Do more")
        #expect(insight.recommendations[2] == "Stay hydrated")

        // Modify recommendations
        insight.recommendations = ["Updated recommendation"]
        #expect(insight.recommendations.count == 1)
        #expect(insight.recommendations[0] == "Updated recommendation")
    }

    @Test @MainActor
    func emptyRecommendations() throws {
        let insight = WeeklyInsight(
            dateRangeStart: testStart,
            dateRangeEnd: testEnd,
            recommendations: []
        )

        #expect(insight.recommendations.isEmpty)
        #expect(insight.recommendationsJSON == "[]")
    }

    // MARK: - Persistence

    @Test @MainActor
    func persistenceRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let insight = WeeklyInsight(
            dateRangeStart: testStart,
            dateRangeEnd: testEnd,
            summary: "Persisted summary",
            forceMultiplierHabit: "Exercise",
            recommendations: ["Rec 1", "Rec 2"],
            averageSentiment: 0.55,
            sentimentTrend: "stable"
        )
        context.insert(insight)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WeeklyInsight>())
        #expect(fetched.count == 1)

        let saved = try #require(fetched.first)
        #expect(saved.summary == "Persisted summary")
        #expect(saved.forceMultiplierHabit == "Exercise")
        #expect(saved.recommendations == ["Rec 1", "Rec 2"])
        #expect(saved.averageSentiment == 0.55)
        #expect(saved.sentimentTrend == "stable")
        #expect(saved.dateRangeStart == testStart)
        #expect(saved.dateRangeEnd == testEnd)
    }

    @Test @MainActor
    func multipleFetchSortedByDate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let older = WeeklyInsight(
            dateRangeStart: testStart,
            dateRangeEnd: testEnd,
            summary: "Older",
            generatedAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let newer = WeeklyInsight(
            dateRangeStart: testStart,
            dateRangeEnd: testEnd,
            summary: "Newer",
            generatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let descriptor = FetchDescriptor<WeeklyInsight>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 2)
        #expect(fetched[0].summary == "Newer")
        #expect(fetched[1].summary == "Older")
    }

    // MARK: - String Array Helpers

    @Test
    func encodeDecodeStringArray() {
        let original = ["alpha", "beta", "gamma"]
        let json = WeeklyInsight.encodeStringArray(original)
        let decoded = WeeklyInsight.decodeStringArray(json)
        #expect(decoded == original)
    }

    @Test
    func decodeInvalidJSON() {
        let decoded = WeeklyInsight.decodeStringArray("not valid json")
        #expect(decoded.isEmpty)
    }

    @Test
    func decodeEmptyString() {
        let decoded = WeeklyInsight.decodeStringArray("")
        #expect(decoded.isEmpty)
    }
}
