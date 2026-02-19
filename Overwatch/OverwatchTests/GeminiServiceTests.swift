import Testing
import Foundation
@testable import Overwatch

// MARK: - GeminiParsedResponse Decoding

@Suite("Gemini Response Decoding")
struct GeminiResponseDecodingTests {

    @Test
    func decodesValidQuantityResponse() throws {
        let json = """
        {"habitName":"Water","value":3.0,"unit":"L","confidence":0.95,"isExistingHabit":true}
        """
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder().decode(GeminiParsedResponse.self, from: data)
        #expect(response.habitName == "Water")
        #expect(response.value == 3.0)
        #expect(response.unit == "L")
        #expect(response.confidence == 0.95)
        #expect(response.isExistingHabit == true)
    }

    @Test
    func decodesValidBooleanResponse() throws {
        let json = """
        {"habitName":"Yoga","value":null,"unit":null,"confidence":0.9,"isExistingHabit":true}
        """
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder().decode(GeminiParsedResponse.self, from: data)
        #expect(response.habitName == "Yoga")
        #expect(response.value == nil)
        #expect(response.unit == nil)
        #expect(response.confidence == 0.9)
    }

    @Test
    func decodesLowConfidenceGibberish() throws {
        let json = """
        {"habitName":"Unknown","value":null,"unit":null,"confidence":0.1,"isExistingHabit":false}
        """
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder().decode(GeminiParsedResponse.self, from: data)
        #expect(response.confidence < 0.3)
        #expect(response.isExistingHabit == false)
    }

    @Test
    func handlesCodeFencedJSON() throws {
        // Simulates Gemini wrapping response in ```json ... ```
        let raw = """
        ```json
        {"habitName":"Coffee","value":2.0,"unit":"cups","confidence":0.85,"isExistingHabit":false}
        ```
        """
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        let data = try #require(cleaned.data(using: .utf8))
        let response = try JSONDecoder().decode(GeminiParsedResponse.self, from: data)
        #expect(response.habitName == "Coffee")
        #expect(response.value == 2.0)
    }
}

// MARK: - Hybrid Parse Flow

@Suite("Hybrid Parse Flow")
struct HybridParseFlowTests {

    private let parser = NaturalLanguageParser()
    private let habits: [HabitReference] = [
        HabitReference(id: .init(), name: "Water", isQuantitative: true, unitLabel: "L"),
        HabitReference(id: .init(), name: "Exercise", isQuantitative: false, unitLabel: ""),
        HabitReference(id: .init(), name: "Meditation", isQuantitative: true, unitLabel: "min"),
    ]

    @Test
    func highConfidenceLocalSkipsGemini() async {
        // "Drank 3L water" should match locally with >= 0.7 confidence
        let result = await parser.parse("Drank 3L water", habits: habits)
        #expect(result.habitName == "Water")
        #expect(result.value == 3.0)
        #expect(result.confidence >= 0.7)
        #expect(result.matchedHabitID != nil)
    }

    @Test
    func exactMatchLocalSkipsGemini() async {
        // Direct habit name input should match locally
        let result = await parser.parse("Water", habits: habits)
        #expect(result.habitName == "Water")
        #expect(result.matchedHabitID != nil)
    }

    @Test
    func gibberishReturnsUnrecognized() async {
        // Without Gemini configured, gibberish returns unrecognized
        let result = await parser.parse("xyzzy plugh", habits: habits)
        #expect(result.confidence < 0.7)
    }

    @Test
    func emptyInputReturnsUnrecognized() async {
        let result = await parser.parse("", habits: habits)
        #expect(result.confidence == 0)
    }

    @Test
    func emojiOnlyFallsThrough() async {
        let result = await parser.parse("🎉🎊", habits: habits)
        #expect(result.confidence < 0.7)
    }

    @Test
    func numbersOnlyFallsThrough() async {
        let result = await parser.parse("12345", habits: habits)
        #expect(result.confidence < 0.7)
    }

    @Test
    func veryLongInputFallsThrough() async {
        let longInput = String(repeating: "a ", count: 500)
        let result = await parser.parse(longInput, habits: habits)
        // Should not crash, should return something
        #expect(result.rawInput == longInput)
    }
}

// MARK: - ParsedHabit Codable

@Suite("ParsedHabit Codable")
struct ParsedHabitCodableTests {

    @Test
    func roundTripsFullResult() throws {
        let original = ParsedHabit(
            habitName: "Water",
            value: 3.0,
            unit: "L",
            confidence: 0.95,
            rawInput: "Drank 3L water",
            matchedHabitID: UUID()
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ParsedHabit.self, from: data)
        #expect(decoded.habitName == original.habitName)
        #expect(decoded.value == original.value)
        #expect(decoded.unit == original.unit)
        #expect(decoded.confidence == original.confidence)
        #expect(decoded.rawInput == original.rawInput)
        #expect(decoded.matchedHabitID == original.matchedHabitID)
    }

    @Test
    func roundTripsNilFields() throws {
        let original = ParsedHabit(
            habitName: "Yoga",
            value: nil,
            unit: nil,
            confidence: 0.9,
            rawInput: "Did yoga",
            matchedHabitID: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ParsedHabit.self, from: data)
        #expect(decoded.value == nil)
        #expect(decoded.unit == nil)
        #expect(decoded.matchedHabitID == nil)
    }
}

// MARK: - EnvironmentConfig Parsing

@Suite("EnvironmentConfig .env Parsing")
struct EnvironmentConfigTests {

    @Test
    func parsesSimpleKeyValue() {
        let contents = "GEMINI_API_KEY=abc123"
        let result = EnvironmentConfig.parseEnv(contents)
        #expect(result["GEMINI_API_KEY"] == "abc123")
    }

    @Test
    func parsesQuotedValue() {
        let contents = """
        GEMINI_API_KEY="my-secret-key"
        """
        let result = EnvironmentConfig.parseEnv(contents)
        #expect(result["GEMINI_API_KEY"] == "my-secret-key")
    }

    @Test
    func ignoresComments() {
        let contents = """
        # This is a comment
        GEMINI_API_KEY=abc123
        # Another comment
        """
        let result = EnvironmentConfig.parseEnv(contents)
        #expect(result.count == 1)
        #expect(result["GEMINI_API_KEY"] == "abc123")
    }

    @Test
    func ignoresBlankLines() {
        let contents = """

        GEMINI_API_KEY=abc123

        OTHER_KEY=value

        """
        let result = EnvironmentConfig.parseEnv(contents)
        #expect(result["GEMINI_API_KEY"] == "abc123")
        #expect(result["OTHER_KEY"] == "value")
    }

    @Test
    func handlesEqualsInValue() {
        let contents = "GEMINI_API_KEY=abc=123=xyz"
        let result = EnvironmentConfig.parseEnv(contents)
        #expect(result["GEMINI_API_KEY"] == "abc=123=xyz")
    }

    @Test
    func handlesSingleQuotes() {
        let contents = "GEMINI_API_KEY='my-key'"
        let result = EnvironmentConfig.parseEnv(contents)
        #expect(result["GEMINI_API_KEY"] == "my-key")
    }

    @Test
    func handlesEmptyFile() {
        let result = EnvironmentConfig.parseEnv("")
        #expect(result.isEmpty)
    }

    @Test
    func handlesOnlyComments() {
        let contents = """
        # Comment 1
        # Comment 2
        """
        let result = EnvironmentConfig.parseEnv(contents)
        #expect(result.isEmpty)
    }
}
