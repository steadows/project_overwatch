import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var content: String
    var parsedHabits: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        content: String,
        parsedHabits: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.parsedHabits = parsedHabits
        self.createdAt = createdAt
    }
}
