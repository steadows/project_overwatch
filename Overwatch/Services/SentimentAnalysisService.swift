import Foundation
import NaturalLanguage
import SwiftData

// MARK: - SentimentResult

/// The result of analyzing sentiment for a piece of text.
struct SentimentResult: Sendable, Equatable {
    let score: Double
    let label: SentimentLabel
    let magnitude: Double

    enum SentimentLabel: String, Sendable, Equatable {
        case positive
        case negative
        case neutral
    }

    static let neutral = SentimentResult(score: 0.0, label: .neutral, magnitude: 0.0)
}

// MARK: - SentimentAnalysisService

/// Scores text sentiment using Apple's NLTagger (.sentimentScore scheme).
///
/// Thread-safe actor — call from any context. Returns a continuous score
/// from -1.0 (very negative) to 1.0 (very positive) plus a categorical label.
actor SentimentAnalysisService {

    private let tagger: NLTagger

    init() {
        self.tagger = NLTagger(tagSchemes: [.sentimentScore])
    }

    // MARK: - Single Entry

    /// Analyze sentiment for a single text string.
    ///
    /// - Returns: `SentimentResult` with score, label, and magnitude.
    ///   Empty or very short text (< 10 chars) returns neutral with magnitude 0.
    func analyzeSentiment(_ text: String) -> SentimentResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Edge case: empty or very short text → neutral
        guard trimmed.count >= 10 else {
            return .neutral
        }

        tagger.string = trimmed
        let range = trimmed.startIndex ..< trimmed.endIndex

        // NLTagger returns a tag whose rawValue is the score as a string
        let (tag, _) = tagger.tag(at: range.lowerBound,
                                  unit: .paragraph,
                                  scheme: .sentimentScore)

        guard let tag,
              let score = Double(tag.rawValue) else {
            return .neutral
        }

        // Clamp to [-1.0, 1.0]
        let clampedScore = min(max(score, -1.0), 1.0)
        let magnitude = abs(clampedScore)
        let label = Self.label(for: clampedScore)

        return SentimentResult(score: clampedScore, label: label, magnitude: magnitude)
    }

    // MARK: - Batch Processing

    /// Score and update an array of JournalEntry objects in place.
    ///
    /// Each entry's `sentimentScore`, `sentimentLabel`, and `sentimentMagnitude`
    /// are set based on its `content` field.
    @MainActor
    func analyzeBatch(_ entries: [JournalEntry]) {
        for entry in entries {
            let result = analyzeText(entry.content)
            entry.sentimentScore = result.score
            entry.sentimentLabel = result.label.rawValue
            entry.sentimentMagnitude = result.magnitude
        }
    }

    // MARK: - Private

    /// Non-isolated text analysis (creates its own tagger for thread safety in batch).
    private nonisolated func analyzeText(_ text: String) -> SentimentResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return .neutral }

        let localTagger = NLTagger(tagSchemes: [.sentimentScore])
        localTagger.string = trimmed
        let range = trimmed.startIndex ..< trimmed.endIndex

        let (tag, _) = localTagger.tag(at: range.lowerBound,
                                       unit: .paragraph,
                                       scheme: .sentimentScore)

        guard let tag, let score = Double(tag.rawValue) else { return .neutral }

        let clampedScore = min(max(score, -1.0), 1.0)
        let magnitude = abs(clampedScore)
        let label = Self.label(for: clampedScore)

        return SentimentResult(score: clampedScore, label: label, magnitude: magnitude)
    }

    private static func label(for score: Double) -> SentimentResult.SentimentLabel {
        if score > 0.1 { return .positive }
        if score < -0.1 { return .negative }
        return .neutral
    }
}
