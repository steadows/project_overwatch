import Foundation
import SwiftData

@Model
final class HabitEntry {
    var id: UUID
    var date: Date
    var completed: Bool
    var value: Double?
    var notes: String
    var loggedAt: Date

    var habit: Habit?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        completed: Bool = true,
        value: Double? = nil,
        notes: String = "",
        loggedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.completed = completed
        self.value = value
        self.notes = notes
        self.loggedAt = loggedAt
    }
}
