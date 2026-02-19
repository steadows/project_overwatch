import Foundation
import Observation
import SwiftData

/// ViewModel for the Journal Timeline — browsable, filterable log of all habit entries.
@MainActor
@Observable
final class JournalTimelineViewModel {

    // MARK: - Display Types

    struct EntryItem: Identifiable, Equatable {
        let id: UUID
        let habitID: UUID
        let habitName: String
        let habitEmoji: String
        let habitCategory: String
        let date: Date
        let loggedAt: Date
        let completed: Bool
        let isQuantitative: Bool
        let unitLabel: String
        var value: Double?
        var notes: String
    }

    // MARK: - Date Range Presets

    enum DateRangeFilter: String, CaseIterable, Equatable {
        case today = "TODAY"
        case week = "7 DAYS"
        case month = "30 DAYS"
        case all = "ALL"
    }

    struct HabitFilterOption: Identifiable, Equatable {
        let id: UUID
        let name: String
        let emoji: String
    }

    // MARK: - State

    var entries: [EntryItem] = []
    var availableHabits: [HabitFilterOption] = []
    var availableCategories: [String] = []

    /// Filter: selected habit ID (nil = all habits)
    var selectedHabitID: UUID?
    /// Filter: date range preset
    var dateRangeFilter: DateRangeFilter = .week
    /// Filter: selected category (nil = all categories)
    var selectedCategory: String?

    /// Inline editing: currently expanded entry ID
    var expandedEntryID: UUID?
    /// Inline editing: value being edited
    var editValue: String = ""
    /// Inline editing: notes being edited
    var editNotes: String = ""

    /// Confirmation state for delete
    var entryToDelete: EntryItem?
    var showingDeleteAlert = false

    // MARK: - Computed

    var filteredEntries: [EntryItem] {
        var result = entries

        if let habitID = selectedHabitID {
            result = result.filter { $0.habitID == habitID }
        }

        if let category = selectedCategory {
            result = result.filter { $0.habitCategory == category }
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)

        switch dateRangeFilter {
        case .today:
            result = result.filter { $0.date >= todayStart }
        case .week:
            let weekStart = calendar.date(byAdding: .day, value: -7, to: todayStart)!
            result = result.filter { $0.date >= weekStart }
        case .month:
            let monthStart = calendar.date(byAdding: .day, value: -30, to: todayStart)!
            result = result.filter { $0.date >= monthStart }
        case .all:
            break
        }

        return result
    }

    var entryCount: Int { filteredEntries.count }

    // MARK: - Data Loading

    func loadEntries(from context: ModelContext) {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        guard let allHabits = try? context.fetch(descriptor) else {
            entries = []
            availableHabits = []
            availableCategories = []
            return
        }

        // Build habit filter options
        availableHabits = allHabits.map { habit in
            HabitFilterOption(id: habit.id, name: habit.name, emoji: habit.emoji)
        }
        availableCategories = Array(Set(allHabits.map(\.category))).sorted()

        // Flatten all entries with parent habit context
        var allEntries: [EntryItem] = []
        for habit in allHabits {
            for entry in habit.entries {
                allEntries.append(EntryItem(
                    id: entry.id,
                    habitID: habit.id,
                    habitName: habit.name,
                    habitEmoji: habit.emoji,
                    habitCategory: habit.category,
                    date: entry.date,
                    loggedAt: entry.loggedAt,
                    completed: entry.completed,
                    isQuantitative: habit.isQuantitative,
                    unitLabel: habit.unitLabel,
                    value: entry.value,
                    notes: entry.notes
                ))
            }
        }

        // Sort newest first
        entries = allEntries.sorted { $0.loggedAt > $1.loggedAt }
    }

    // MARK: - Expand / Edit

    func toggleExpand(_ entryID: UUID) {
        if expandedEntryID == entryID {
            expandedEntryID = nil
            editValue = ""
            editNotes = ""
        } else {
            expandedEntryID = entryID
            if let entry = entries.first(where: { $0.id == entryID }) {
                editValue = entry.value.map { String(format: "%g", $0) } ?? ""
                editNotes = entry.notes
            }
        }
    }

    func saveEdit(in context: ModelContext) {
        guard let entryID = expandedEntryID else { return }

        let descriptor = FetchDescriptor<HabitEntry>()
        guard let allEntries = try? context.fetch(descriptor),
              let entry = allEntries.first(where: { $0.id == entryID }) else { return }

        entry.value = Double(editValue)
        entry.notes = editNotes.trimmingCharacters(in: .whitespaces)

        expandedEntryID = nil
        editValue = ""
        editNotes = ""
        loadEntries(from: context)
    }

    // MARK: - Delete

    func confirmDelete(_ entry: EntryItem) {
        entryToDelete = entry
        showingDeleteAlert = true
    }

    func deleteEntry(in context: ModelContext) {
        guard let target = entryToDelete else { return }

        let descriptor = FetchDescriptor<HabitEntry>()
        guard let allEntries = try? context.fetch(descriptor),
              let entry = allEntries.first(where: { $0.id == target.id }) else { return }

        context.delete(entry)
        entryToDelete = nil

        if expandedEntryID == target.id {
            expandedEntryID = nil
            editValue = ""
            editNotes = ""
        }

        loadEntries(from: context)
    }

    // MARK: - Filter Helpers

    func clearFilters() {
        selectedHabitID = nil
        selectedCategory = nil
        dateRangeFilter = .week
    }

    var hasActiveFilters: Bool {
        selectedHabitID != nil || selectedCategory != nil || dateRangeFilter != .week
    }
}
