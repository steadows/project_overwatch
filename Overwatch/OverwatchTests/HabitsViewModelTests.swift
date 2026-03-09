import Testing
import Foundation
import SwiftData
@testable import Overwatch

// MARK: - Test Helpers

@MainActor
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Habit.self, HabitEntry.self, JournalEntry.self,
        MonthlyAnalysis.self, WhoopCycle.self, WeeklyInsight.self,
        configurations: config
    )
}

@MainActor
private func seedHabitsWithEntries(in context: ModelContext) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let meditation = Habit(
        name: "Meditation", emoji: "🧘", category: "Wellness",
        targetFrequency: 7, isQuantitative: false, unitLabel: "", sortOrder: 0,
        createdAt: calendar.date(byAdding: .day, value: -30, to: today)!
    )
    let exercise = Habit(
        name: "Exercise", emoji: "🏋️", category: "Fitness",
        targetFrequency: 5, isQuantitative: false, unitLabel: "", sortOrder: 1,
        createdAt: calendar.date(byAdding: .day, value: -30, to: today)!
    )
    let water = Habit(
        name: "Water", emoji: "💧", category: "Health",
        targetFrequency: 7, isQuantitative: true, unitLabel: "L", sortOrder: 2,
        createdAt: calendar.date(byAdding: .day, value: -30, to: today)!
    )
    context.insert(meditation)
    context.insert(exercise)
    context.insert(water)

    // Create a 7-day streak for meditation (today through 6 days ago)
    for dayOffset in 0..<7 {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let entry = HabitEntry(date: noon, completed: true)
        entry.habit = meditation
        context.insert(entry)
    }

    // Exercise: 3 days this week
    for dayOffset in [0, 2, 4] {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let entry = HabitEntry(date: noon, completed: true)
        entry.habit = exercise
        context.insert(entry)
    }

    try? context.save()
}

// MARK: - Tests

@Suite("HabitsViewModel")
struct HabitsViewModelTests {

    // MARK: - Initial State

    @Test @MainActor
    func initialStateIsEmpty() {
        let vm = HabitsViewModel()

        #expect(vm.habits.isEmpty)
        #expect(vm.selectedHabitID == nil)
        #expect(vm.selectedCategory == nil)
        #expect(vm.availableCategories.isEmpty)
        #expect(vm.filteredHabits.isEmpty)
        #expect(vm.selectedHabit == nil)
    }

    // MARK: - Load Data

    @Test @MainActor
    func loadDataPopulatesHabits() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        #expect(vm.habits.count == 3)
        #expect(vm.availableCategories.sorted() == ["Fitness", "Health", "Wellness"])
    }

    @Test @MainActor
    func loadDataCalculatesStreaks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        let meditation = vm.habits.first { $0.name == "Meditation" }
        #expect(meditation != nil)
        #expect(meditation!.currentStreak == 7)
        #expect(meditation!.longestStreak == 7)
    }

    @Test @MainActor
    func loadDataCalculatesRates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        let meditation = vm.habits.first { $0.name == "Meditation" }
        #expect(meditation != nil)
        #expect(meditation!.weeklyRate == 1.0) // 7/7

        let exercise = vm.habits.first { $0.name == "Exercise" }
        #expect(exercise != nil)
        // Exercise: 3 days / 5 target per week = 0.6 (but rate calc uses 7 days = 3/5 goal-relative)
        #expect(exercise!.weeklyRate > 0)
    }

    @Test @MainActor
    func loadDataWithEmptyDatabase() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        #expect(vm.habits.isEmpty)
        #expect(vm.availableCategories.isEmpty)
    }

    // MARK: - Category Filtering

    @Test @MainActor
    func filterByCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        vm.selectedCategory = "Wellness"
        #expect(vm.filteredHabits.count == 1)
        #expect(vm.filteredHabits.first?.name == "Meditation")

        vm.selectedCategory = nil
        #expect(vm.filteredHabits.count == 3)
    }

    @Test @MainActor
    func filterByNonexistentCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        vm.selectedCategory = "Nonexistent"
        #expect(vm.filteredHabits.isEmpty)
    }

    // MARK: - CRUD

    @Test @MainActor
    func addHabit() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = HabitsViewModel()
        vm.addHabit(
            name: "Running", emoji: "🏃", category: "Fitness",
            targetFrequency: 3, isQuantitative: true, unitLabel: "km",
            to: context
        )

        #expect(vm.habits.count == 1)
        let habit = vm.habits.first!
        #expect(habit.name == "Running")
        #expect(habit.emoji == "🏃")
        #expect(habit.category == "Fitness")
        #expect(habit.targetFrequency == 3)
        #expect(habit.isQuantitative == true)
        #expect(habit.unitLabel == "km")
    }

    @Test @MainActor
    func addHabitIncrementsSortOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = HabitsViewModel()
        vm.addHabit(
            name: "First", emoji: "1️⃣", category: "General",
            targetFrequency: 7, isQuantitative: false, unitLabel: "",
            to: context
        )
        vm.addHabit(
            name: "Second", emoji: "2️⃣", category: "General",
            targetFrequency: 7, isQuantitative: false, unitLabel: "",
            to: context
        )

        #expect(vm.habits.count == 2)
        #expect(vm.habits[0].sortOrder == 0)
        #expect(vm.habits[1].sortOrder == 1)
    }

    @Test @MainActor
    func updateHabit() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = HabitsViewModel()
        vm.addHabit(
            name: "Old Name", emoji: "❌", category: "General",
            targetFrequency: 7, isQuantitative: false, unitLabel: "",
            to: context
        )

        let habitID = vm.habits.first!.id

        vm.updateHabit(
            habitID,
            name: "New Name", emoji: "✅", category: "Health",
            targetFrequency: 5, isQuantitative: true, unitLabel: "cups",
            in: context
        )

        let updated = vm.habits.first { $0.id == habitID }
        #expect(updated?.name == "New Name")
        #expect(updated?.emoji == "✅")
        #expect(updated?.category == "Health")
        #expect(updated?.targetFrequency == 5)
        #expect(updated?.isQuantitative == true)
        #expect(updated?.unitLabel == "cups")
    }

    @Test @MainActor
    func deleteHabit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)
        #expect(vm.habits.count == 3)

        let meditationID = vm.habits.first { $0.name == "Meditation" }!.id
        vm.selectedHabitID = meditationID

        vm.deleteHabit(meditationID, from: context)

        #expect(vm.habits.count == 2)
        #expect(vm.habits.contains { $0.name == "Meditation" } == false)
        #expect(vm.selectedHabitID == nil) // Deselected
    }

    @Test @MainActor
    func deleteNonSelectedHabitKeepsSelection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        let exerciseID = vm.habits.first { $0.name == "Exercise" }!.id
        let meditationID = vm.habits.first { $0.name == "Meditation" }!.id
        vm.selectedHabitID = meditationID

        vm.deleteHabit(exerciseID, from: context)

        #expect(vm.habits.count == 2)
        #expect(vm.selectedHabitID == meditationID) // Still selected
    }

    // MARK: - Reordering

    @Test @MainActor
    func moveHabitReorders() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        let firstID = vm.habits[0].id
        let lastID = vm.habits[2].id

        vm.moveHabit(from: lastID, toPositionOf: firstID)

        #expect(vm.habits[0].id == lastID)
        #expect(vm.habits.count == 3)
    }

    @Test @MainActor
    func moveHabitToSamePositionNoOp() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsWithEntries(in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        let originalOrder = vm.habits.map(\.id)
        let id = vm.habits[1].id

        vm.moveHabit(from: id, toPositionOf: id)

        #expect(vm.habits.map(\.id) == originalOrder)
    }

    // MARK: - Streak Milestones

    @Test @MainActor
    func streakMilestones() {
        #expect(HabitsViewModel.currentMilestone(for: 0) == nil)
        #expect(HabitsViewModel.currentMilestone(for: 6) == nil)
        #expect(HabitsViewModel.currentMilestone(for: 7) == 7)
        #expect(HabitsViewModel.currentMilestone(for: 15) == 7)
        #expect(HabitsViewModel.currentMilestone(for: 30) == 30)
        #expect(HabitsViewModel.currentMilestone(for: 100) == 100)
        #expect(HabitsViewModel.currentMilestone(for: 365) == 365)
        #expect(HabitsViewModel.currentMilestone(for: 500) == 365)
    }

    @Test @MainActor
    func isExactMilestone() {
        #expect(HabitsViewModel.isExactMilestone(7) == true)
        #expect(HabitsViewModel.isExactMilestone(30) == true)
        #expect(HabitsViewModel.isExactMilestone(100) == true)
        #expect(HabitsViewModel.isExactMilestone(365) == true)
        #expect(HabitsViewModel.isExactMilestone(8) == false)
        #expect(HabitsViewModel.isExactMilestone(0) == false)
    }

    // MARK: - Trend Date Range

    @Test @MainActor
    func trendDateRangeDayCounts() {
        #expect(HabitsViewModel.TrendDateRange.week.dayCount == 7)
        #expect(HabitsViewModel.TrendDateRange.month.dayCount == 30)
        #expect(HabitsViewModel.TrendDateRange.threeMonths.dayCount == 90)
        #expect(HabitsViewModel.TrendDateRange.year.dayCount == 365)
    }

    // MARK: - Rolling Average Computation

    @Test @MainActor
    func computeRollingAverageBasic() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let habitCreated = calendar.date(byAdding: .day, value: -10, to: today)!

        // Completed every day for the last 7 days
        let completedDates = Set(
            (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        )

        let dateRange = (0..<7).map {
            calendar.date(byAdding: .day, value: -6 + $0, to: today)!
        }

        let result = HabitsViewModel.computeRollingAverage(
            completedDates: completedDates,
            dateRange: dateRange,
            habitCreatedDate: habitCreated
        )

        // Last day should be 100% (7/7)
        let lastPoint = result.last!
        #expect(lastPoint.value == 100.0)
    }

    @Test @MainActor
    func computeRollingAverageExcludesPreCreationDates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let habitCreated = today // Created today

        let completedDates: Set<Date> = [today]

        let dateRange = (-3...0).map {
            calendar.date(byAdding: .day, value: $0, to: today)!
        }

        let result = HabitsViewModel.computeRollingAverage(
            completedDates: completedDates,
            dateRange: dateRange,
            habitCreatedDate: habitCreated
        )

        // Should only have 1 point (today), not the 3 pre-creation days
        #expect(result.count == 1)
        #expect(result.first?.value == 100.0)
    }

    // MARK: - Default Categories

    @Test @MainActor
    func defaultCategoriesAreComplete() {
        let categories = HabitsViewModel.defaultCategories
        #expect(categories.contains("General"))
        #expect(categories.contains("Health"))
        #expect(categories.contains("Fitness"))
        #expect(categories.contains("Mindfulness"))
        #expect(categories.count >= 5)
    }
}
