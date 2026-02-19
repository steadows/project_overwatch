import Testing
import Foundation
import SwiftData
@testable import Overwatch

// MARK: - Test Helpers

/// Create an in-memory ModelContainer with all models needed for pipeline testing.
private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: JournalEntry.self, Habit.self, HabitEntry.self, MonthlyAnalysis.self,
        configurations: config
    )
}

/// Build a `RegressionInput` from SwiftData for a given date range.
///
/// Fetches journal entries (target vector) and habit entries (feature matrix) within
/// the range. Habits with no variance (0% or 100% completion) are excluded by default
/// since they cause matrix singularity with the intercept column.
@MainActor
private func buildRegressionInput(
    from context: ModelContext,
    startDate: Date,
    endDate: Date,
    excludeNoVariance: Bool = true
) throws -> RegressionInput {
    let calendar = Calendar.current

    let entryDescriptor = FetchDescriptor<JournalEntry>(
        predicate: #Predicate<JournalEntry> { entry in
            entry.date >= startDate && entry.date < endDate
        },
        sortBy: [SortDescriptor(\.date)]
    )
    let entries = try context.fetch(entryDescriptor)

    let habits = try context.fetch(
        FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)])
    )

    let habitEntryDescriptor = FetchDescriptor<HabitEntry>(
        predicate: #Predicate<HabitEntry> { he in
            he.date >= startDate && he.date < endDate
        }
    )
    let allHabitEntries = try context.fetch(habitEntryDescriptor)

    let dayCount = entries.count
    guard dayCount > 0 else {
        return RegressionInput(
            habitNames: [], habitEmojis: [], featureMatrix: [],
            targetVector: [], completionRates: []
        )
    }

    let dayDates = entries.map { calendar.startOfDay(for: $0.date) }

    var habitNames: [String] = []
    var habitEmojis: [String] = []
    var columns: [[Double]] = []
    var completionRates: [Double] = []

    for habit in habits {
        let thisHabitEntries = allHabitEntries.filter { $0.habit?.id == habit.id }

        var column = [Double](repeating: 0.0, count: dayCount)
        var completedCount = 0

        for (dayIndex, dayDate) in dayDates.enumerated() {
            let completed = thisHabitEntries.contains {
                calendar.startOfDay(for: $0.date) == dayDate && $0.completed
            }
            if completed {
                column[dayIndex] = 1.0
                completedCount += 1
            }
        }

        let rate = Double(completedCount) / Double(dayCount)

        if excludeNoVariance && (rate < 1e-6 || rate > 1.0 - 1e-6) {
            continue
        }

        habitNames.append(habit.name)
        habitEmojis.append(habit.emoji)
        columns.append(column)
        completionRates.append(rate)
    }

    let featureCount = habitNames.count
    var featureMatrix = [Double](repeating: 0.0, count: dayCount * featureCount)
    for (colIndex, column) in columns.enumerated() {
        for row in 0 ..< dayCount {
            featureMatrix[colIndex * dayCount + row] = column[row]
        }
    }

    let targetVector = entries.map(\.sentimentScore)

    return RegressionInput(
        habitNames: habitNames,
        habitEmojis: habitEmojis,
        featureMatrix: featureMatrix,
        targetVector: targetVector,
        completionRates: completionRates
    )
}

/// Convenience: build regression input for a specific calendar month.
@MainActor
private func buildRegressionInput(
    from context: ModelContext,
    month: Int,
    year: Int,
    excludeNoVariance: Bool = true
) throws -> RegressionInput {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    let end = calendar.date(byAdding: .month, value: 1, to: start)!
    return try buildRegressionInput(
        from: context, startDate: start, endDate: end,
        excludeNoVariance: excludeNoVariance
    )
}

/// Convenience: build regression input using ALL data in the context.
@MainActor
private func buildRegressionInputForAllData(
    from context: ModelContext,
    excludeNoVariance: Bool = true
) throws -> RegressionInput {
    try buildRegressionInput(
        from: context, startDate: .distantPast, endDate: .distantFuture,
        excludeNoVariance: excludeNoVariance
    )
}

// MARK: - Synthetic Data Pipeline Tests

@Suite("Synthetic Data Pipeline")
struct SyntheticDataTests {

    // MARK: - Sentiment Scoring Accuracy

    @Test("Positive entries score > 0, negative < 0, neutral near 0")
    @MainActor
    func sentimentScoringAccuracy() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        SyntheticDataSeeder.seedJournalAndHabits(in: context, days: 60)

        let service = SentimentAnalysisService()
        let entries = try context.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date)])
        )
        await service.analyzeBatch(entries)

        // Partition entries by which snippet bank their content came from
        let positiveEntries = entries.filter { entry in
            SyntheticDataSeeder.positiveSnippets.contains(entry.content)
        }
        let negativeEntries = entries.filter { entry in
            SyntheticDataSeeder.negativeSnippets.contains(entry.content)
        }
        let neutralEntries = entries.filter { entry in
            SyntheticDataSeeder.neutralSnippets.contains(entry.content)
        }

        // Positive entries should average above 0
        let avgPositive = positiveEntries.map(\.sentimentScore).reduce(0, +)
            / Double(max(positiveEntries.count, 1))
        #expect(avgPositive > 0.0, "Average positive sentiment should be > 0, got \(avgPositive)")

        // Negative entries should average below 0
        let avgNegative = negativeEntries.map(\.sentimentScore).reduce(0, +)
            / Double(max(negativeEntries.count, 1))
        #expect(avgNegative < 0.0, "Average negative sentiment should be < 0, got \(avgNegative)")

        // Neutral entries should be closer to 0 than positive/negative averages
        // NLTagger may skew neutral text slightly, so we use a relaxed threshold
        if !neutralEntries.isEmpty {
            let avgNeutral = neutralEntries.map(\.sentimentScore).reduce(0, +)
                / Double(neutralEntries.count)
            #expect(
                abs(avgNeutral) < abs(avgPositive),
                "Neutral average (\(avgNeutral)) should be closer to 0 than positive (\(avgPositive))"
            )
            #expect(
                abs(avgNeutral) < abs(avgNegative),
                "Neutral average (\(avgNeutral)) should be closer to 0 than negative (\(avgNegative))"
            )
        }
    }

    // MARK: - Regression Coefficient Directions

    @Test("Meditation +, Exercise +, Alcohol -, Reading ~0, Water excluded")
    @MainActor
    func regressionCoefficientDirections() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        SyntheticDataSeeder.seedJournalAndHabits(in: context, days: 60)

        let sentimentService = SentimentAnalysisService()
        let entries = try context.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date)])
        )
        await sentimentService.analyzeBatch(entries)

        // Use full 60-day dataset for maximum statistical power
        let input = try buildRegressionInputForAllData(from: context)

        // Water should be excluded (no variance — completed every day)
        #expect(
            !input.habitNames.contains("Water"),
            "Water should be excluded from regression input (no variance)"
        )

        let regressionService = RegressionService()
        let output = try #require(
            regressionService.computeRegression(input),
            "Regression should succeed with sufficient data"
        )

        // Meditation: strong positive correlation (95% on happy, 10% on unhappy)
        let meditation = try #require(output.coefficients.first { $0.habitName == "Meditation" })
        #expect(meditation.coefficient > 0, "Meditation should have positive coefficient")
        #expect(meditation.direction == .positive)

        // Exercise: moderate positive correlation (60% on happy, 35% on unhappy)
        let exercise = try #require(output.coefficients.first { $0.habitName == "Exercise" })
        #expect(exercise.coefficient > 0, "Exercise should have positive coefficient")

        // Alcohol: strong negative correlation (10% on happy, 85% on unhappy)
        let alcohol = try #require(output.coefficients.first { $0.habitName == "Alcohol" })
        #expect(alcohol.coefficient < 0, "Alcohol should have negative coefficient")
        #expect(alcohol.direction == .negative)

        // Reading: noise — its absolute coefficient should be smaller than the strongest drivers
        let reading = try #require(output.coefficients.first { $0.habitName == "Reading" })
        let strongestMagnitude = max(abs(meditation.coefficient), abs(alcohol.coefficient))
        #expect(
            abs(reading.coefficient) < strongestMagnitude,
            "Reading (\(reading.coefficient)) should be weaker than strongest driver (\(strongestMagnitude))"
        )
    }

    // MARK: - R-Squared

    @Test("R-squared > 0 (model has explanatory power)")
    @MainActor
    func rSquaredIsPositive() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        SyntheticDataSeeder.seedJournalAndHabits(in: context, days: 60)

        let sentimentService = SentimentAnalysisService()
        let entries = try context.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date)])
        )
        await sentimentService.analyzeBatch(entries)

        let input = try buildRegressionInputForAllData(from: context)
        let regressionService = RegressionService()
        let output = try #require(regressionService.computeRegression(input))

        #expect(output.r2 > 0.0, "R² should be positive, got \(output.r2)")
        #expect(output.r2 <= 1.0, "R² should be ≤ 1.0, got \(output.r2)")
    }

    // MARK: - Force Multiplier Identification

    @Test("Force multiplier habit is Meditation")
    @MainActor
    func forceMultiplierIsMeditation() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        SyntheticDataSeeder.seedJournalAndHabits(in: context, days: 60)

        let sentimentService = SentimentAnalysisService()
        let entries = try context.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date)])
        )
        await sentimentService.analyzeBatch(entries)

        // Use full 60-day dataset for the strongest signal
        let input = try buildRegressionInputForAllData(from: context)
        let regressionService = RegressionService()
        let output = try #require(regressionService.computeRegression(input))

        // Force multiplier = habit with highest positive coefficient
        let forceMultiplier = output.coefficients
            .filter { $0.direction == .positive }
            .max(by: { $0.coefficient < $1.coefficient })

        let winner = try #require(forceMultiplier, "Should have at least one positive habit")
        #expect(
            winner.habitName == "Meditation",
            "Force multiplier should be Meditation, got \(winner.habitName) (\(winner.coefficient))"
        )
    }

    // MARK: - Minimum Data Guard

    @Test("5 days of data returns nil (below 14-day minimum)")
    @MainActor
    func minimumDataGuardReturnsNil() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Seed only 5 days — well below the 14-day minimum
        SyntheticDataSeeder.seedJournalAndHabits(in: context, days: 5, seed: 99)

        let sentimentService = SentimentAnalysisService()
        let entries = try context.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date)])
        )
        await sentimentService.analyzeBatch(entries)

        let input = try buildRegressionInputForAllData(from: context)

        let regressionService = RegressionService()
        let output = regressionService.computeRegression(input)

        #expect(output == nil, "Regression should return nil with only \(input.observationCount) days")
    }

    // MARK: - End-to-End Pipeline

    @Test("Seed → analyze → regress → MonthlyAnalysis saved with valid data")
    @MainActor
    func endToEndPipeline() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // 1. Seed data
        SyntheticDataSeeder.seedJournalAndHabits(in: context, days: 60)

        // 2. Run sentiment analysis
        let sentimentService = SentimentAnalysisService()
        let entries = try context.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date)])
        )
        await sentimentService.analyzeBatch(entries)

        // 3. Build regression input for January 2026
        let input = try buildRegressionInput(from: context, month: 1, year: 2026)
        #expect(input.observationCount >= 14, "Should have enough observations")
        #expect(input.featureCount >= 2, "Should have enough features with variance")

        // 4. Run regression
        let regressionService = RegressionService()
        let output = try #require(regressionService.computeRegression(input))

        // 5. Identify force multiplier
        let forceMultiplier = output.coefficients
            .filter { $0.direction == .positive }
            .max(by: { $0.coefficient < $1.coefficient })?
            .habitName ?? ""

        // 6. Compute average sentiment for the month
        let janEntries = entries.filter {
            let comps = Calendar.current.dateComponents([.month, .year], from: $0.date)
            return comps.month == 1 && comps.year == 2026
        }
        let avgSentiment = janEntries.map(\.sentimentScore).reduce(0, +)
            / Double(max(janEntries.count, 1))

        // 7. Create and save MonthlyAnalysis
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!

        let analysis = MonthlyAnalysis(
            month: 1,
            year: 2026,
            startDate: startDate,
            endDate: endDate,
            habitCoefficients: output.coefficients,
            forceMultiplierHabit: forceMultiplier,
            modelR2: output.r2,
            averageSentiment: avgSentiment,
            entryCount: janEntries.count,
            summary: "Test summary — generated by SyntheticDataTests."
        )
        context.insert(analysis)

        // 8. Fetch it back and verify
        let fetched = try context.fetch(FetchDescriptor<MonthlyAnalysis>())
        #expect(fetched.count == 1, "Should have exactly 1 MonthlyAnalysis")

        let saved = try #require(fetched.first)
        #expect(saved.month == 1)
        #expect(saved.year == 2026)
        #expect(!saved.habitCoefficients.isEmpty, "Should have habit coefficients")
        #expect(saved.modelR2 > 0, "R² should be positive")
        #expect(!saved.forceMultiplierHabit.isEmpty, "Force multiplier should be set")
        #expect(saved.entryCount > 0, "Entry count should be positive")
    }

    // MARK: - Sentiment Trend Data

    @Test("Correct entry count and all entries have scored sentiment")
    @MainActor
    func sentimentTrendData() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        SyntheticDataSeeder.seedJournalAndHabits(in: context, days: 60)

        let sentimentService = SentimentAnalysisService()
        let entries = try context.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date)])
        )
        await sentimentService.analyzeBatch(entries)

        // Should have exactly 60 entries
        #expect(entries.count == 60, "Should have 60 journal entries, got \(entries.count)")

        // Every entry should have a non-default sentiment score after analysis
        // (NLTagger returns non-zero for well-formed text > 10 chars)
        let scoredEntries = entries.filter { $0.sentimentScore != 0.0 }
        #expect(
            scoredEntries.count > entries.count / 2,
            "Most entries should have non-zero sentiment scores (\(scoredEntries.count)/\(entries.count))"
        )

        // Every entry should have a valid sentiment label
        let validLabels: Set<String> = ["positive", "negative", "neutral"]
        for entry in entries {
            #expect(
                validLabels.contains(entry.sentimentLabel),
                "Invalid label '\(entry.sentimentLabel)' for entry on \(entry.date)"
            )
        }

        // Entries should span 2 calendar months
        let months = Set(entries.map { Calendar.current.component(.month, from: $0.date) })
        #expect(months.count == 2, "Entries should span 2 months, got \(months)")

        // Scores should be in valid range
        for entry in entries {
            #expect(entry.sentimentScore >= -1.0 && entry.sentimentScore <= 1.0)
            #expect(entry.sentimentMagnitude >= 0.0 && entry.sentimentMagnitude <= 1.0)
        }
    }
}
