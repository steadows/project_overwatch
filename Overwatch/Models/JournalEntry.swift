import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var content: String
    var parsedHabits: [String]
    var createdAt: Date

    // Phase 6.5 — Sentiment & Journal properties
    var sentimentScore: Double
    var sentimentLabel: String
    var sentimentMagnitude: Double
    var title: String
    var wordCount: Int
    var tags: [String]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        content: String,
        parsedHabits: [String] = [],
        createdAt: Date = .now,
        sentimentScore: Double = 0.0,
        sentimentLabel: String = "neutral",
        sentimentMagnitude: Double = 0.0,
        title: String = "",
        wordCount: Int = 0,
        tags: [String] = [],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.parsedHabits = parsedHabits
        self.createdAt = createdAt
        self.sentimentScore = sentimentScore
        self.sentimentLabel = sentimentLabel
        self.sentimentMagnitude = sentimentMagnitude
        self.title = title
        self.wordCount = wordCount
        self.tags = tags
        self.updatedAt = updatedAt
    }
}
