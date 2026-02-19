import Foundation
@preconcurrency import GoogleGenerativeAI

// MARK: - Error Types

enum GeminiError: LocalizedError {
    case noAPIKey
    case emptyResponse
    case invalidResponse(String)
    case rateLimited
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "No Gemini API key configured"
        case .emptyResponse: "Empty response from Gemini"
        case .invalidResponse(let detail): "Invalid Gemini response: \(detail)"
        case .rateLimited: "Gemini API rate limited — try again later"
        case .serviceUnavailable: "Gemini service temporarily unavailable — retries exhausted"
        }
    }
}

// MARK: - Gemini Parsed Response

struct GeminiParsedResponse: Codable, Sendable {
    let habitName: String
    let value: Double?
    let unit: String?
    let confidence: Double
    let isExistingHabit: Bool
}

// MARK: - GeminiService

/// Centralizes all Gemini API communication. Manages the GenerativeModel instance
/// and provides structured methods for habit parsing and connection testing.
actor GeminiService {

    private static let primaryModel = "gemini-2.5-flash"
    private static let maxRetries = 3
    private static let baseDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds

    private let model: GenerativeModel

    init(apiKey: String) {
        self.model = GenerativeModel(name: Self.primaryModel, apiKey: apiKey)
    }

    /// Creates a GeminiService from the configured API key, or nil if no key is available.
    static func create() -> GeminiService? {
        guard let key = EnvironmentConfig.geminiAPIKey else { return nil }
        return GeminiService(apiKey: key)
    }

    // MARK: - Retry Logic

    /// Executes a Gemini API call with exponential backoff on transient failures (503, rate limits).
    private func withRetry<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        for attempt in 0..<Self.maxRetries {
            do {
                return try await operation()
            } catch {
                let isTransient = isTransientError(error)
                let isLastAttempt = attempt == Self.maxRetries - 1

                if !isTransient || isLastAttempt {
                    if isTransient { throw GeminiError.serviceUnavailable }
                    throw error
                }

                let delay = Self.baseDelay * UInt64(1 << attempt) // 1s, 2s, 4s
                try await Task.sleep(nanoseconds: delay)
            }
        }
        throw GeminiError.serviceUnavailable
    }

    /// Checks if an error is a transient server-side failure worth retrying.
    private nonisolated func isTransientError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("unavailable")
            || message.contains("503")
            || message.contains("high demand")
            || message.contains("rate limit")
            || message.contains("overloaded")
    }

    // MARK: - Habit Parsing

    /// Sends freeform text to Gemini for structured habit parsing.
    /// The prompt includes the user's existing habit names for context-aware matching.
    func parseHabit(_ input: String, existingHabits: [String]) async throws -> GeminiParsedResponse {
        let prompt = buildParsePrompt(input: input, habits: existingHabits)

        let text: String = try await withRetry {
            let response = try await self.model.generateContent(prompt)
            guard let text = response.text else { throw GeminiError.emptyResponse }
            return text
        }

        return try decodeParseResponse(text)
    }

    // MARK: - Connection Test

    /// Verifies the API key works by sending a minimal request.
    func testConnection() async throws -> Bool {
        try await withRetry {
            let response = try await self.model.generateContent("Respond with exactly one word: OK")
            return response.text != nil
        }
    }

    // MARK: - Prompt Building

    private func buildParsePrompt(input: String, habits: [String]) -> String {
        let habitList = habits.isEmpty
            ? "No habits configured yet."
            : habits.joined(separator: ", ")

        return """
        You are a habit tracking assistant. Parse the following user input into a structured habit entry.

        The user's existing tracked habits are: \(habitList)

        User input: "\(input)"

        Respond with ONLY a JSON object. No markdown fences, no explanation — just raw JSON.

        Fields:
        - "habitName": string — the habit name. Match to an existing habit name if the input clearly refers to one.
        - "value": number or null — numeric value if present (e.g., 3.0 for "drank 3L water").
        - "unit": string or null — unit if present (e.g., "L", "hours", "min", "km").
        - "confidence": number 0.0 to 1.0 — how confident you are in the parse.
        - "isExistingHabit": boolean — true if habitName matches one of the user's existing habits.

        Rules:
        - If the input is gibberish or completely unrelated to habits, set confidence below 0.3.
        - If the input mentions multiple habits, pick the primary one and set confidence to 0.6.
        - Normalize unit abbreviations: "L" for liters, "hours" for hours, "min" for minutes, "km" for kilometers.
        - Match existing habits case-insensitively. "water" should match "Water", "meditation" should match "Meditation".
        """
    }

    // MARK: - Sentiment Analysis

    /// Analyzes sentiment of journal text using Gemini, accounting for negation, sarcasm, and context.
    /// Returns nil if Gemini fails so the caller can fall back to NLTagger.
    func analyzeSentiment(title: String, content: String) async -> SentimentResult? {
        let prompt = buildSentimentPrompt(title: title, content: content)

        do {
            let text: String = try await withRetry {
                let response = try await self.model.generateContent(prompt)
                guard let text = response.text else { throw GeminiError.emptyResponse }
                return text
            }
            return parseSentimentResponse(text)
        } catch {
            return nil
        }
    }

    // MARK: - Sentiment Prompt (RISEN)

    private func buildSentimentPrompt(title: String, content: String) -> String {
        """
        <role>
        You are a sentiment analyst specializing in personal journal entries. You understand nuance, \
        negation, sarcasm, understatement, and contextual tone. You score text on a continuous scale \
        from -1.0 (very negative) to 1.0 (very positive).
        </role>

        <instructions>
        Analyze the sentiment of the following journal entry (title + content provided together). \
        Return a JSON object with "score" (number, -1.0 to 1.0) and "label" (string: "positive", \
        "negative", or "neutral").
        </instructions>

        <steps>
        1. Read the title and full content as a unified piece of writing.
        2. Assess the overall emotional tone, paying close attention to negation ("not bad" = mildly positive), \
        sarcasm, hedging, and mixed sentiments.
        3. Assign a continuous score from -1.0 to 1.0 reflecting the dominant emotional tone.
        4. Assign a label: "positive" if score > 0.1, "negative" if score < -0.1, "neutral" otherwise.
        </steps>

        <expectations>
        Respond with ONLY a JSON object. No markdown fences, no explanation — just raw JSON. \
        Format: {"score": <number>, "label": "<string>"}. \
        The score must be between -1.0 and 1.0. The label must be one of: "positive", "negative", "neutral".
        </expectations>

        <narrowing>
        Do not invent context not present in the text. Do not provide commentary or advice. \
        Do not wrap the JSON in code fences or add any text before or after the JSON object. \
        Analyze only what is written — not what you think the author should feel.
        </narrowing>

        <journal_entry>
        Title: \(title)

        \(content)
        </journal_entry>
        """
    }

    private func parseSentimentResponse(_ text: String) -> SentimentResult? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let score = json["score"] as? Double,
              let labelStr = json["label"] as? String,
              let label = SentimentResult.SentimentLabel(rawValue: labelStr) else {
            return nil
        }

        let clampedScore = min(max(score, -1.0), 1.0)
        return SentimentResult(
            score: clampedScore,
            label: label,
            magnitude: abs(clampedScore)
        )
    }

    // MARK: - Regression Narrative

    /// Sends regression results to Gemini for a narrative summary using the RISEN framework.
    ///
    /// Returns a 2-3 paragraph narrative summarizing wellbeing drivers, highlighting
    /// the force multiplier habit, and providing an actionable recommendation.
    /// Falls back to a template-based summary when Gemini is unavailable.
    func interpretRegressionResults(
        coefficients: [HabitCoefficient],
        averageSentiment: Double,
        monthName: String,
        entryCount: Int
    ) async throws -> String {
        let prompt = buildRegressionNarrativePrompt(
            coefficients: coefficients,
            averageSentiment: averageSentiment,
            monthName: monthName,
            entryCount: entryCount
        )

        do {
            let text: String = try await withRetry {
                let response = try await self.model.generateContent(prompt)
                guard let text = response.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw GeminiError.emptyResponse
                }
                return text
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return Self.templateFallback(
                coefficients: coefficients,
                averageSentiment: averageSentiment,
                monthName: monthName,
                entryCount: entryCount
            )
        }
    }

    // MARK: - Regression Narrative Prompt (RISEN)

    private func buildRegressionNarrativePrompt(
        coefficients: [HabitCoefficient],
        averageSentiment: Double,
        monthName: String,
        entryCount: Int
    ) -> String {
        let coeffJSON = coefficients.map { coeff in
            """
            {"habitName": "\(coeff.habitName)", "emoji": "\(coeff.habitEmoji)", \
            "coefficient": \(String(format: "%.4f", coeff.coefficient)), \
            "pValue": \(String(format: "%.4f", coeff.pValue)), \
            "completionRate": \(String(format: "%.2f", coeff.completionRate)), \
            "direction": "\(coeff.direction.rawValue)"}
            """
        }.joined(separator: ",\n")

        let forceMultiplier = coefficients
            .filter { $0.direction == .positive }
            .max(by: { $0.coefficient < $1.coefficient })

        let forceMultiplierName = forceMultiplier?.habitName ?? "none identified"

        return """
        <role>
        You are a performance coach who analyzes habit and wellbeing data. You are encouraging \
        but honest, data-driven, and always actionable. You speak directly to the user as "you."
        </role>

        <instructions>
        Analyze the following monthly habit-sentiment regression results. Produce a 2-3 paragraph \
        narrative summary. Highlight the force multiplier habit (the habit with the strongest positive \
        impact on mood). End with one concrete, actionable recommendation for next month.
        </instructions>

        <steps>
        1. Review the habit coefficients and identify the strongest positive and negative drivers of sentiment.
        2. Summarize the overall sentiment trend for \(monthName) using the average score and entry count.
        3. Call out the force multiplier habit ("\(forceMultiplierName)") with its specific coefficient value.
        4. Note any habits with negative coefficients that may be dragging mood down.
        5. Provide one concrete, actionable recommendation for improving wellbeing next month.
        </steps>

        <expectations>
        Respond in 2-3 paragraphs of narrative prose. Use a motivational but data-grounded tone. \
        Reference specific habit names and their coefficient values. Do not use bullet points or \
        numbered lists — narrative prose only. Do not use markdown formatting. Keep the total \
        response under 300 words.
        </expectations>

        <narrowing>
        Do not invent data points not present in the input. Do not provide medical advice. \
        Do not reference habits not included in the data. Do not use generic platitudes — \
        every sentence should reference specific data from the input.
        </narrowing>

        <habit_coefficients>
        [\(coeffJSON)]
        </habit_coefficients>

        <sentiment_summary>
        {"averageScore": \(String(format: "%.3f", averageSentiment)), "entryCount": \(entryCount), "month": "\(monthName)"}
        </sentiment_summary>

        <force_multiplier>
        \(forceMultiplierName)
        </force_multiplier>
        """
    }

    // MARK: - Template Fallback

    /// Generates a template-based narrative when Gemini is unavailable.
    static func templateFallback(
        coefficients: [HabitCoefficient],
        averageSentiment: Double,
        monthName: String,
        entryCount: Int
    ) -> String {
        let sorted = coefficients.sorted { $0.coefficient > $1.coefficient }
        let forceMultiplier = sorted.first(where: { $0.direction == .positive })
        let detractor = sorted.last(where: { $0.direction == .negative })

        let sentimentLabel: String
        if averageSentiment > 0.2 { sentimentLabel = "positive" }
        else if averageSentiment > 0.05 { sentimentLabel = "slightly positive" }
        else if averageSentiment > -0.05 { sentimentLabel = "neutral" }
        else if averageSentiment > -0.2 { sentimentLabel = "slightly negative" }
        else { sentimentLabel = "negative" }

        var paragraphs: [String] = []

        // Paragraph 1: Overview
        paragraphs.append(
            "Your \(monthName) analysis is based on \(entryCount) journal entries. " +
            "Your average sentiment score was \(String(format: "%.2f", averageSentiment)), " +
            "reflecting an overall \(sentimentLabel) month."
        )

        // Paragraph 2: Force multiplier + detractor
        var p2 = ""
        if let fm = forceMultiplier {
            p2 += "\(fm.habitEmoji) \(fm.habitName) was your force multiplier this month " +
                  "with a coefficient of \(String(format: "+%.3f", fm.coefficient)), " +
                  "meaning days you completed it tended to have noticeably higher mood scores. "
        }
        if let det = detractor {
            p2 += "On the flip side, \(det.habitEmoji) \(det.habitName) showed a negative correlation " +
                  "(\(String(format: "%.3f", det.coefficient))), suggesting it may be worth examining " +
                  "how this habit affects your day."
        }
        if p2.isEmpty {
            p2 = "No single habit stood out as a dominant driver this month. " +
                 "Consistency across your routines is likely contributing to a stable baseline."
        }
        paragraphs.append(p2)

        // Paragraph 3: Recommendation
        if let fm = forceMultiplier {
            paragraphs.append(
                "Recommendation: prioritize \(fm.habitName) next month. " +
                "Your completion rate was \(Int(fm.completionRate * 100))% — " +
                "even a small increase in consistency could meaningfully boost your wellbeing."
            )
        } else {
            paragraphs.append(
                "Recommendation: experiment with increasing the frequency of one habit " +
                "you enjoy and see if it shifts your sentiment scores upward next month."
            )
        }

        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: - Weekly Briefing

    /// Sends a pre-built RISEN prompt to Gemini and returns the raw response text.
    /// Used by IntelligenceManager for weekly intelligence briefings.
    func generateWeeklyBriefing(prompt: String) async throws -> String {
        try await withRetry {
            let response = try await self.model.generateContent(prompt)
            guard let text = response.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw GeminiError.emptyResponse
            }
            return text
        }
    }

    // MARK: - Response Decoding

    private func decodeParseResponse(_ text: String) throws -> GeminiParsedResponse {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.invalidResponse("Could not encode response as UTF-8")
        }

        do {
            return try JSONDecoder().decode(GeminiParsedResponse.self, from: data)
        } catch {
            throw GeminiError.invalidResponse(error.localizedDescription)
        }
    }
}
