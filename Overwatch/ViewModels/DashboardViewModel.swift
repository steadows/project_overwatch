import Foundation
import Observation
import SwiftData

/// ViewModel for the Tactical Dashboard.
///
/// Owns the WHOOP sync status display, latest biometric data,
/// habit completion stats, and full habit tracking with weekly/monthly rates.
@MainActor
@Observable
final class DashboardViewModel {

    // MARK: - WHOOP Status

    struct WhoopMetrics: Equatable {
        var recoveryScore: Double = 0
        var strain: Double = 0
        var sleepPerformance: Double = 0
        var restingHeartRate: Double = 0
        var hrvRmssd: Double = 0
        var lastSyncedAt: Date?

        static let empty = WhoopMetrics()
    }

    var whoopMetrics = WhoopMetrics.empty
    var syncStatus: AppState.SyncStatus = .idle
    var whoopError: String?

    /// True when WHOOP was connected but API returned an error (distinct from "not connected")
    var hasWhoopError: Bool { whoopError != nil }

    /// True when the Gemini API key is configured
    var geminiAvailable: Bool { EnvironmentConfig.geminiAPIKey != nil }

    // MARK: - Habit Summary

    struct HabitSummary: Equatable {
        var totalHabits: Int = 0
        var completedToday: Int = 0
        var currentStreak: Int = 0

        var completionRate: Double {
            guard totalHabits > 0 else { return 0 }
            return Double(completedToday) / Double(totalHabits)
        }

        static let empty = HabitSummary()
    }

    var habitSummary = HabitSummary.empty

    // MARK: - Tracked Habits

    struct TrackedHabit: Identifiable, Equatable {
        let id: UUID
        let name: String
        let emoji: String
        var completedToday: Bool
        var weeklyRate: Double   // 0.0–1.0 (completed days / 7)
        var monthlyRate: Double  // 0.0–1.0 (completed days / 30)
    }

    var trackedHabits: [TrackedHabit] = []

    // MARK: - Heat Map

    /// Pre-computed 30-day heat map data for the dashboard compact preview.
    var compactHeatMapDays: [HeatMapDay] = []

    // MARK: - Sentiment Pulse

    struct SentimentPulse: Equatable {
        var todayScore: Double = 0
        var todayLabel: String = "neutral"
        var hasEntriesToday: Bool = false
        var sparklineData: [Double] = []

        static let empty = SentimentPulse()
    }

    var sentimentPulse = SentimentPulse.empty

    // MARK: - Date Navigation

    /// The date the habit section is showing. Defaults to today.
    var selectedDate: Date = .now

    /// True when `selectedDate` is the current calendar day.
    var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Display label for the selected date (e.g. "TODAY" or "FEB 18, 2026").
    var selectedDateLabel: String {
        if isViewingToday { return "TODAY" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate).uppercased()
    }

    /// Step forward or backward by a number of days.
    func navigateDate(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        // Don't allow navigating into the future
        let todayEnd = Calendar.current.startOfDay(for: .now)
        if newDate > todayEnd { return }
        selectedDate = newDate
    }

    /// Snap back to today.
    func goToToday() {
        selectedDate = .now
    }

    // MARK: - Dashboard Interaction State

    /// Which habit's expand panel is currently open (nil = all collapsed)
    var expandedHabitID: UUID?

    /// Whether the compact WHOOP strip is expanded to show full arc gauges
    var isWhoopExpanded = false

    /// Whether WHOOP data is available (has at least one synced cycle)
    var hasWhoopData: Bool {
        whoopMetrics.lastSyncedAt != nil
    }

    // MARK: - Data Loading

    /// Refresh all dashboard data from the given model context.
    func loadData(from context: ModelContext) {
        loadWhoopMetrics(from: context)
        loadHabitSummary(from: context)
        loadTrackedHabits(from: context)
        loadHeatMapData(from: context)
        loadSentimentPulse(from: context)
    }

    private func loadWhoopMetrics(from context: ModelContext) {
        var descriptor = FetchDescriptor<WhoopCycle>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let latest = try? context.fetch(descriptor).first else {
            whoopMetrics = .empty
            return
        }

        whoopMetrics = WhoopMetrics(
            recoveryScore: latest.recoveryScore,
            strain: latest.strain,
            sleepPerformance: latest.sleepPerformance,
            restingHeartRate: latest.restingHeartRate,
            hrvRmssd: latest.hrvRmssdMilli,
            lastSyncedAt: latest.fetchedAt
        )
    }

    private func loadHabitSummary(from context: ModelContext) {
        let habitsDescriptor = FetchDescriptor<Habit>()
        let totalHabits = (try? context.fetchCount(habitsDescriptor)) ?? 0

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let dayPredicate = #Predicate<HabitEntry> { entry in
            entry.date >= dayStart && entry.date < dayEnd && entry.completed
        }
        let dayDescriptor = FetchDescriptor<HabitEntry>(predicate: dayPredicate)
        let completedOnDay = (try? context.fetchCount(dayDescriptor)) ?? 0

        habitSummary = HabitSummary(
            totalHabits: totalHabits,
            completedToday: completedOnDay,
            currentStreak: 0
        )
    }

    private func loadTrackedHabits(from context: ModelContext) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let weekStart = calendar.date(byAdding: .day, value: -7, to: dayStart)!
        let monthStart = calendar.date(byAdding: .day, value: -30, to: dayStart)!

        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)])
        guard let habits = try? context.fetch(descriptor) else {
            trackedHabits = []
            return
        }

        trackedHabits = habits.map { habit in
            let entries = habit.entries

            let completedOnDay = entries.contains { entry in
                entry.date >= dayStart && entry.date < dayEnd && entry.completed
            }

            // Count unique completed days in the 7 days ending on selectedDate
            let weeklyDays = Set(
                entries
                    .filter { $0.date >= weekStart && $0.date < dayEnd && $0.completed }
                    .map { calendar.startOfDay(for: $0.date) }
            ).count

            // Count unique completed days in the 30 days ending on selectedDate
            let monthlyDays = Set(
                entries
                    .filter { $0.date >= monthStart && $0.date < dayEnd && $0.completed }
                    .map { calendar.startOfDay(for: $0.date) }
            ).count

            // Goal-relative rates
            let weeklyTarget = Double(min(habit.targetFrequency, 7))
            let monthlyTarget = Double(habit.targetFrequency) * 30.0 / 7.0

            return TrackedHabit(
                id: habit.id,
                name: habit.name,
                emoji: habit.emoji,
                completedToday: completedOnDay,
                weeklyRate: min(weeklyTarget > 0 ? Double(weeklyDays) / weeklyTarget : 0, 1.0),
                monthlyRate: min(monthlyTarget > 0 ? Double(monthlyDays) / monthlyTarget : 0, 1.0)
            )
        }
    }

    // MARK: - Heat Map Data

    private func loadHeatMapData(from context: ModelContext) {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)])
        guard let habits = try? context.fetch(descriptor) else {
            compactHeatMapDays = []
            return
        }
        compactHeatMapDays = HeatMapDataBuilder.buildAggregate(habits: habits, dayCount: 35)
    }

    // MARK: - Sentiment Pulse Data

    private func loadSentimentPulse(from context: ModelContext) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let weekStart = calendar.date(byAdding: .day, value: -7, to: todayStart)!

        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date)]
        )
        guard let allEntries = try? context.fetch(descriptor) else {
            sentimentPulse = .empty
            return
        }

        let todayEntries = allEntries.filter { $0.date >= todayStart && $0.date < todayEnd }
        let weekEntries = allEntries.filter { $0.date >= weekStart && $0.date < todayEnd }

        let hasToday = !todayEntries.isEmpty
        let todayAvg = hasToday
            ? todayEntries.map(\.sentimentScore).reduce(0, +) / Double(todayEntries.count)
            : 0.0

        let todayLabel: String
        if !hasToday {
            todayLabel = "neutral"
        } else if todayAvg > 0.1 {
            todayLabel = "positive"
        } else if todayAvg < -0.1 {
            todayLabel = "negative"
        } else {
            todayLabel = "neutral"
        }

        // Build 7-day sparkline: one value per day (average sentiment, 0 if no entries)
        var sparkline: [Double] = []
        for offset in (0..<7).reversed() {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let dayEntries = weekEntries.filter { $0.date >= dayStart && $0.date < dayEnd }
            if dayEntries.isEmpty {
                sparkline.append(0)
            } else {
                sparkline.append(
                    dayEntries.map(\.sentimentScore).reduce(0, +) / Double(dayEntries.count)
                )
            }
        }

        sentimentPulse = SentimentPulse(
            todayScore: todayAvg,
            todayLabel: todayLabel,
            hasEntriesToday: hasToday,
            sparklineData: sparkline
        )
    }

    // MARK: - Habit Actions

    /// Add a new habit to track.
    func addHabit(name: String, emoji: String, to context: ModelContext) {
        let habit = Habit(name: name, emoji: emoji)
        context.insert(habit)
        loadData(from: context)
    }

    /// Toggle completion for a habit on the selected date.
    func toggleHabitCompletion(_ habitID: UUID, in context: ModelContext) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let descriptor = FetchDescriptor<Habit>()
        guard let habits = try? context.fetch(descriptor),
              let habit = habits.first(where: { $0.id == habitID }) else { return }

        // Delete ALL completed entries for the selected day (not just the first)
        let dayEntries = habit.entries.filter {
            $0.date >= dayStart && $0.date < dayEnd && $0.completed
        }

        if !dayEntries.isEmpty {
            dayEntries.forEach { context.delete($0) }
        } else {
            // Place entry at noon on the selected day so it sorts well
            let entryDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            let entry = HabitEntry(date: entryDate, completed: true)
            entry.habit = habit
            context.insert(entry)
        }

        // Flush so relationship data is fresh for loadData
        try? context.save()
        loadData(from: context)
    }

    /// Confirm a habit entry with optional value and notes on the selected date.
    func confirmHabitEntry(
        _ habitID: UUID,
        value: Double?,
        notes: String,
        in context: ModelContext
    ) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let descriptor = FetchDescriptor<Habit>()
        guard let habits = try? context.fetch(descriptor),
              let habit = habits.first(where: { $0.id == habitID }) else { return }

        // Remove ALL existing entries for the selected day before creating the confirmed one
        habit.entries
            .filter { $0.date >= dayStart && $0.date < dayEnd && $0.completed }
            .forEach { context.delete($0) }

        // Place entry at noon on the selected day
        let entryDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let entry = HabitEntry(date: entryDate, completed: true)
        entry.value = value
        entry.notes = notes
        entry.habit = habit
        context.insert(entry)

        // Flush so relationship data is fresh for loadData
        try? context.save()
        expandedHabitID = nil
        loadData(from: context)
    }

    /// Expand or collapse a habit's detail panel.
    func toggleExpandedHabit(_ habitID: UUID) {
        if expandedHabitID == habitID {
            expandedHabitID = nil
        } else {
            expandedHabitID = habitID
        }
    }
}
