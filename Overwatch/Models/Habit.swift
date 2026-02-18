import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID
    var name: String
    var emoji: String
    var category: String
    var targetFrequency: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry]

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "",
        category: String = "General",
        targetFrequency: Int = 7,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.targetFrequency = targetFrequency
        self.createdAt = createdAt
        self.entries = []
    }
}
