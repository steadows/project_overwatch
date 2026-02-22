import Foundation
import SwiftData

@MainActor
@Observable
final class WarRoomViewModel {

    // MARK: - Types

    enum DateRange: String, CaseIterable, Identifiable {
        case week = "1W"
        case month = "1M"
        case quarter = "3M"
        case year = "1Y"
        case all = "ALL"

        var id: String { rawValue }

        var dayCount: Int? {
            switch self {
            case .week: 7
            case .month: 30
            case .quarter: 90
            case .year: 365
            case .all: nil
            }
        }
    }

    enum ChartType: String, CaseIterable, Identifiable {
        case recovery = "RECOVERY"
        case habits = "HABITS"
        case correlation = "CORRELATION"
        case sleep = "SLEEP"
        case sentiment = "SENTIMENT"
        case habitSentiment = "HABIT × MOOD"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .recovery: "heart.text.square"
            case .habits: "checkmark.circle"
            case .correlation: "arrow.up.right.and.arrow.down.left"
            case .sleep: "moon.zzz"
            case .sentiment: "face.smiling"
            case .habitSentiment: "chart.dots.scatter"
            }
        }
    }

    // Chart data point types
    struct RecoveryPoint: Identifiable, Equatable {
        let id: Date
        let date: Date
        let score: Double
    }

    struct HabitDayPoint: Identifiable, Equatable {
        let id: String
        let date: Date
        let habitName: String
        let emoji: String
        let iconName: String
        let completed: Bool
    }

    struct CorrelationPoint: Identifiable, Equatable {
        let id: String
        let habitName: String
        let emoji: String
        let iconName: String
        let completionPercent: Double
        let recoveryAvg: Double
    }

    struct SleepPoint: Identifiable, Equatable {
        let id: Date
        let date: Date
        let swsHours: Double
        let remHours: Double
        let totalHours: Double
    }

    struct HabitSentimentPoint: Identifiable, Equatable {
        let id: String
        let habitName: String
        let emoji: String
        let iconName: String
        let completionPercent: Double
        let avgSentiment: Double
    }

    // MARK: - State

    var selectedDateRange: DateRange = .month
    var selectedChartType: ChartType = .recovery
    var latestInsight: ReportsViewModel.ReportCard?
    var isRefreshing = false
    var refreshProgress: String?

    // Chart data
    var recoveryData: [RecoveryPoint] = []
    var habitDayData: [HabitDayPoint] = []
    var correlationData: [CorrelationPoint] = []
    var sleepData: [SleepPoint] = []
    var sentimentData: [JournalViewModel.SentimentDataPoint] = []
    var habitCompletionOverlay: [JournalViewModel.DailyHabitCompletion] = []
    var habitSentimentData: [HabitSentimentPoint] = []

    // Sentiment gauge
    var gaugeData: [JournalViewModel.SentimentDataPoint] = []

    // MARK: - Dependencies

    private let intelligenceManager: IntelligenceManager

    init(intelligenceManager: IntelligenceManager = IntelligenceManager()) {
        self.intelligenceManager = intelligenceManager
    }

    /// Set when refresh fails due to rate limiting
    var isThrottled = false
    var throttleMessage: String?

    // MARK: - Computed

    var hasData: Bool {
        !recoveryData.isEmpty || !sentimentData.isEmpty || !habitDayData.isEmpty
    }

    /// True when WHOOP biometric data exists for the selected date range
    var hasWhoopData: Bool {
        !recoveryData.isEmpty || !sleepData.isEmpty
    }

    /// Whether the Gemini API key is configured
    var geminiAvailable: Bool { EnvironmentConfig.geminiAPIKey != nil }

    private var dateWindow: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: .now)
        guard let days = selectedDateRange.dayCount else {
            // "ALL" — use earliest available date
            let earliest = calendar.date(byAdding: .year, value: -5, to: now)!
            return (earliest, now)
        }
        let start = calendar.date(byAdding: .day, value: -days, to: now)!
        return (start, now)
    }

    // MARK: - Data Loading

    func loadData(from context: ModelContext) {
        let window = dateWindow
        loadLatestInsight(from: context)
        loadRecoveryData(from: context, window: window)
        loadHabitDayData(from: context, window: window)
        loadCorrelationData(from: context, window: window)
        loadSleepData(from: context, window: window)
        loadSentimentData(from: context, window: window)
        loadHabitSentimentData(from: context, window: window)
    }

    private func loadLatestInsight(from context: ModelContext) {
        let descriptor = FetchDescriptor<WeeklyInsight>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        guard let insight = (try? context.fetch(descriptor))?.first else {
            latestInsight = nil
            return
        }
        latestInsight = ReportsViewModel.ReportCard(
            id: insight.id,
            dateRangeStart: insight.dateRangeStart,
            dateRangeEnd: insight.dateRangeEnd,
            summary: insight.summary,
            forceMultiplierHabit: insight.forceMultiplierHabit,
            recommendations: insight.recommendations,
            correlations: insight.correlations,
            averageSentiment: insight.averageSentiment,
            sentimentTrend: insight.sentimentTrend,
            generatedAt: insight.generatedAt
        )
    }

    private func loadRecoveryData(from context: ModelContext, window: (start: Date, end: Date)) {
        let cycles = ((try? context.fetch(FetchDescriptor<WhoopCycle>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.date >= window.start && $0.date <= window.end }

        recoveryData = cycles
            .filter { $0.recoveryScore > 0 }
            .map { cycle in
                RecoveryPoint(id: cycle.date, date: cycle.date, score: cycle.recoveryScore)
            }
    }

    private func loadHabitDayData(from context: ModelContext, window: (start: Date, end: Date)) {
        let habits = (try? context.fetch(FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []

        var points: [HabitDayPoint] = []
        let calendar = Calendar.current

        for habit in habits {
            let entries = habit.entries.filter {
                $0.date >= window.start && $0.date <= window.end && $0.completed
            }
            let completedDays = Set(entries.map { calendar.startOfDay(for: $0.date) })

            // Generate one point per day for stacked bar
            var cursor = calendar.startOfDay(for: window.start)
            while cursor <= window.end {
                if completedDays.contains(cursor) {
                    points.append(HabitDayPoint(
                        id: "\(habit.id)-\(cursor.timeIntervalSince1970)",
                        date: cursor,
                        habitName: habit.name,
                        emoji: habit.emoji,
                        iconName: HabitIcons.icon(for: habit.name),
                        completed: true
                    ))
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }
        }
        habitDayData = points
    }

    private func loadCorrelationData(from context: ModelContext, window: (start: Date, end: Date)) {
        let habits = (try? context.fetch(FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []
        let cycles = ((try? context.fetch(FetchDescriptor<WhoopCycle>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.date >= window.start && $0.date <= window.end }

        guard !cycles.isEmpty else {
            correlationData = []
            return
        }

        let calendar = Calendar.current
        let totalDays = max(1, calendar.dateComponents([.day], from: window.start, to: window.end).day ?? 1)

        // Map cycles to recovery by day
        var recoveryByDay: [Date: Double] = [:]
        for cycle in cycles {
            recoveryByDay[calendar.startOfDay(for: cycle.date)] = cycle.recoveryScore
        }

        correlationData = habits.compactMap { habit -> CorrelationPoint? in
            let completedDays = Set(
                habit.entries
                    .filter { $0.date >= window.start && $0.date <= window.end && $0.completed }
                    .map { calendar.startOfDay(for: $0.date) }
            )
            let completionPct = Double(completedDays.count) / Double(totalDays) * 100

            // Average recovery on days habit was completed
            let recoveryOnHabitDays = completedDays.compactMap { recoveryByDay[$0] }
            guard !recoveryOnHabitDays.isEmpty else { return nil }
            let avgRecovery = recoveryOnHabitDays.reduce(0, +) / Double(recoveryOnHabitDays.count)

            return CorrelationPoint(
                id: habit.id.uuidString,
                habitName: habit.name,
                emoji: habit.emoji,
                iconName: HabitIcons.icon(for: habit.name),
                completionPercent: completionPct,
                recoveryAvg: avgRecovery
            )
        }
    }

    private func loadSleepData(from context: ModelContext, window: (start: Date, end: Date)) {
        let cycles = ((try? context.fetch(FetchDescriptor<WhoopCycle>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.date >= window.start && $0.date <= window.end }

        sleepData = cycles
            .filter { $0.sleepSWSMilli > 0 || $0.sleepREMMilli > 0 }
            .map { cycle in
                SleepPoint(
                    id: cycle.date,
                    date: cycle.date,
                    swsHours: Double(cycle.sleepSWSMilli) / 3_600_000,
                    remHours: Double(cycle.sleepREMMilli) / 3_600_000,
                    totalHours: (Double(cycle.sleepSWSMilli) + Double(cycle.sleepREMMilli)) / 3_600_000
                )
            }
    }

    private func loadSentimentData(from context: ModelContext, window: (start: Date, end: Date)) {
        let calendar = Calendar.current
        let entries = ((try? context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.date >= window.start && $0.date <= window.end }

        sentimentData = entries.map { entry in
            JournalViewModel.SentimentDataPoint(
                id: calendar.startOfDay(for: entry.date),
                date: entry.date,
                score: entry.sentimentScore
            )
        }

        gaugeData = sentimentData

        // Habit completion overlay
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        var completionByDay: [Date: Int] = [:]
        for habit in habits {
            for entry in habit.entries where entry.completed && entry.date >= window.start && entry.date <= window.end {
                let day = calendar.startOfDay(for: entry.date)
                completionByDay[day, default: 0] += 1
            }
        }
        habitCompletionOverlay = completionByDay.map { day, count in
            JournalViewModel.DailyHabitCompletion(id: day, date: day, count: count)
        }.sorted { $0.date < $1.date }
    }

    private func loadHabitSentimentData(from context: ModelContext, window: (start: Date, end: Date)) {
        let calendar = Calendar.current
        let habits = (try? context.fetch(FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []
        let entries = ((try? context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.date >= window.start && $0.date <= window.end }

        guard !entries.isEmpty else {
            habitSentimentData = []
            return
        }

        let totalDays = max(1, calendar.dateComponents([.day], from: window.start, to: window.end).day ?? 1)

        // Map sentiment by day
        var sentimentByDay: [Date: [Double]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            sentimentByDay[day, default: []].append(entry.sentimentScore)
        }

        habitSentimentData = habits.compactMap { habit -> HabitSentimentPoint? in
            let completedDays = Set(
                habit.entries
                    .filter { $0.date >= window.start && $0.date <= window.end && $0.completed }
                    .map { calendar.startOfDay(for: $0.date) }
            )
            let completionPct = Double(completedDays.count) / Double(totalDays) * 100

            // Average sentiment on days habit was completed
            let sentimentOnHabitDays = completedDays.compactMap { day -> Double? in
                guard let scores = sentimentByDay[day] else { return nil }
                return scores.reduce(0, +) / Double(scores.count)
            }
            guard !sentimentOnHabitDays.isEmpty else { return nil }
            let avgSentiment = sentimentOnHabitDays.reduce(0, +) / Double(sentimentOnHabitDays.count)

            return HabitSentimentPoint(
                id: habit.id.uuidString,
                habitName: habit.name,
                emoji: habit.emoji,
                iconName: HabitIcons.icon(for: habit.name),
                completionPercent: completionPct,
                avgSentiment: avgSentiment
            )
        }
    }

    // MARK: - Refresh Analysis

    func refreshAnalysis(from context: ModelContext) async {
        isRefreshing = true
        isThrottled = false
        throttleMessage = nil
        refreshProgress = "COMPILING INTELLIGENCE BRIEFING..."

        let window = dateWindow
        do {
            let _ = try await intelligenceManager.generateWeeklyReport(
                startDate: window.start,
                endDate: window.end,
                from: context
            )
            loadData(from: context)
        } catch {
            if let geminiError = error as? GeminiError {
                switch geminiError {
                case .rateLimited:
                    isThrottled = true
                    throttleMessage = "Rate limit exceeded — try again later"
                case .noAPIKey:
                    refreshProgress = "INTELLIGENCE CORE OFFLINE"
                default:
                    refreshProgress = "REFRESH FAILED"
                }
            } else {
                refreshProgress = "REFRESH FAILED"
            }
        }

        isRefreshing = false
        refreshProgress = nil
    }
}
