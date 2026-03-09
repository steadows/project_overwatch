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
private func seedHabitsAndEntries(in context: ModelContext) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let meditation = Habit(
        name: "Meditation", emoji: "🧘", category: "Wellness",
        targetFrequency: 7, isQuantitative: false, unitLabel: "", sortOrder: 0
    )
    let exercise = Habit(
        name: "Exercise", emoji: "🏋️", category: "Fitness",
        targetFrequency: 5, isQuantitative: false, unitLabel: "", sortOrder: 1
    )
    let water = Habit(
        name: "Water", emoji: "💧", category: "Health",
        targetFrequency: 7, isQuantitative: true, unitLabel: "L", sortOrder: 2
    )
    context.insert(meditation)
    context.insert(exercise)
    context.insert(water)

    // Today's entries
    let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)!
    let medEntry = HabitEntry(date: todayNoon, completed: true)
    medEntry.habit = meditation
    context.insert(medEntry)

    let waterEntry = HabitEntry(date: todayNoon, completed: true, value: 3.0, notes: "3L")
    waterEntry.habit = water
    context.insert(waterEntry)

    // Yesterday's entries
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let yesterdayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: yesterday)!

    let medYesterday = HabitEntry(date: yesterdayNoon, completed: true)
    medYesterday.habit = meditation
    context.insert(medYesterday)

    let exYesterday = HabitEntry(date: yesterdayNoon, completed: true)
    exYesterday.habit = exercise
    context.insert(exYesterday)

    try? context.save()
}

@MainActor
private func seedWhoopCycle(in context: ModelContext) {
    let cycle = WhoopCycle(
        cycleId: 1,
        date: .now,
        strain: 12.5,
        kilojoules: 8000,
        averageHeartRate: 70,
        maxHeartRate: 175,
        recoveryScore: 85.0,
        hrvRmssdMilli: 65.0,
        restingHeartRate: 52.0,
        sleepPerformance: 88.0,
        sleepSWSMilli: 5400000,
        sleepREMMilli: 7200000
    )
    context.insert(cycle)
    try? context.save()
}

// MARK: - Tests

@Suite("DashboardViewModel")
struct DashboardViewModelTests {

    // MARK: - Initial State

    @Test @MainActor
    func initialStateIsEmpty() {
        let vm = DashboardViewModel()

        #expect(vm.whoopMetrics == .empty)
        #expect(vm.syncStatus == .idle)
        #expect(vm.whoopError == nil)
        #expect(vm.hasWhoopError == false)
        #expect(vm.habitSummary == .empty)
        #expect(vm.trackedHabits.isEmpty)
        #expect(vm.compactHeatMapDays.isEmpty)
        #expect(vm.sentimentPulse == .empty)
        #expect(vm.isViewingToday == true)
        #expect(vm.selectedDateLabel == "TODAY")
        #expect(vm.expandedHabitID == nil)
        #expect(vm.isWhoopExpanded == false)
        #expect(vm.hasWhoopData == false)
    }

    // MARK: - Load Data

    @Test @MainActor
    func loadDataPopulatesHabitSummary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsAndEntries(in: context)

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.habitSummary.totalHabits == 3)
        #expect(vm.habitSummary.completedToday == 2) // Meditation + Water
    }

    @Test @MainActor
    func loadDataPopulatesTrackedHabits() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsAndEntries(in: context)

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.trackedHabits.count == 3)

        let meditation = vm.trackedHabits.first { $0.name == "Meditation" }
        #expect(meditation != nil)
        #expect(meditation?.completedToday == true)

        let exercise = vm.trackedHabits.first { $0.name == "Exercise" }
        #expect(exercise != nil)
        #expect(exercise?.completedToday == false) // Not completed today
    }

    @Test @MainActor
    func loadDataPopulatesWhoopMetrics() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedWhoopCycle(in: context)

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.whoopMetrics.recoveryScore == 85.0)
        #expect(vm.whoopMetrics.strain == 12.5)
        #expect(vm.whoopMetrics.sleepPerformance == 88.0)
        #expect(vm.whoopMetrics.restingHeartRate == 52.0)
        #expect(vm.whoopMetrics.hrvRmssd == 65.0)
        #expect(vm.whoopMetrics.lastSyncedAt != nil)
        #expect(vm.hasWhoopData == true)
    }

    @Test @MainActor
    func loadDataWithNoWhoopCycles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHabitsAndEntries(in: context)

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.whoopMetrics == .empty)
        #expect(vm.hasWhoopData == false)
    }

    @Test @MainActor
    func loadDataWithEmptyDatabase() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.habitSummary.totalHabits == 0)
        #expect(vm.habitSummary.completedToday == 0)
        #expect(vm.habitSummary.completionRate == 0)
        #expect(vm.trackedHabits.isEmpty)
        // Heat map builder may return zero-completion days even with no habits
        // The key invariant: no habit data means all rates are 0
        for day in vm.compactHeatMapDays {
            #expect(day.completionRate == 0.0)
        }
    }

    // MARK: - Habit Actions

    @Test @MainActor
    func toggleHabitCompletion() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habit = Habit(name: "TestHabit", emoji: "✅", sortOrder: 0)
        context.insert(habit)
        try context.save()

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.trackedHabits.first?.completedToday == false)

        // Toggle on
        vm.toggleHabitCompletion(habit.id, in: context)
        #expect(vm.trackedHabits.first?.completedToday == true)

        // Toggle off
        vm.toggleHabitCompletion(habit.id, in: context)
        #expect(vm.trackedHabits.first?.completedToday == false)
    }

    @Test @MainActor
    func confirmHabitEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habit = Habit(
            name: "Water", emoji: "💧",
            isQuantitative: true, unitLabel: "L", sortOrder: 0
        )
        context.insert(habit)
        try context.save()

        let vm = DashboardViewModel()
        vm.expandedHabitID = habit.id

        vm.confirmHabitEntry(habit.id, value: 3.0, notes: "3 liters", in: context)

        #expect(vm.trackedHabits.first?.completedToday == true)
        #expect(vm.expandedHabitID == nil) // Collapses after confirm

        // Verify the entry was created with correct values
        let entries = try context.fetch(FetchDescriptor<HabitEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.value == 3.0)
        #expect(entries.first?.notes == "3 liters")
    }

    @Test @MainActor
    func addHabit() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = DashboardViewModel()
        vm.addHabit(name: "Running", emoji: "🏃", to: context)

        #expect(vm.trackedHabits.count == 1)
        #expect(vm.trackedHabits.first?.name == "Running")
        #expect(vm.trackedHabits.first?.emoji == "🏃")
    }

    // MARK: - Date Navigation

    @Test @MainActor
    func navigateDateBackward() {
        let vm = DashboardViewModel()
        let originalDate = vm.selectedDate

        vm.navigateDate(by: -1)

        let calendar = Calendar.current
        let expectedDate = calendar.date(byAdding: .day, value: -1, to: originalDate)!
        #expect(calendar.isDate(vm.selectedDate, inSameDayAs: expectedDate))
        #expect(vm.isViewingToday == false)
    }

    @Test @MainActor
    func navigateDateDoesNotGoToFuture() {
        let vm = DashboardViewModel()
        vm.navigateDate(by: 1)

        // Should still be today — can't navigate into the future
        #expect(vm.isViewingToday == true)
    }

    @Test @MainActor
    func goToTodaySnapsBack() {
        let vm = DashboardViewModel()
        vm.navigateDate(by: -5)
        #expect(vm.isViewingToday == false)

        vm.goToToday()
        #expect(vm.isViewingToday == true)
        #expect(vm.selectedDateLabel == "TODAY")
    }

    @Test @MainActor
    func pastDateShowsFormattedLabel() {
        let vm = DashboardViewModel()
        vm.navigateDate(by: -3)

        #expect(vm.selectedDateLabel != "TODAY")
        // Should be uppercased format like "MAR 6, 2026"
        #expect(vm.selectedDateLabel == vm.selectedDateLabel.uppercased())
    }

    // MARK: - Expand/Collapse

    @Test @MainActor
    func toggleExpandedHabit() {
        let vm = DashboardViewModel()
        let habitID = UUID()

        vm.toggleExpandedHabit(habitID)
        #expect(vm.expandedHabitID == habitID)

        vm.toggleExpandedHabit(habitID)
        #expect(vm.expandedHabitID == nil)
    }

    @Test @MainActor
    func expandDifferentHabitCollapsesOld() {
        let vm = DashboardViewModel()
        let id1 = UUID()
        let id2 = UUID()

        vm.toggleExpandedHabit(id1)
        #expect(vm.expandedHabitID == id1)

        vm.toggleExpandedHabit(id2)
        #expect(vm.expandedHabitID == id2)
    }

    // MARK: - Computed Properties

    @Test @MainActor
    func habitSummaryCompletionRate() {
        let vm = DashboardViewModel()
        vm.habitSummary = DashboardViewModel.HabitSummary(
            totalHabits: 5, completedToday: 3, currentStreak: 0
        )

        #expect(vm.habitSummary.completionRate == 0.6)
    }

    @Test @MainActor
    func habitSummaryCompletionRateZeroHabits() {
        let vm = DashboardViewModel()
        vm.habitSummary = DashboardViewModel.HabitSummary(
            totalHabits: 0, completedToday: 0, currentStreak: 0
        )

        #expect(vm.habitSummary.completionRate == 0)
    }

    @Test @MainActor
    func whoopErrorState() {
        let vm = DashboardViewModel()
        #expect(vm.hasWhoopError == false)

        vm.whoopError = "BIOMETRIC SIGNAL LOST"
        #expect(vm.hasWhoopError == true)

        vm.whoopError = nil
        #expect(vm.hasWhoopError == false)
    }

    // MARK: - Sentiment Pulse

    @Test @MainActor
    func loadSentimentPulseWithJournalEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: todayStart)!

        let entry = JournalEntry(
            content: "Great day!",
            sentimentScore: 0.7,
            sentimentLabel: "positive",
            sentimentMagnitude: 0.7,
            title: "Good Day",
            wordCount: 2,
            tags: []
        )
        entry.date = todayNoon
        context.insert(entry)
        try context.save()

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.sentimentPulse.hasEntriesToday == true)
        #expect(vm.sentimentPulse.todayScore == 0.7)
        #expect(vm.sentimentPulse.todayLabel == "positive")
        #expect(vm.sentimentPulse.sparklineData.count == 7)
    }

    @Test @MainActor
    func loadSentimentPulseEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.sentimentPulse.hasEntriesToday == false)
        #expect(vm.sentimentPulse.todayScore == 0)
        #expect(vm.sentimentPulse.todayLabel == "neutral")
    }
}
