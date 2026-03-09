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
private func seedDataForExport(in context: ModelContext) {
    let habit = Habit(
        name: "Exercise", emoji: "🏋️", category: "Fitness",
        targetFrequency: 5, isQuantitative: false, unitLabel: "", sortOrder: 0
    )
    context.insert(habit)

    let entry = HabitEntry(date: .now, completed: true, value: nil, notes: "Morning workout")
    entry.habit = habit
    context.insert(entry)

    let journal = JournalEntry(
        content: "Good day!",
        parsedHabits: ["Exercise"],
        sentimentScore: 0.5,
        sentimentLabel: "positive",
        sentimentMagnitude: 0.5,
        title: "Day 1",
        wordCount: 2,
        tags: ["mood"]
    )
    context.insert(journal)

    let cycle = WhoopCycle(
        cycleId: 1, date: .now,
        strain: 12.0, kilojoules: 8000,
        averageHeartRate: 70, maxHeartRate: 175,
        recoveryScore: 85.0, hrvRmssdMilli: 65.0,
        restingHeartRate: 52.0, sleepPerformance: 88.0,
        sleepSWSMilli: 5400000, sleepREMMilli: 7200000
    )
    context.insert(cycle)

    try? context.save()
}

// MARK: - Tests

@Suite("SettingsViewModel")
struct SettingsViewModelTests {

    // MARK: - Initial State

    @Test @MainActor
    func initialDefaults() {
        let vm = SettingsViewModel()

        #expect(vm.isConnectingWhoop == false)
        #expect(vm.whoopError == nil)
        #expect(vm.geminiTestStatus == .idle)
        #expect(vm.showPurgeConfirmation == false)
        #expect(vm.purgeConfirmText == "")
        #expect(vm.accentColor == .cyan)
    }

    // MARK: - Connection Status

    @Test @MainActor
    func whoopDisconnectedByDefault() {
        // Clean up tokens first
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopAccessToken)

        let vm = SettingsViewModel()
        #expect(vm.whoopStatus == .disconnected)
    }

    @Test @MainActor
    func markWhoopConnected() {
        let vm = SettingsViewModel()
        vm.whoopError = "Some error"

        vm.markWhoopConnected()

        #expect(vm.whoopStatus == .linked)
        #expect(vm.whoopError == nil)
    }

    @Test @MainActor
    func disconnectWhoop() {
        // Store a fake token
        KeychainHelper.save(key: KeychainHelper.Keys.whoopAccessToken, string: "fake")

        let vm = SettingsViewModel()
        vm.whoopStatus = .linked

        vm.disconnectWhoop()

        #expect(vm.whoopStatus == .disconnected)
        #expect(vm.lastSyncDisplay == "NEVER")
        #expect(KeychainHelper.readString(key: KeychainHelper.Keys.whoopAccessToken) == nil)
    }

    // MARK: - Category Management

    @Test @MainActor
    func addCategory() {
        let vm = SettingsViewModel()
        let initialCount = vm.categories.count

        vm.newCategoryName = "Custom Category"
        vm.addCategory()

        #expect(vm.categories.count == initialCount + 1)
        #expect(vm.categories.contains("Custom Category"))
        #expect(vm.newCategoryName == "") // Cleared after add

        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "settings_customCategories")
    }

    @Test @MainActor
    func addDuplicateCategoryIgnored() {
        let vm = SettingsViewModel()
        let existing = vm.categories.first!

        vm.newCategoryName = existing
        let countBefore = vm.categories.count
        vm.addCategory()

        #expect(vm.categories.count == countBefore)
    }

    @Test @MainActor
    func addEmptyCategoryIgnored() {
        let vm = SettingsViewModel()
        let countBefore = vm.categories.count

        vm.newCategoryName = "   "
        vm.addCategory()

        #expect(vm.categories.count == countBefore)
    }

    @Test @MainActor
    func deleteCategory() {
        let vm = SettingsViewModel()
        let initialCount = vm.categories.count
        let toDelete = vm.categories.first!

        vm.deleteCategory(toDelete)

        #expect(vm.categories.count == initialCount - 1)
        #expect(!vm.categories.contains(toDelete))

        // Clean up
        UserDefaults.standard.removeObject(forKey: "settings_customCategories")
    }

    @Test @MainActor
    func resetCategoriesToDefault() {
        let vm = SettingsViewModel()
        vm.categories = ["Only One"]

        vm.resetCategoriesToDefault()

        #expect(vm.categories == HabitsViewModel.defaultCategories)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "settings_customCategories")
    }

    // MARK: - Data Export

    @Test @MainActor
    func buildAllDataJSON() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedDataForExport(in: context)

        let vm = SettingsViewModel()
        let data = try #require(vm.buildAllDataJSON(from: context))

        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? String == "1.0")
        #expect((json["habits"] as? [[String: Any]])?.count == 1)
        #expect((json["habitEntries"] as? [[String: Any]])?.count == 1)
        #expect((json["journalEntries"] as? [[String: Any]])?.count == 1)
        #expect((json["whoopCycles"] as? [[String: Any]])?.count == 1)
    }

    @Test @MainActor
    func buildAllDataJSONEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = SettingsViewModel()
        let data = try #require(vm.buildAllDataJSON(from: context))

        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((json["habits"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test @MainActor
    func buildHabitsCSV() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedDataForExport(in: context)

        let vm = SettingsViewModel()
        let data = try #require(vm.buildHabitsCSV(from: context))
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv.hasPrefix("Date,Habit,Emoji,Category,Completed,Value,Unit,Notes\n"))
        #expect(csv.contains("Exercise"))
        #expect(csv.contains("Yes"))
    }

    @Test @MainActor
    func buildHabitsCSVEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = SettingsViewModel()
        let data = try #require(vm.buildHabitsCSV(from: context))
        let csv = try #require(String(data: data, encoding: .utf8))

        // Should only have the header
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
    }

    // MARK: - Purge

    @Test @MainActor
    func purgeAllData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedDataForExport(in: context)

        let vm = SettingsViewModel()
        vm.showPurgeConfirmation = true
        vm.purgeConfirmText = "PURGE"

        vm.purgeAllData(from: context)

        let habits = try context.fetch(FetchDescriptor<Habit>())
        let cycles = try context.fetch(FetchDescriptor<WhoopCycle>())
        let journals = try context.fetch(FetchDescriptor<JournalEntry>())

        #expect(habits.isEmpty)
        #expect(cycles.isEmpty)
        #expect(journals.isEmpty)
        #expect(vm.showPurgeConfirmation == false)
        #expect(vm.purgeConfirmText == "")
    }

    // MARK: - Helpers

    @Test @MainActor
    func dayNames() {
        let vm = SettingsViewModel()
        #expect(vm.dayName(for: 1) == "Sunday")
        #expect(vm.dayName(for: 7) == "Saturday")
        #expect(vm.dayName(for: 0) == "Sunday") // Out of range fallback
        #expect(vm.dayName(for: 8) == "Sunday") // Out of range fallback
    }

    @Test @MainActor
    func formatTime() {
        let vm = SettingsViewModel()
        #expect(vm.formatTime(hour: 8, minute: 0) == "08:00")
        #expect(vm.formatTime(hour: 14, minute: 30) == "14:30")
        #expect(vm.formatTime(hour: 0, minute: 5) == "00:05")
    }

    // MARK: - Accent Colors

    @Test @MainActor
    func accentColorCases() {
        let cases = SettingsViewModel.AccentColorChoice.allCases
        #expect(cases.count == 6)
        #expect(cases.contains(.cyan))
        #expect(cases.contains(.green))
        #expect(cases.contains(.amber))
        #expect(cases.contains(.red))
        #expect(cases.contains(.purple))
        #expect(cases.contains(.white))
    }

    // MARK: - TestStatus Equatable

    @Test @MainActor
    func testStatusEquality() {
        #expect(SettingsViewModel.TestStatus.idle == .idle)
        #expect(SettingsViewModel.TestStatus.testing == .testing)
        #expect(SettingsViewModel.TestStatus.success == .success)
        #expect(SettingsViewModel.TestStatus.failed("a") == .failed("a"))
        #expect(SettingsViewModel.TestStatus.idle != .testing)
    }
}
