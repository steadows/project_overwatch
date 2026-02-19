import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var content: String
    var createdAt: Date

    // Phase 6.5 — Sentiment & Journal properties
    var sentimentScore: Double
    var sentimentLabel: String
    var sentimentMagnitude: Double
    var title: String
    var wordCount: Int
    var updatedAt: Date

    // JSON-backed storage for arrays (avoids CoreData Array<String> materialization errors)
    var parsedHabitsJSON: String
    var tagsJSON: String

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
        self.parsedHabitsJSON = Self.encodeStringArray(parsedHabits)
        self.createdAt = createdAt
        self.sentimentScore = sentimentScore
        self.sentimentLabel = sentimentLabel
        self.sentimentMagnitude = sentimentMagnitude
        self.title = title
        self.wordCount = wordCount
        self.tagsJSON = Self.encodeStringArray(tags)
        self.updatedAt = updatedAt
    }
}

// MARK: - Array Accessors (outside @Model macro scope)

extension JournalEntry {
    var parsedHabits: [String] {
        get { Self.decodeStringArray(parsedHabitsJSON) }
        set { parsedHabitsJSON = Self.encodeStringArray(newValue) }
    }

    var tags: [String] {
        get { Self.decodeStringArray(tagsJSON) }
        set { tagsJSON = Self.encodeStringArray(newValue) }
    }

    static func encodeStringArray(_ array: [String]) -> String {
        (try? String(data: JSONEncoder().encode(array), encoding: .utf8)) ?? "[]"
    }

    static func decodeStringArray(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
