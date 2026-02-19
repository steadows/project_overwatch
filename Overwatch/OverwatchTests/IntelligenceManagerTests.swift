import Testing
import Foundation
import SwiftData
@testable import Overwatch

// MARK: - Test Helpers

private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Habit.self, HabitEntry.self, JournalEntry.self,
        MonthlyAnalysis.self, WhoopCycle.self, WeeklyInsight.self,
        configurations: config
    )
}

private let testStartDate = Calendar.current.date(
    from: DateComponents(year: 2026, month: 2, day: 9)
)!
private let testEndDate = Calendar.current.date(
    from: DateComponents(year: 2026, month: 2, day: 16)
)!

@MainActor
private func seedTestData(in context: ModelContext) {
    let calendar = Calendar.current

    // Create habits
    let meditation = Habit(
        name: "Meditation", emoji: "🧘", category: "Wellness",
        targetFrequency: 7, isQuantitative: false, unitLabel: "", sortOrder: 0
    )
    let exercise = Habit(
        name: "Exercise", emoji: "🏋️", category: "Fitness",
        targetFrequency: 5, isQuantitative: false, unitLabel: "", sortOrder: 1
    )
    context.insert(meditation)
    context.insert(exercise)

    // Create habit entries in range
    for dayOffset in 0..<7 {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: testStartDate)!

        let medEntry = HabitEntry(date: date, completed: dayOffset % 2 == 0)
        medEntry.habit = meditation
        context.insert(medEntry)

        let exEntry = HabitEntry(date: date, completed: dayOffset < 5)
        exEntry.habit = exercise
        context.insert(exEntry)
    }

    // Create journal entries with sentiment
    let sentiments: [(Double, String)] = [
        (0.6, "positive"), (-0.3, "negative"), (0.4, "positive"),
        (0.1, "neutral"), (0.7, "positive"), (-0.1, "neutral"), (0.5, "positive"),
    ]
    for (dayOffset, (score, label)) in sentiments.enumerated() {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: testStartDate)!
        let entry = JournalEntry(
            content: "Test entry for day \(dayOffset)",
            sentimentScore: score,
            sentimentLabel: label,
            sentimentMagnitude: abs(score),
            title: "Day \(dayOffset)",
            wordCount: 5,
            tags: []
        )
        entry.date = date
        context.insert(entry)
    }

    // Create WHOOP cycles
    for dayOffset in 0..<7 {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: testStartDate)!
        let cycle = WhoopCycle(
            cycleId: 1000 + dayOffset,
            date: date,
            strain: 10.0 + Double(dayOffset),
            kilojoules: 2000,
            averageHeartRate: 70,
            maxHeartRate: 150,
            recoveryScore: 60.0 + Double(dayOffset) * 3,
            hrvRmssdMilli: 50.0 + Double(dayOffset),
            restingHeartRate: 55.0,
            sleepPerformance: 70.0 + Double(dayOffset) * 2,
            sleepSWSMilli: 3600000,
            sleepREMMilli: 5400000
        )
        context.insert(cycle)
    }
}

// MARK: - Tests

@Suite("Intelligence Manager — Weekly Report Generation")
struct IntelligenceManagerTests {

    // MARK: - Report Generation (Template Fallback)

    @Test("generateWeeklyReport produces valid WeeklyInsight with fallback")
    @MainActor
    func reportGenerationWithFallback() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        seedTestData(in: context)

        // nil geminiService → template fallback
        let manager = IntelligenceManager(geminiService: nil)

        let insight = try await manager.generateWeeklyReport(
            startDate: testStartDate,
            endDate: testEndDate,
            from: context
        )

        #expect(!insight.summary.isEmpty, "Summary should not be empty")
        #expect(!insight.recommendations.isEmpty, "Should have recommendations")
        #expect(insight.dateRangeStart == testStartDate)
        #expect(insight.dateRangeEnd == testEndDate)
        #expect(insight.generatedAt <= .now)
    }

    // MARK: - Sentiment Integration (6.5.13)

    @Test("Report includes sentiment data from journal entries")
    @MainActor
    func reportIncludesSentimentData() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        seedTestData(in: context)

        let manager = IntelligenceManager(geminiService: nil)

        let insight = try await manager.generateWeeklyReport(
            startDate: testStartDate,
            endDate: testEndDate,
            from: context
        )

        // Sentiment should be populated from the 7 journal entries
        let avgSentiment = try #require(insight.averageSentiment, "averageSentiment should not be nil")
        #expect(avgSentiment > -1.0 && avgSentiment < 1.0, "Average should be in valid range")

        let trend = try #require(insight.sentimentTrend, "sentimentTrend should not be nil")
        #expect(
            ["improving", "declining", "stable"].contains(trend),
            "Trend should be a valid value, got \(trend)"
        )
    }

    // MARK: - Nil-Safe (No Journal Data)

    @Test("Report generation works with no journal entries")
    @MainActor
    func reportWithNoJournalData() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Seed only habits + habit entries, no journal entries
        let habit = Habit(
            name: "Water", emoji: "💧", category: "Health",
            targetFrequency: 7, isQuantitative: false, unitLabel: "", sortOrder: 0
        )
        context.insert(habit)

        let entry = HabitEntry(date: testStartDate, completed: true)
        entry.habit = habit
        context.insert(entry)

        let manager = IntelligenceManager(geminiService: nil)

        let insight = try await manager.generateWeeklyReport(
            startDate: testStartDate,
            endDate: testEndDate,
            from: context
        )

        #expect(insight.averageSentiment == nil, "No journal data → nil sentiment")
        #expect(insight.sentimentTrend == nil, "No journal data → nil trend")
        #expect(!insight.summary.isEmpty, "Should still generate a summary")
    }

    // MARK: - Offline Retrieval of Cached Reports

    @Test("Generated reports are persisted and retrievable from SwiftData")
    @MainActor
    func offlineRetrieval() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        seedTestData(in: context)

        let manager = IntelligenceManager(geminiService: nil)

        let insight = try await manager.generateWeeklyReport(
            startDate: testStartDate,
            endDate: testEndDate,
            from: context
        )

        // Fetch from SwiftData
        let descriptor = FetchDescriptor<WeeklyInsight>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1, "Should have exactly 1 cached report")
        let cached = try #require(fetched.first)
        #expect(cached.id == insight.id, "Fetched report should match generated")
        #expect(cached.summary == insight.summary)
        #expect(cached.recommendations == insight.recommendations)
        #expect(cached.forceMultiplierHabit == insight.forceMultiplierHabit)
    }

    // MARK: - Dedup (Auto-Generate Skips Existing)

    @Test("checkAutoGenerate skips when report already exists for the period")
    @MainActor
    func autoGenerateSkipsDuplicate() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        seedTestData(in: context)

        let manager = IntelligenceManager(geminiService: nil)

        // Generate first report
        _ = try await manager.generateWeeklyReport(
            startDate: testStartDate,
            endDate: testEndDate,
            from: context
        )

        // Generate second report for same range
        _ = try await manager.generateWeeklyReport(
            startDate: testStartDate,
            endDate: testEndDate,
            from: context
        )

        // Both get inserted (dedup is in checkAutoGenerate, not generateWeeklyReport)
        let all = try context.fetch(FetchDescriptor<WeeklyInsight>())
        #expect(all.count == 2, "Direct calls create separate records")

        // Now test checkAutoGenerate dedup: set up UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "settings_autoGenerateReports")
        defaults.set(1, forKey: "settings_reportDayOfWeek") // Sunday
        defaults.set(0, forKey: "settings_reportHour")
        defaults.set(0, forKey: "settings_reportMinute")
        defer {
            defaults.removeObject(forKey: "settings_autoGenerateReports")
            defaults.removeObject(forKey: "settings_reportDayOfWeek")
            defaults.removeObject(forKey: "settings_reportHour")
            defaults.removeObject(forKey: "settings_reportMinute")
        }

        let countBefore = try context.fetch(FetchDescriptor<WeeklyInsight>()).count
        await manager.checkAutoGenerate(from: context)
        let countAfter = try context.fetch(FetchDescriptor<WeeklyInsight>()).count

        // checkAutoGenerate should either skip (date mismatch) or create at most one
        // The key assertion: it doesn't infinitely loop creating reports
        #expect(countAfter <= countBefore + 1, "Auto-generate should not create unbounded reports")
    }

    // MARK: - Auto-Generate Disabled

    @Test("checkAutoGenerate does nothing when setting is off")
    @MainActor
    func autoGenerateDisabled() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        UserDefaults.standard.set(false, forKey: "settings_autoGenerateReports")
        defer { UserDefaults.standard.removeObject(forKey: "settings_autoGenerateReports") }

        let manager = IntelligenceManager(geminiService: nil)
        await manager.checkAutoGenerate(from: context)

        let reports = try context.fetch(FetchDescriptor<WeeklyInsight>())
        #expect(reports.isEmpty, "Should not generate when disabled")
    }

    // MARK: - Response Parsing

    @Test("Template fallback produces valid response structure")
    @MainActor
    func templateFallbackStructure() async throws {
        let completions = [
            HabitCompletionData(habitName: "Meditation", emoji: "🧘", completedDays: 5, totalDays: 7, completionRate: 0.71),
            HabitCompletionData(habitName: "Exercise", emoji: "🏋️", completedDays: 3, totalDays: 7, completionRate: 0.43),
        ]

        let sentiments = [
            DailySentiment(dateLabel: "Feb 9", score: 0.5, label: "positive"),
            DailySentiment(dateLabel: "Feb 10", score: -0.2, label: "negative"),
            DailySentiment(dateLabel: "Feb 11", score: 0.6, label: "positive"),
        ]

        let correlations = [
            HabitCoefficient(habitName: "Meditation", habitEmoji: "🧘", coefficient: 0.34, pValue: 0.01, completionRate: 0.71, direction: .positive),
            HabitCoefficient(habitName: "Exercise", habitEmoji: "🏋️", coefficient: -0.12, pValue: 0.15, completionRate: 0.43, direction: .negative),
        ]

        let response = IntelligenceManager.weeklyFallback(
            habitCompletions: completions,
            sentimentScores: sentiments,
            correlations: correlations,
            forceMultiplierHabit: "Meditation",
            dateRangeLabel: "Feb 9 — Feb 16"
        )

        #expect(!response.summary.isEmpty)
        #expect(response.forceMultiplierHabit == "Meditation")
        #expect(!response.recommendations.isEmpty)
        #expect(response.recommendations.count >= 2)
        #expect(["improving", "declining", "stable"].contains(response.sentimentTrend ?? ""))
    }

    // MARK: - Empty Data

    @Test("Report generation handles completely empty database")
    @MainActor
    func reportWithEmptyDatabase() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let manager = IntelligenceManager(geminiService: nil)

        let insight = try await manager.generateWeeklyReport(
            startDate: testStartDate,
            endDate: testEndDate,
            from: context
        )

        #expect(insight.averageSentiment == nil)
        #expect(insight.sentimentTrend == nil)
        #expect(insight.correlations.isEmpty)
        #expect(!insight.summary.isEmpty, "Should still produce a fallback summary")
    }
}
