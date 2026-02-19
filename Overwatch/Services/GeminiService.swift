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
