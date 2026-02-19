import Foundation
import Observation
import SwiftData

/// ViewModel for the Habits page — full CRUD, streak calculation,
/// category filtering, and drag-and-drop reordering.
@MainActor
@Observable
final class HabitsViewModel {

    // MARK: - Default Categories

    static let defaultCategories = [
        "General", "Health", "Fitness", "Mindfulness", "Productivity",
        "Social", "Financial", "Educational", "Religious"
    ]

    // MARK: - Display Types

    struct HabitItem: Identifiable, Equatable {
        let id: UUID
        let name: String
        let emoji: String
        let category: String
        let targetFrequency: Int
        let isQuantitative: Bool
        let unitLabel: String
        var currentStreak: Int
        var longestStreak: Int
        var weeklyRate: Double   // 0.0–1.0
        var monthlyRate: Double  // 0.0–1.0
        var allTimeRate: Double  // 0.0–1.0
        var totalCompletions: Int
        var sortOrder: Int
        var createdAt: Date
    }

    /// Streak milestones that trigger celebrations.
    static let streakMilestones = [7, 30, 100, 365]

    /// Returns the highest milestone the streak has reached, or nil.
    static func currentMilestone(for streak: Int) -> Int? {
        streakMilestones.last { streak >= $0 }
    }

    /// Returns true if the streak is exactly at a milestone value.
    static func isExactMilestone(_ streak: Int) -> Bool {
        streakMilestones.contains(streak)
    }

    // MARK: - Trend Chart Types

    enum TrendDateRange: String, CaseIterable, Identifiable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case year = "1Y"

        var id: String { rawValue }

        var dayCount: Int {
            switch self {
            case .week: 7
            case .month: 30
            case .threeMonths: 90
            case .year: 365
            }
        }
    }

    struct TrendDataPoint: Identifiable, Equatable {
        let id: Date
        let date: Date
        let value: Double
    }

    struct TrendChartData: Equatable {
        let habitPoints: [TrendDataPoint]
        let whoopPoints: [TrendDataPoint]
        let isQuantitative: Bool
        let unitLabel: String
        let habitName: String
        let hasEnoughData: Bool
        let maxHabitValue: Double
        let minHabitValue: Double
    }

    // MARK: - State

    var habits: [HabitItem] = []
    var selectedHabitID: UUID?
    var selectedCategory: String?
    var availableCategories: [String] = []
    var selectedHabitHeatMapDays: [HeatMapDay] = []
    var selectedTrendRange: TrendDateRange = .month
    var showWhoopOverlay = false
    var trendChartData: TrendChartData?

    // MARK: - Computed

    var filteredHabits: [HabitItem] {
        guard let category = selectedCategory else { return habits }
        return habits.filter { $0.category == category }
    }

    var selectedHabit: HabitItem? {
        guard let id = selectedHabitID else { return nil }
        return habits.first { $0.id == id }
    }

    // MARK: - Data Loading

    func loadData(from context: ModelContext) {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        guard let allHabits = try? context.fetch(descriptor) else {
            habits = []
            availableCategories = []
            return
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let weekStart = calendar.date(byAdding: .day, value: -7, to: todayStart)!
        let monthStart = calendar.date(byAdding: .day, value: -30, to: todayStart)!

        habits = allHabits.map { habit in
            let entries = habit.entries

            let streak = calculateCurrentStreak(
                entries: entries, calendar: calendar, from: todayStart
            )
            let longest = calculateLongestStreak(
                entries: entries, calendar: calendar
            )

            let weeklyDays = Set(
                entries.filter { $0.date >= weekStart && $0.completed }
                    .map { calendar.startOfDay(for: $0.date) }
            ).count

            let monthlyDays = Set(
                entries.filter { $0.date >= monthStart && $0.completed }
                    .map { calendar.startOfDay(for: $0.date) }
            ).count

            let total = entries.filter(\.completed).count

            let daysSinceCreated = max(
                1,
                (calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: habit.createdAt),
                    to: todayStart
                ).day ?? 0) + 1
            )
            let allTimeDays = Set(
                entries.filter(\.completed)
                    .map { calendar.startOfDay(for: $0.date) }
            ).count
            let allTimeRate = Double(allTimeDays) / Double(daysSinceCreated)

            let weeklyTarget = Double(min(habit.targetFrequency, 7))
            let monthlyTarget = Double(habit.targetFrequency) * 30.0 / 7.0

            // Goal-relative: days achieved / days expected
            let weeklyRate = weeklyTarget > 0 ? Double(weeklyDays) / weeklyTarget : 0
            let monthlyRate = monthlyTarget > 0 ? Double(monthlyDays) / monthlyTarget : 0

            // All-time rate relative to target frequency
            let expectedAllTime = Double(habit.targetFrequency) * Double(daysSinceCreated) / 7.0
            let goalRelativeAllTime = expectedAllTime > 0 ? Double(allTimeDays) / expectedAllTime : 0

            return HabitItem(
                id: habit.id,
                name: habit.name,
                emoji: habit.emoji,
                category: habit.category,
                targetFrequency: habit.targetFrequency,
                isQuantitative: habit.isQuantitative,
                unitLabel: habit.unitLabel,
                currentStreak: streak,
                longestStreak: longest,
                weeklyRate: min(weeklyRate, 1.0),
                monthlyRate: min(monthlyRate, 1.0),
                allTimeRate: min(goalRelativeAllTime, 1.0),
                totalCompletions: total,
                sortOrder: habit.sortOrder,
                createdAt: habit.createdAt
            )
        }

        availableCategories = Array(Set(allHabits.map(\.category))).sorted()

        // Refresh heat map and trend chart for selected habit if one is active
        loadSelectedHabitHeatMap(from: context)
        loadTrendChartData(from: context)
    }

    /// Loads 12-month heat map data for the currently selected habit.
    func loadSelectedHabitHeatMap(from context: ModelContext) {
        guard let selectedID = selectedHabitID else {
            selectedHabitHeatMapDays = []
            return
        }

        let descriptor = FetchDescriptor<Habit>()
        guard let allHabits = try? context.fetch(descriptor),
              let habit = allHabits.first(where: { $0.id == selectedID }) else {
            selectedHabitHeatMapDays = []
            return
        }

        selectedHabitHeatMapDays = HeatMapDataBuilder.buildForHabit(habit, dayCount: 365)
    }

    // MARK: - Trend Chart Data

    /// Loads trend chart data for the currently selected habit and date range.
    func loadTrendChartData(from context: ModelContext) {
        guard let selectedID = selectedHabitID else {
            trendChartData = nil
            return
        }

        let descriptor = FetchDescriptor<Habit>()
        guard let allHabits = try? context.fetch(descriptor),
              let habit = allHabits.first(where: { $0.id == selectedID }) else {
            trendChartData = nil
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dayCount = selectedTrendRange.dayCount
        let rangeStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today)!

        // Build ordered date range
        let dateRange = (0..<dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: rangeStart)
        }

        let habitPoints: [TrendDataPoint]
        let isQuantitative = habit.isQuantitative

        if isQuantitative {
            let entries = habit.entries
                .filter { $0.completed && $0.value != nil }
                .map { (date: calendar.startOfDay(for: $0.date), value: $0.value!) }
            habitPoints = Self.computeQuantityTrend(entries: entries, dateRange: dateRange)
        } else {
            let completedDates = Set(
                habit.entries
                    .filter(\.completed)
                    .map { calendar.startOfDay(for: $0.date) }
            )
            let habitCreated = calendar.startOfDay(for: habit.createdAt)
            habitPoints = Self.computeRollingAverage(
                completedDates: completedDates,
                dateRange: dateRange,
                habitCreatedDate: habitCreated
            )
        }

        // WHOOP overlay
        var whoopPoints: [TrendDataPoint] = []
        if showWhoopOverlay {
            let whoopDescriptor = FetchDescriptor<WhoopCycle>(
                sortBy: [SortDescriptor(\.date)]
            )
            if let cycles = try? context.fetch(whoopDescriptor) {
                let filtered = cycles.filter {
                    let d = calendar.startOfDay(for: $0.date)
                    return d >= rangeStart && d <= today
                }
                whoopPoints = filtered.map { cycle in
                    let d = calendar.startOfDay(for: cycle.date)
                    return TrendDataPoint(id: d, date: d, value: cycle.recoveryScore)
                }
            }
        }

        let values = habitPoints.map(\.value)
        let maxVal = values.max() ?? 1
        let minVal = values.min() ?? 0

        trendChartData = TrendChartData(
            habitPoints: habitPoints,
            whoopPoints: whoopPoints,
            isQuantitative: isQuantitative,
            unitLabel: habit.unitLabel,
            habitName: habit.name,
            hasEnoughData: habitPoints.filter({ $0.value > 0 }).count >= 7,
            maxHabitValue: maxVal,
            minHabitValue: minVal
        )
    }

    /// Computes 7-day rolling average for boolean habit completion.
    /// Returns values as percentages (0–100).
    static func computeRollingAverage(
        completedDates: Set<Date>,
        dateRange: [Date],
        habitCreatedDate: Date,
        windowSize: Int = 7
    ) -> [TrendDataPoint] {
        dateRange.compactMap { date in
            // Only include dates from when the habit existed
            guard date >= habitCreatedDate else { return nil }

            var completions = 0
            var denominator = 0
            for offset in 0..<windowSize {
                guard let checkDate = Calendar.current.date(
                    byAdding: .day, value: -offset, to: date
                ) else { continue }
                // Don't count days before the habit existed
                guard checkDate >= habitCreatedDate else { continue }
                denominator += 1
                if completedDates.contains(checkDate) {
                    completions += 1
                }
            }
            guard denominator > 0 else { return nil }
            let avg = Double(completions) / Double(denominator) * 100.0
            return TrendDataPoint(id: date, date: date, value: avg)
        }
    }

    /// Aggregates quantity entries per day (sums multiple entries on same day).
    static func computeQuantityTrend(
        entries: [(date: Date, value: Double)],
        dateRange: [Date]
    ) -> [TrendDataPoint] {
        var byDate: [Date: Double] = [:]
        for entry in entries {
            byDate[entry.date, default: 0] += entry.value
        }

        return dateRange.compactMap { date in
            guard let value = byDate[date] else { return nil }
            return TrendDataPoint(id: date, date: date, value: value)
        }
    }

    // MARK: - Streak Calculations

    private func calculateCurrentStreak(
        entries: [HabitEntry],
        calendar: Calendar,
        from today: Date
    ) -> Int {
        let completedDays = Set(
            entries.filter(\.completed)
                .map { calendar.startOfDay(for: $0.date) }
        )

        guard !completedDays.isEmpty else { return 0 }

        var streak = 0
        var checkDate = today

        // If today is not completed, start from yesterday
        if !completedDays.contains(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if !completedDays.contains(checkDate) {
                return 0
            }
        }

        while completedDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    private func calculateLongestStreak(
        entries: [HabitEntry],
        calendar: Calendar
    ) -> Int {
        let completedDays = Set(
            entries.filter(\.completed)
                .map { calendar.startOfDay(for: $0.date) }
        ).sorted()

        guard !completedDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<completedDays.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: completedDays[i - 1])!
            if calendar.isDate(completedDays[i], inSameDayAs: expected) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    // MARK: - CRUD

    func addHabit(
        name: String,
        emoji: String,
        category: String,
        targetFrequency: Int,
        isQuantitative: Bool,
        unitLabel: String,
        to context: ModelContext
    ) {
        let maxOrder = habits.map(\.sortOrder).max() ?? -1
        let habit = Habit(
            name: name,
            emoji: emoji,
            category: category,
            targetFrequency: targetFrequency,
            isQuantitative: isQuantitative,
            unitLabel: unitLabel,
            sortOrder: maxOrder + 1
        )
        context.insert(habit)
        loadData(from: context)
    }

    func updateHabit(
        _ habitID: UUID,
        name: String,
        emoji: String,
        category: String,
        targetFrequency: Int,
        isQuantitative: Bool,
        unitLabel: String,
        in context: ModelContext
    ) {
        let descriptor = FetchDescriptor<Habit>()
        guard let allHabits = try? context.fetch(descriptor),
              let habit = allHabits.first(where: { $0.id == habitID }) else { return }

        habit.name = name
        habit.emoji = emoji
        habit.category = category
        habit.targetFrequency = targetFrequency
        habit.isQuantitative = isQuantitative
        habit.unitLabel = unitLabel
        loadData(from: context)
    }

    func deleteHabit(_ habitID: UUID, from context: ModelContext) {
        let descriptor = FetchDescriptor<Habit>()
        guard let allHabits = try? context.fetch(descriptor),
              let habit = allHabits.first(where: { $0.id == habitID }) else { return }

        context.delete(habit)
        if selectedHabitID == habitID {
            selectedHabitID = nil
        }
        loadData(from: context)
    }

    // MARK: - Reordering

    func moveHabit(from sourceID: UUID, toPositionOf targetID: UUID) {
        guard sourceID != targetID else { return }
        guard let sourceIndex = habits.firstIndex(where: { $0.id == sourceID }),
              var targetIndex = habits.firstIndex(where: { $0.id == targetID }) else { return }

        let item = habits.remove(at: sourceIndex)
        if sourceIndex < targetIndex {
            targetIndex -= 1
        }
        habits.insert(item, at: targetIndex)
    }

    func commitReorder(in context: ModelContext) {
        let orderedIDs = habits.map(\.id)
        let descriptor = FetchDescriptor<Habit>()
        guard let allHabits = try? context.fetch(descriptor) else { return }

        for (index, id) in orderedIDs.enumerated() {
            if let habit = allHabits.first(where: { $0.id == id }) {
                habit.sortOrder = index
            }
        }
        loadData(from: context)
    }
}
