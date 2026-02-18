import Testing
import SwiftData
@testable import Overwatch

/// Tests for Habit, HabitEntry, and JournalEntry SwiftData models (Plan 2.1.3)

// MARK: - Test Helpers

@MainActor
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Habit.self, HabitEntry.self, JournalEntry.self,
        configurations: config
    )
}

// MARK: - Habit Creation & Defaults

@Suite("Habit Model")
struct HabitModelTests {

    @Test @MainActor
    func habitCreationWithDefaults() throws {
        let habit = Habit(name: "Hydration")

        #expect(habit.name == "Hydration")
        #expect(habit.emoji == "")
        #expect(habit.category == "General")
        #expect(habit.targetFrequency == 7)
        #expect(habit.entries.isEmpty)
    }

    @Test @MainActor
    func habitCreationWithCustomValues() throws {
        let habit = Habit(
            name: "Meditation",
            emoji: "🧘",
            category: "Mind",
            targetFrequency: 5
        )

        #expect(habit.name == "Meditation")
        #expect(habit.emoji == "🧘")
        #expect(habit.category == "Mind")
        #expect(habit.targetFrequency == 5)
    }

    // MARK: - Habit ↔ HabitEntry Relationship

    @Test @MainActor
    func habitEntryRelationship() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habit = Habit(name: "Exercise")
        context.insert(habit)

        let entry1 = HabitEntry(completed: true)
        let entry2 = HabitEntry(completed: false, notes: "Skipped — travel day")
        entry1.habit = habit
        entry2.habit = habit

        try context.save()

        #expect(habit.entries.count == 2)
    }

    @Test @MainActor
    func habitDeleteCascadesEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let habit = Habit(name: "Reading")
        context.insert(habit)

        let entry = HabitEntry(completed: true, value: 30, notes: "30 min")
        entry.habit = habit
        try context.save()

        #expect(habit.entries.count == 1)

        // Delete the habit — entries should cascade
        context.delete(habit)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<HabitEntry>())
        #expect(remaining.isEmpty)
    }
}

// MARK: - HabitEntry

@Suite("HabitEntry Model")
struct HabitEntryModelTests {

    @Test @MainActor
    func entryDefaults() throws {
        let entry = HabitEntry()

        #expect(entry.completed == true)
        #expect(entry.value == nil)
        #expect(entry.notes == "")
    }

    @Test @MainActor
    func entryWithQuantitativeValue() throws {
        let entry = HabitEntry(completed: true, value: 3.0, notes: "3L water")

        #expect(entry.value == 3.0)
        #expect(entry.notes == "3L water")
    }
}

// MARK: - JournalEntry

@Suite("JournalEntry Model")
struct JournalEntryModelTests {

    @Test @MainActor
    func journalEntryCreation() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let entry = JournalEntry(
            content: "Drank 3L water, meditated 20 min, no alcohol",
            parsedHabits: ["Hydration", "Meditation", "No Alcohol"]
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<JournalEntry>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.parsedHabits.count == 3)
        #expect(fetched.first?.content.contains("water") == true)
    }
}
