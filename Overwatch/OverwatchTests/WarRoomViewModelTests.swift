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
private func seedFullData(in context: ModelContext) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    // Habits + entries
    let meditation = Habit(
        name: "Meditation", emoji: "🧘", category: "Wellness",
        targetFrequency: 7, isQuantitative: false, unitLabel: "", sortOrder: 0,
        createdAt: calendar.date(byAdding: .day, value: -30, to: today)!
    )
    context.insert(meditation)

    for dayOffset in 0..<14 {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let entry = HabitEntry(date: noon, completed: dayOffset % 2 == 0)
        entry.habit = meditation
        context.insert(entry)
    }

    // WHOOP cycles
    for dayOffset in 0..<14 {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let cycle = WhoopCycle(
            cycleId: 100 + dayOffset,
            date: date,
            strain: 10.0 + Double(dayOffset % 5),
            kilojoules: 2000,
            averageHeartRate: 70,
            maxHeartRate: 150,
            recoveryScore: 60.0 + Double(dayOffset) * 2,
            hrvRmssdMilli: 50.0,
            restingHeartRate: 55.0,
            sleepPerformance: 80.0,
            sleepSWSMilli: 3600000 + dayOffset * 100000,
            sleepREMMilli: 5400000 + dayOffset * 100000
        )
        context.insert(cycle)
    }

    // Journal entries with sentiment
    for dayOffset in 0..<14 {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let sentiment = dayOffset % 3 == 0 ? 0.5 : (dayOffset % 3 == 1 ? -0.3 : 0.1)
        let entry = JournalEntry(
            content: "Day \(dayOffset) entry",
            sentimentScore: sentiment,
            sentimentLabel: sentiment > 0.1 ? "positive" : (sentiment < -0.1 ? "negative" : "neutral"),
            sentimentMagnitude: abs(sentiment),
            title: "Day \(dayOffset)",
            wordCount: 5,
            tags: []
        )
        entry.date = noon
        context.insert(entry)
    }

    // Weekly insight
    let insight = WeeklyInsight(
        dateRangeStart: calendar.date(byAdding: .day, value: -7, to: today)!,
        dateRangeEnd: today,
        summary: "Test insight summary",
        forceMultiplierHabit: "Meditation",
        recommendations: ["Keep meditating"],
        averageSentiment: 0.3,
        sentimentTrend: "improving"
    )
    context.insert(insight)

    try? context.save()
}

// MARK: - Tests

@Suite("WarRoomViewModel")
struct WarRoomViewModelTests {

    // MARK: - Initial State

    @Test @MainActor
    func initialState() {
        let vm = WarRoomViewModel()

        #expect(vm.selectedDateRange == .month)
        #expect(vm.selectedChartType == .recovery)
        #expect(vm.latestInsight == nil)
        #expect(vm.isRefreshing == false)
        #expect(vm.refreshProgress == nil)
        #expect(vm.recoveryData.isEmpty)
        #expect(vm.habitDayData.isEmpty)
        #expect(vm.correlationData.isEmpty)
        #expect(vm.sleepData.isEmpty)
        #expect(vm.sentimentData.isEmpty)
        #expect(vm.habitSentimentData.isEmpty)
        #expect(vm.hasData == false)
        #expect(vm.hasWhoopData == false)
        #expect(vm.isThrottled == false)
    }

    // MARK: - Date Range

    @Test @MainActor
    func dateRangeDayCounts() {
        #expect(WarRoomViewModel.DateRange.week.dayCount == 7)
        #expect(WarRoomViewModel.DateRange.month.dayCount == 30)
        #expect(WarRoomViewModel.DateRange.quarter.dayCount == 90)
        #expect(WarRoomViewModel.DateRange.year.dayCount == 365)
        #expect(WarRoomViewModel.DateRange.all.dayCount == nil)
    }

    // MARK: - Chart Type Icons

    @Test @MainActor
    func chartTypeIcons() {
        #expect(!WarRoomViewModel.ChartType.recovery.icon.isEmpty)
        #expect(!WarRoomViewModel.ChartType.habits.icon.isEmpty)
        #expect(!WarRoomViewModel.ChartType.correlation.icon.isEmpty)
        #expect(!WarRoomViewModel.ChartType.sleep.icon.isEmpty)
        #expect(!WarRoomViewModel.ChartType.sentiment.icon.isEmpty)
        #expect(!WarRoomViewModel.ChartType.habitSentiment.icon.isEmpty)
    }

    // MARK: - Load Data

    @Test @MainActor
    func loadDataPopulatesRecoveryData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        #expect(!vm.recoveryData.isEmpty)
        #expect(vm.hasWhoopData == true)
        #expect(vm.hasData == true)
    }

    @Test @MainActor
    func loadDataPopulatesSleepData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        #expect(!vm.sleepData.isEmpty)
        // Sleep data should have SWS and REM values
        let firstSleep = vm.sleepData.first!
        #expect(firstSleep.swsHours > 0)
        #expect(firstSleep.remHours > 0)
        #expect(firstSleep.totalHours == firstSleep.swsHours + firstSleep.remHours)
    }

    @Test @MainActor
    func loadDataPopulatesSentimentData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        #expect(!vm.sentimentData.isEmpty)
        #expect(!vm.gaugeData.isEmpty)
    }

    @Test @MainActor
    func loadDataPopulatesCorrelationData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        #expect(!vm.correlationData.isEmpty)
        let meditation = vm.correlationData.first { $0.habitName == "Meditation" }
        #expect(meditation != nil)
        #expect(meditation!.completionPercent > 0)
        #expect(meditation!.recoveryAvg > 0)
    }

    @Test @MainActor
    func loadDataPopulatesHabitSentimentData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        #expect(!vm.habitSentimentData.isEmpty)
        let meditation = vm.habitSentimentData.first { $0.habitName == "Meditation" }
        #expect(meditation != nil)
        #expect(meditation!.completionPercent > 0)
    }

    @Test @MainActor
    func loadDataPopulatesLatestInsight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        #expect(vm.latestInsight != nil)
        #expect(vm.latestInsight?.summary == "Test insight summary")
        #expect(vm.latestInsight?.forceMultiplierHabit == "Meditation")
    }

    @Test @MainActor
    func loadDataWithEmptyDatabase() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        #expect(vm.recoveryData.isEmpty)
        #expect(vm.habitDayData.isEmpty)
        #expect(vm.correlationData.isEmpty)
        #expect(vm.sleepData.isEmpty)
        #expect(vm.sentimentData.isEmpty)
        #expect(vm.latestInsight == nil)
        #expect(vm.hasData == false)
        #expect(vm.hasWhoopData == false)
    }

    // MARK: - Date Range Filtering

    @Test @MainActor
    func weekRangeFiltersData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.selectedDateRange = .week
        vm.loadData(from: context)

        // Week range should have fewer recovery points than month
        let weekCount = vm.recoveryData.count

        vm.selectedDateRange = .month
        vm.loadData(from: context)
        let monthCount = vm.recoveryData.count

        #expect(weekCount <= monthCount)
    }

    // MARK: - Habit Day Data

    @Test @MainActor
    func habitDayDataContainsCompletedDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        #expect(!vm.habitDayData.isEmpty)
        // All habit day points should be completed
        for point in vm.habitDayData {
            #expect(point.completed == true)
        }
    }

    // MARK: - Habit Completion Overlay

    @Test @MainActor
    func habitCompletionOverlaySorted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFullData(in: context)

        let vm = WarRoomViewModel()
        vm.loadData(from: context)

        // Overlay should be sorted by date
        for i in 1..<vm.habitCompletionOverlay.count {
            #expect(vm.habitCompletionOverlay[i].date >= vm.habitCompletionOverlay[i - 1].date)
        }
    }
}
