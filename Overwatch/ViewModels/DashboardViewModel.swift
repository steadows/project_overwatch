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
        let todayStart = calendar.startOfDay(for: .now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        let todayPredicate = #Predicate<HabitEntry> { entry in
            entry.date >= todayStart && entry.date < todayEnd && entry.completed
        }
        let todayDescriptor = FetchDescriptor<HabitEntry>(predicate: todayPredicate)
        let completedToday = (try? context.fetchCount(todayDescriptor)) ?? 0

        habitSummary = HabitSummary(
            totalHabits: totalHabits,
            completedToday: completedToday,
            currentStreak: 0
        )
    }

    private func loadTrackedHabits(from context: ModelContext) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let weekStart = calendar.date(byAdding: .day, value: -7, to: todayStart)!
        let monthStart = calendar.date(byAdding: .day, value: -30, to: todayStart)!

        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.name)])
        guard let habits = try? context.fetch(descriptor) else {
            trackedHabits = []
            return
        }

        trackedHabits = habits.map { habit in
            let entries = habit.entries

            let completedToday = entries.contains { entry in
                entry.date >= todayStart && entry.date < todayEnd && entry.completed
            }

            // Count unique completed days in the last 7 days
            let weeklyDays = Set(
                entries
                    .filter { $0.date >= weekStart && $0.completed }
                    .map { calendar.startOfDay(for: $0.date) }
            ).count

            // Count unique completed days in the last 30 days
            let monthlyDays = Set(
                entries
                    .filter { $0.date >= monthStart && $0.completed }
                    .map { calendar.startOfDay(for: $0.date) }
            ).count

            return TrackedHabit(
                id: habit.id,
                name: habit.name,
                emoji: habit.emoji,
                completedToday: completedToday,
                weeklyRate: Double(weeklyDays) / 7.0,
                monthlyRate: Double(monthlyDays) / 30.0
            )
        }
    }

    // MARK: - Habit Actions

    /// Add a new habit to track.
    func addHabit(name: String, emoji: String, to context: ModelContext) {
        let habit = Habit(name: name, emoji: emoji)
        context.insert(habit)
        loadData(from: context)
    }

    /// Toggle today's completion for a habit.
    func toggleHabitCompletion(_ habitID: UUID, in context: ModelContext) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        let descriptor = FetchDescriptor<Habit>()
        guard let habits = try? context.fetch(descriptor),
              let habit = habits.first(where: { $0.id == habitID }) else { return }

        // Check if already completed today
        if let existingEntry = habit.entries.first(where: {
            $0.date >= todayStart && $0.date < todayEnd && $0.completed
        }) {
            context.delete(existingEntry)
        } else {
            let entry = HabitEntry(date: .now, completed: true)
            entry.habit = habit
            context.insert(entry)
        }

        loadData(from: context)
    }

    /// Toggle today's completion with optional value and notes.
    func confirmHabitEntry(
        _ habitID: UUID,
        value: Double?,
        notes: String,
        in context: ModelContext
    ) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        let descriptor = FetchDescriptor<Habit>()
        guard let habits = try? context.fetch(descriptor),
              let habit = habits.first(where: { $0.id == habitID }) else { return }

        // Remove existing today entry if present
        if let existingEntry = habit.entries.first(where: {
            $0.date >= todayStart && $0.date < todayEnd && $0.completed
        }) {
            context.delete(existingEntry)
        }

        // Create new entry with value and notes
        let entry = HabitEntry(date: .now, completed: true)
        entry.value = value
        entry.notes = notes
        entry.habit = habit
        context.insert(entry)

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
