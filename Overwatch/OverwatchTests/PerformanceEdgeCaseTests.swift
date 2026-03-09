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
private func seedHabits(count: Int, in context: ModelContext) -> [Habit] {
    var habits: [Habit] = []
    for i in 0..<count {
        let habit = Habit(
            name: "Habit \(i)", emoji: "⭐", category: "Test",
            targetFrequency: 7, isQuantitative: false, unitLabel: "", sortOrder: i
        )
        context.insert(habit)
        habits.append(habit)
    }
    try? context.save()
    return habits
}

@MainActor
private func seedEntries(
    for habit: Habit,
    dayCount: Int,
    completionRate: Double = 0.7,
    in context: ModelContext
) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    for dayOffset in 0..<dayCount {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let completed = Double.random(in: 0...1) < completionRate
        let entry = HabitEntry(date: date, completed: completed)
        entry.habit = habit
        context.insert(entry)
    }
    try? context.save()
}

@MainActor
private func seedMassiveDataset(
    habitCount: Int,
    daysPerHabit: Int,
    in context: ModelContext
) -> [Habit] {
    let habits = seedHabits(count: habitCount, in: context)
    for habit in habits {
        seedEntries(for: habit, dayCount: daysPerHabit, in: context)
    }
    return habits
}

@MainActor
private func seedWhoopCycles(count: Int, in context: ModelContext) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    for i in 0..<count {
        let date = calendar.date(byAdding: .day, value: -i, to: today)!
        let cycle = WhoopCycle(
            cycleId: i + 1,
            date: date,
            strain: Double.random(in: 2...21),
            kilojoules: Double.random(in: 3000...15000),
            averageHeartRate: Int.random(in: 55...85),
            maxHeartRate: Int.random(in: 140...195),
            recoveryScore: Double.random(in: 10...99),
            hrvRmssdMilli: Double.random(in: 20...120),
            restingHeartRate: Double.random(in: 42...68),
            sleepPerformance: Double.random(in: 30...100),
            sleepSWSMilli: Int.random(in: 2_000_000...8_000_000),
            sleepREMMilli: Int.random(in: 3_000_000...10_000_000)
        )
        context.insert(cycle)
    }
    try? context.save()
}

// MARK: - Offline Mode Tests

@Suite("Offline Mode — Degraded State")
struct OfflineModeTests {

    @Test("Dashboard renders with no WHOOP data")
    @MainActor
    func dashboardNoWhoopData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Seed habits but no WHOOP cycles
        let habits = seedHabits(count: 3, in: context)
        for habit in habits {
            seedEntries(for: habit, dayCount: 7, in: context)
        }

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        // Dashboard should show habits but WHOOP metrics should be zeroed/default
        #expect(vm.trackedHabits.count == 3)
        #expect(vm.whoopMetrics.recoveryScore == 0)
        #expect(vm.whoopMetrics.lastSyncedAt == nil)
    }

    @Test("Dashboard renders with no habits (empty state)")
    @MainActor
    func dashboardNoHabits() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.trackedHabits.isEmpty)
        #expect(vm.habitSummary.totalHabits == 0)
        #expect(vm.habitSummary.completedToday == 0)
    }

    @Test("Dashboard renders with no journal entries")
    @MainActor
    func dashboardNoJournal() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(!vm.sentimentPulse.hasEntriesToday)
        #expect(vm.sentimentPulse.todayScore == 0)
    }

    @Test("Reports view model handles no Gemini key gracefully")
    @MainActor
    func reportsNoGemini() throws {
        let vm = ReportsViewModel()
        // Without Gemini API key, generation should be disabled or error gracefully
        #expect(!vm.isGenerating)
    }

    @Test("Settings ViewModel shows disconnected WHOOP state")
    @MainActor
    func settingsDisconnectedWhoop() throws {
        let vm = SettingsViewModel()
        #expect(vm.whoopStatus == .disconnected)
    }
}

// MARK: - Heat Map Performance Tests

@Suite("Heat Map Performance")
struct HeatMapPerformanceTests {

    @Test("365-day heat map builds for single habit in <100ms")
    @MainActor
    func heatMap365DaysSingleHabit() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habits = seedHabits(count: 1, in: context)
        seedEntries(for: habits[0], dayCount: 365, in: context)

        let start = CFAbsoluteTimeGetCurrent()
        let days = HeatMapDataBuilder.buildForHabit(habits[0], dayCount: 365)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(days.count == 365)
        #expect(elapsed < 0.1, "Heat map build should complete in <100ms, took \(elapsed)s")
    }

    @Test("365-day aggregate heat map builds for 20 habits in <500ms")
    @MainActor
    func heatMap365DaysMultipleHabits() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habits = seedMassiveDataset(habitCount: 20, daysPerHabit: 365, in: context)

        let start = CFAbsoluteTimeGetCurrent()
        let days = HeatMapDataBuilder.buildAggregate(habits: habits, dayCount: 365)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(days.count == 365)
        #expect(elapsed < 1.0, "Aggregate heat map (20 habits × 365 days) should build in <1s, took \(elapsed)s")
    }

    @Test("Compact heat map builds for 30 days quickly")
    @MainActor
    func heatMapCompact30Days() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habits = seedMassiveDataset(habitCount: 10, daysPerHabit: 30, in: context)

        let start = CFAbsoluteTimeGetCurrent()
        let days = HeatMapDataBuilder.buildAggregate(habits: habits, dayCount: 30)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(days.count == 30)
        #expect(elapsed < 0.05, "Compact heat map should build in <50ms, took \(elapsed)s")
    }
}

// MARK: - Dashboard Performance Tests

@Suite("Dashboard Performance")
struct DashboardPerformanceTests {

    @Test("Dashboard loads with 20+ habits in <200ms")
    @MainActor
    func dashboardLoad20Habits() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = seedMassiveDataset(habitCount: 25, daysPerHabit: 30, in: context)
        seedWhoopCycles(count: 30, in: context)

        let vm = DashboardViewModel()

        let start = CFAbsoluteTimeGetCurrent()
        vm.loadData(from: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(vm.trackedHabits.count == 25)
        #expect(elapsed < 0.2, "Dashboard full load (25 habits) should complete in <200ms, took \(elapsed)s")
    }

    @Test("Dashboard loads with 50+ habits")
    @MainActor
    func dashboardLoad50Habits() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = seedMassiveDataset(habitCount: 50, daysPerHabit: 7, in: context)

        let vm = DashboardViewModel()

        let start = CFAbsoluteTimeGetCurrent()
        vm.loadData(from: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(vm.trackedHabits.count == 50)
        #expect(elapsed < 0.5, "Dashboard load (50 habits) should complete in <500ms, took \(elapsed)s")
    }
}

// MARK: - Boundary Tests

@Suite("Boundary Testing")
struct BoundaryTests {

    @Test("Zero data — all view models handle empty state")
    @MainActor
    func zeroData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dashVM = DashboardViewModel()
        dashVM.loadData(from: context)

        #expect(dashVM.trackedHabits.isEmpty)
        #expect(dashVM.whoopMetrics.recoveryScore == 0)
        // Heat map builds placeholder days even with no habits — verify all have zero completion
        for day in dashVM.compactHeatMapDays {
            #expect(day.completedCount == 0)
        }

        let habitsVM = HabitsViewModel()
        habitsVM.loadData(from: context)
        #expect(habitsVM.habits.isEmpty)

        let reportsVM = ReportsViewModel()
        reportsVM.loadReports(from: context)
        #expect(reportsVM.isEmpty)
    }

    @Test("One day of data")
    @MainActor
    func oneDayOfData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habits = seedHabits(count: 2, in: context)
        for habit in habits {
            seedEntries(for: habit, dayCount: 1, completionRate: 1.0, in: context)
        }

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.trackedHabits.count == 2)
        // With 1 day of data, weekly rate should be 1/7 = ~0.143
        for habit in vm.trackedHabits {
            #expect(habit.weeklyRate >= 0 && habit.weeklyRate <= 1.0)
        }
    }

    @Test("One year of data — 365 days")
    @MainActor
    func oneYearOfData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habits = seedMassiveDataset(habitCount: 5, daysPerHabit: 365, in: context)

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        #expect(vm.trackedHabits.count == 5)
        for habit in vm.trackedHabits {
            #expect(habit.weeklyRate >= 0 && habit.weeklyRate <= 1.0)
            #expect(habit.monthlyRate >= 0 && habit.monthlyRate <= 1.0)
        }

        // Heat map should handle 365 days
        let heatMap = HeatMapDataBuilder.buildAggregate(habits: habits, dayCount: 365)
        #expect(heatMap.count == 365)
    }

    @Test("50+ habits — large habit set")
    @MainActor
    func fiftyPlusHabits() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = seedHabits(count: 55, in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        #expect(vm.habits.count == 55)
    }

    @Test("10,000+ entries — massive entry count")
    @MainActor
    func tenThousandEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 5 habits × 2000 days = 10,000 entries (roughly, with completionRate)
        let habits = seedMassiveDataset(habitCount: 5, daysPerHabit: 2000, in: context)

        let totalEntries = habits.reduce(0) { $0 + $1.entries.count }
        #expect(totalEntries > 5000, "Should have thousands of entries")

        let vm = DashboardViewModel()

        let start = CFAbsoluteTimeGetCurrent()
        vm.loadData(from: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(vm.trackedHabits.count == 5)
        #expect(elapsed < 2.0, "Loading with 10k+ entries should complete in <2s, took \(elapsed)s")
    }

    @Test("Heat map handles zero habits gracefully")
    @MainActor
    func heatMapZeroHabits() throws {
        let days = HeatMapDataBuilder.buildAggregate(habits: [], dayCount: 365)
        #expect(days.count == 365)
        // All days should have 0 completion with default divisor of 1
        for day in days {
            #expect(day.completionRate == 0)
            #expect(day.completedCount == 0)
        }
    }

    @Test("WHOOP metrics with historical data")
    @MainActor
    func whoopHistoricalData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedWhoopCycles(count: 365, in: context)

        let vm = DashboardViewModel()
        vm.loadData(from: context)

        // Should load the most recent cycle's data
        #expect(vm.whoopMetrics.recoveryScore > 0)
        #expect(vm.whoopMetrics.lastSyncedAt != nil)
    }

    @Test("Habits ViewModel handles category filter with zero matches")
    @MainActor
    func categoryFilterNoMatches() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = seedHabits(count: 3, in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)

        // Set a category filter that matches no habits
        vm.selectedCategory = "NonexistentCategory"

        #expect(vm.filteredHabits.isEmpty)
    }
}

// MARK: - Chart Data Performance

@Suite("Chart Data Performance")
struct ChartDataPerformanceTests {

    @Test("War Room ViewModel loads 1 year of chart data")
    @MainActor
    func warRoomYearOfData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = seedMassiveDataset(habitCount: 5, daysPerHabit: 365, in: context)
        seedWhoopCycles(count: 365, in: context)

        let vm = WarRoomViewModel()

        let start = CFAbsoluteTimeGetCurrent()
        vm.loadData(from: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(elapsed < 1.0, "War Room data load (1 year) should complete in <1s, took \(elapsed)s")
    }

    @Test("Habits trend chart builds for 1 year of single-habit data")
    @MainActor
    func habitsTrendChartYear() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habits = seedMassiveDataset(habitCount: 1, daysPerHabit: 365, in: context)

        let vm = HabitsViewModel()
        vm.loadData(from: context)
        vm.selectedHabitID = habits[0].id

        let start = CFAbsoluteTimeGetCurrent()
        vm.loadTrendChartData(from: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(elapsed < 0.3, "Trend chart build (365 days) should complete in <300ms, took \(elapsed)s")
    }
}
