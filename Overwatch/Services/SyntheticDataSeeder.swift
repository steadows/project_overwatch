import Foundation
import SwiftData

// MARK: - SyntheticDataSeeder

/// Generates controlled synthetic data for testing the NLP/sentiment pipeline.
///
/// Creates 5 habits with designed correlations to sentiment and journal entries
/// with known-sentiment content. Used by `SyntheticDataTests` and the optional
/// DEBUG "SEED DEMO DATA" button.
///
/// Synthetic journal entries are tagged with `"synthetic"` and created habit IDs
/// are stored in UserDefaults so they can be cleanly removed without touching real data.
struct SyntheticDataSeeder {

    // MARK: - Persistence Keys

    private static let habitIDsKey = "overwatch.synthetic.habitIDs"
    private static let journalIDsKey = "overwatch.synthetic.journalIDs"

    /// Whether synthetic data is currently seeded (IDs stored in UserDefaults).
    static var hasSyntheticData: Bool {
        let ids = UserDefaults.standard.stringArray(forKey: journalIDsKey) ?? []
        return !ids.isEmpty
    }

    // MARK: - Snippet Banks

    /// Clearly positive journal entries (2-4 sentences each).
    static let positiveSnippets: [String] = [
        "Had an amazing day today. Everything just clicked and I felt incredibly productive and happy with how things turned out.",
        "Woke up feeling grateful and energized. The morning routine was perfect and I accomplished everything I set out to do.",
        "Great workout this morning, followed by a delicious healthy breakfast. Feeling on top of the world and ready for anything.",
        "Wonderful conversation with a friend today. Feeling connected and appreciated. Life is genuinely good right now.",
        "Crushed my goals today. Every task I tackled went smoothly and I am proud of what I accomplished this week.",
        "Beautiful weather and a fantastic mood. Spent quality time outdoors and felt completely at peace with everything.",
        "Today was a win. Got positive feedback at work and celebrated with a nice dinner. Feeling blessed and motivated.",
        "Incredible energy today. Meditation was deep, focus was sharp, and everything fell into place perfectly throughout the day.",
        "Feeling so thankful for the progress I have made. Today reminded me how far I have come. Really happy and optimistic.",
        "Had a breakthrough moment today. Everything suddenly made sense and I felt a rush of excitement and joy about the future.",
        "Spent the day doing what I love. Creativity was flowing and I produced some of my best work yet. Truly fulfilling.",
        "Amazing progress on my personal goals today. Feeling motivated, inspired, and genuinely optimistic about what comes next.",
    ]

    /// Clearly negative journal entries (2-4 sentences each).
    static let negativeSnippets: [String] = [
        "Terrible day. Nothing went right and I feel completely drained and frustrated with everything that happened today.",
        "Could not sleep last night and it ruined the entire day. Exhausted, irritable, and struggling to focus on anything.",
        "Everything feels overwhelming right now. Stress is through the roof and I cannot seem to catch a break at all.",
        "Had a really discouraging setback today. Feeling defeated and questioning whether any of this effort is even worth it.",
        "Awful headache all day and zero motivation. Just wanted to stay in bed and avoid the world entirely. Miserable.",
        "Got into an argument that left me feeling angry and upset. The tension is draining all my energy and patience.",
        "Failed at something I worked hard on. The disappointment is crushing and I feel like giving up on this completely.",
        "Lonely and sad today. The isolation is getting to me and I miss feeling connected to people who actually care.",
        "Anxiety was through the roof today. Could not concentrate on anything and felt paralyzed by worry and dread all day.",
        "Worst day in weeks. Everything that could go wrong did go wrong. I feel hopeless and completely exhausted tonight.",
        "Feeling really down and unmotivated. The negativity is overwhelming and I cannot shake this terrible mood no matter what.",
        "Stressed beyond belief today. Deadlines piling up, nothing going right, and I feel completely burnt out and defeated.",
    ]

    /// Relatively neutral journal entries (2-4 sentences each).
    static let neutralSnippets: [String] = [
        "Average day today. Went through my usual routine without anything particularly notable happening one way or another.",
        "Spent the day working on routine tasks. Nothing exciting but nothing bad either. Just a regular ordinary day overall.",
        "Had some meetings and finished a few tasks. Pretty standard day overall with nothing much to report or remember.",
        "Quiet day at home. Did some chores, read a bit, and watched some television. Uneventful but perfectly fine.",
        "Ran some errands and caught up on email. Not the most exciting day but I got some things done at least.",
        "Mixed bag today. Some things went reasonably well, others not so much. Ended up feeling neutral about it all.",
        "Busy with administrative tasks most of the day. Not particularly stimulating work but it was necessary to complete.",
        "Standard weekday routine. Coffee, work, lunch, more work, dinner. Nothing stood out as especially remarkable today.",
        "Did some organizing and planning for the week ahead. Productive in a quiet, unremarkable sort of way overall.",
        "Moderate day with a balanced mix of activities. Nothing to complain about and nothing to celebrate particularly either.",
    ]

    // MARK: - Habit Definitions

    /// Describes a habit's completion probability by day sentiment class.
    struct HabitDef {
        let name: String
        let emoji: String
        let category: String
        let positiveRate: Double   // probability of completion on positive-sentiment days
        let negativeRate: Double   // probability of completion on negative-sentiment days
        let neutralRate: Double    // probability of completion on neutral-sentiment days
    }

    /// Five habits with designed correlations to sentiment.
    ///
    /// - Meditation: strong positive (95% on happy, 10% on unhappy)
    /// - Exercise: moderate positive (60% on happy, 35% on unhappy)
    /// - Alcohol: strong negative (10% on happy, 85% on unhappy)
    /// - Reading: noise/random (50/50 regardless)
    /// - Water: no variance (completed every day → excluded by regression)
    static let habitDefinitions: [HabitDef] = [
        HabitDef(name: "Meditation", emoji: "🧘", category: "Wellness",
                 positiveRate: 0.95, negativeRate: 0.10, neutralRate: 0.50),
        HabitDef(name: "Exercise", emoji: "💪", category: "Fitness",
                 positiveRate: 0.60, negativeRate: 0.35, neutralRate: 0.45),
        HabitDef(name: "Alcohol", emoji: "🍺", category: "Health",
                 positiveRate: 0.10, negativeRate: 0.85, neutralRate: 0.40),
        HabitDef(name: "Reading", emoji: "📖", category: "Growth",
                 positiveRate: 0.50, negativeRate: 0.50, neutralRate: 0.50),
        HabitDef(name: "Water", emoji: "💧", category: "Health",
                 positiveRate: 1.00, negativeRate: 1.00, neutralRate: 1.00),
    ]

    // MARK: - Seed

    /// Seed journal entries and habit data with designed sentiment correlations.
    ///
    /// Creates 5 habits and `days` journal entries (1/day) with deterministic
    /// content and habit completions. Approximately 50% positive, 33% negative,
    /// 17% neutral days. Dates span 2 calendar months (Dec 2025 – Jan 2026)
    /// for monthly analysis testing.
    ///
    /// Journal entries are tagged `"synthetic"` and all created IDs are stored
    /// in UserDefaults for clean removal via `clearSyntheticData(from:)`.
    ///
    /// - Parameters:
    ///   - context: The SwiftData model context to insert into.
    ///   - days: Number of days to generate (default 60).
    ///   - seed: Random seed for reproducibility (default 42).
    @MainActor
    static func seedJournalAndHabits(
        in context: ModelContext,
        days: Int = 60,
        seed: UInt64 = 42
    ) {
        var rng = SeededGenerator(seed: seed)
        var journalIDs: [String] = []
        var habitIDs: [String] = []

        // 1. Create habits
        var habits: [Habit] = []
        for (index, def) in habitDefinitions.enumerated() {
            let habit = Habit(
                name: def.name,
                emoji: def.emoji,
                category: def.category,
                sortOrder: index
            )
            context.insert(habit)
            habits.append(habit)
            habitIDs.append(habit.id.uuidString)
        }

        // 2. Generate daily entries
        let calendar = Calendar.current
        // Reference: Jan 31 2026. Going back `days` days gives Dec 3 2025 → Jan 31 2026.
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!

        for dayOffset in 0 ..< days {
            guard let date = calendar.date(
                byAdding: .day,
                value: -(days - 1 - dayOffset),
                to: referenceDate
            ) else { continue }

            // Classify day sentiment: ~50% positive, ~33% negative, ~17% neutral
            let roll = Double.random(in: 0.0 ..< 1.0, using: &rng)
            let sentiment: DaySentiment
            if roll < 0.50 {
                sentiment = .positive
            } else if roll < 0.83 {
                sentiment = .negative
            } else {
                sentiment = .neutral
            }

            // Pick snippet from appropriate bank
            let snippets: [String]
            switch sentiment {
            case .positive: snippets = positiveSnippets
            case .negative: snippets = negativeSnippets
            case .neutral:  snippets = neutralSnippets
            }
            let content = snippets[Int.random(in: 0 ..< snippets.count, using: &rng)]

            // Assign sentiment score based on day class
            let sentimentScore: Double
            let sentimentLabel: String
            switch sentiment {
            case .positive:
                sentimentScore = Double.random(in: 0.5...1.0, using: &rng)
                sentimentLabel = "positive"
            case .negative:
                sentimentScore = Double.random(in: -1.0...(-0.5), using: &rng)
                sentimentLabel = "negative"
            case .neutral:
                sentimentScore = Double.random(in: -0.2...0.2, using: &rng)
                sentimentLabel = "neutral"
            }

            // Create journal entry — tagged "synthetic" for clean removal
            let entry = JournalEntry(
                date: date,
                content: content,
                createdAt: date,
                sentimentScore: sentimentScore,
                sentimentLabel: sentimentLabel,
                sentimentMagnitude: abs(sentimentScore),
                title: "Day \(dayOffset + 1)",
                wordCount: content.split(separator: " ").count,
                tags: ["synthetic"],
                updatedAt: date
            )
            context.insert(entry)
            journalIDs.append(entry.id.uuidString)

            // Create habit entries with correlation-based completion
            for (habitIndex, def) in habitDefinitions.enumerated() {
                let rate: Double
                switch sentiment {
                case .positive: rate = def.positiveRate
                case .negative: rate = def.negativeRate
                case .neutral:  rate = def.neutralRate
                }

                let completed = Double.random(in: 0.0 ..< 1.0, using: &rng) < rate
                let habitEntry = HabitEntry(
                    date: date,
                    completed: completed,
                    loggedAt: date
                )
                habitEntry.habit = habits[habitIndex]
                context.insert(habitEntry)
            }
        }

        // 3. Store IDs for later removal
        UserDefaults.standard.set(journalIDs, forKey: journalIDsKey)
        UserDefaults.standard.set(habitIDs, forKey: habitIDsKey)
    }

    // MARK: - Clear

    /// All known synthetic snippet content for fallback matching.
    private static let allSnippets: Set<String> = Set(
        positiveSnippets + negativeSnippets + neutralSnippets
    )

    /// All known synthetic habit names for fallback matching.
    private static let syntheticHabitNames: Set<String> = Set(
        habitDefinitions.map(\.name)
    )

    /// Remove all synthetic data without touching real user entries.
    ///
    /// First attempts to delete by stored IDs in UserDefaults (fast path).
    /// If no stored IDs exist (data was seeded before ID tracking), falls back
    /// to content-based matching: journal entries whose content matches a known
    /// snippet, and habits whose names match the synthetic habit definitions.
    /// Habit entries are cascade-deleted via the `Habit → HabitEntry` relationship.
    /// Also removes any `MonthlyAnalysis` for Dec 2025 and Jan 2026 (seeded months).
    @MainActor
    static func clearSyntheticData(from context: ModelContext) {
        let storedJournalIDs = Set(
            (UserDefaults.standard.stringArray(forKey: journalIDsKey) ?? [])
                .compactMap { UUID(uuidString: $0) }
        )
        let storedHabitIDs = Set(
            (UserDefaults.standard.stringArray(forKey: habitIDsKey) ?? [])
                .compactMap { UUID(uuidString: $0) }
        )

        let useIDMatching = !storedJournalIDs.isEmpty

        // Delete synthetic journal entries
        if let entries = try? context.fetch(FetchDescriptor<JournalEntry>()) {
            for entry in entries {
                let shouldDelete: Bool
                if useIDMatching {
                    shouldDelete = storedJournalIDs.contains(entry.id)
                } else {
                    // Fallback: match by content against known snippet banks
                    shouldDelete = allSnippets.contains(entry.content)
                }
                if shouldDelete { context.delete(entry) }
            }
        }

        // Delete synthetic habits (cascade deletes their HabitEntry children)
        if let habits = try? context.fetch(FetchDescriptor<Habit>()) {
            for habit in habits {
                let shouldDelete: Bool
                if useIDMatching {
                    shouldDelete = storedHabitIDs.contains(habit.id)
                } else {
                    // Fallback: match by name against known synthetic habit names
                    shouldDelete = syntheticHabitNames.contains(habit.name)
                }
                if shouldDelete { context.delete(habit) }
            }
        }

        // Clean up monthly analyses for the seeded months
        if let analyses = try? context.fetch(FetchDescriptor<MonthlyAnalysis>()) {
            for analysis in analyses {
                let isSeededMonth =
                    (analysis.month == 12 && analysis.year == 2025) ||
                    (analysis.month == 1 && analysis.year == 2026)
                if isSeededMonth { context.delete(analysis) }
            }
        }

        // Clear stored IDs
        UserDefaults.standard.removeObject(forKey: journalIDsKey)
        UserDefaults.standard.removeObject(forKey: habitIDsKey)
    }

    // MARK: - Types

    enum DaySentiment {
        case positive, negative, neutral
    }
}

// MARK: - SeededGenerator

/// Deterministic random number generator (xorshift64) for reproducible test data.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
