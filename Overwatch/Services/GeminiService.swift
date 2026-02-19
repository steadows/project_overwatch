import Foundation
@preconcurrency import GoogleGenerativeAI

// MARK: - Error Types

enum GeminiError: LocalizedError {
    case noAPIKey
    case emptyResponse
    case invalidResponse(String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "No Gemini API key configured"
        case .emptyResponse: "Empty response from Gemini"
        case .invalidResponse(let detail): "Invalid Gemini response: \(detail)"
        case .rateLimited: "Gemini API rate limited — try again later"
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

    private let model: GenerativeModel

    init(apiKey: String) {
        self.model = GenerativeModel(name: "gemini-2.0-flash", apiKey: apiKey)
    }

    /// Creates a GeminiService from the configured API key, or nil if no key is available.
    static func create() -> GeminiService? {
        guard let key = EnvironmentConfig.geminiAPIKey else { return nil }
        return GeminiService(apiKey: key)
    }

    // MARK: - Habit Parsing

    /// Sends freeform text to Gemini for structured habit parsing.
    /// The prompt includes the user's existing habit names for context-aware matching.
    func parseHabit(_ input: String, existingHabits: [String]) async throws -> GeminiParsedResponse {
        let prompt = buildParsePrompt(input: input, habits: existingHabits)
        let response = try await model.generateContent(prompt)

        guard let text = response.text else {
            throw GeminiError.emptyResponse
        }

        return try decodeParseResponse(text)
    }

    // MARK: - Connection Test

    /// Verifies the API key works by sending a minimal request.
    func testConnection() async throws -> Bool {
        let response = try await model.generateContent("Respond with exactly one word: OK")
        return response.text != nil
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
            let response = try await model.generateContent(prompt)
            guard let text = response.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return Self.templateFallback(
                    coefficients: coefficients,
                    averageSentiment: averageSentiment,
                    monthName: monthName,
                    entryCount: entryCount
                )
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
        let response = try await model.generateContent(prompt)
        guard let text = response.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.emptyResponse
        }
        return text
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
