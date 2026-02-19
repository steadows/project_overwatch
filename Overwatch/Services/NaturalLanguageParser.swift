import Foundation
import SwiftData

// MARK: - ParsedHabit

/// Result of parsing a freeform text input into a structured habit entry.
struct ParsedHabit: Sendable, Codable {
    let habitName: String
    let value: Double?
    let unit: String?
    let confidence: Double
    let rawInput: String
    let matchedHabitID: UUID?

    static func unrecognized(_ input: String) -> ParsedHabit {
        ParsedHabit(
            habitName: input,
            value: nil,
            unit: nil,
            confidence: 0,
            rawInput: input,
            matchedHabitID: nil
        )
    }
}

// MARK: - HabitReference

/// Lightweight habit info passed to the parser for fuzzy matching.
/// Avoids coupling the parser to SwiftData model objects directly.
struct HabitReference: Sendable {
    let id: UUID
    let name: String
    let isQuantitative: Bool
    let unitLabel: String
}

// MARK: - Cached Parse Entry

/// Wraps a ParsedHabit with a timestamp for cache TTL.
private struct CachedParse: Codable, Sendable {
    let result: ParsedHabit
    let cachedAt: Date
}

// MARK: - NaturalLanguageParser

/// Parses freeform text into structured habit entries.
///
/// Local regex-based parsing handles common patterns instantly.
/// Gemini is a fallback for ambiguous or complex inputs when the local
/// parser returns low confidence (< 0.7). Results from Gemini are cached
/// in UserDefaults with a 30-day TTL to avoid redundant API calls.
final class NaturalLanguageParser: Sendable {

    private static let cacheKey = "overwatch.parserCache"
    private static let cacheTTLSeconds: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    // MARK: - Public API

    /// Main entry point. Tries local parse first, then cache, then Gemini fallback.
    ///
    /// 1. Local regex parse — if confidence >= 0.7, returns immediately
    /// 2. Cache lookup — if a previous Gemini result exists for this input
    /// 3. Gemini API call — for ambiguous inputs
    /// 4. Falls back to local result (even low confidence) or unrecognized
    func parse(_ input: String, habits: [HabitReference]) async -> ParsedHabit {
        // Step 1: Try local parser — return immediately if high confidence
        if let local = parseLocally(input, habits: habits), local.confidence >= 0.7 {
            return local
        }

        // Step 2: Check cache for a previous Gemini result
        if let cached = getCachedResult(for: input) {
            return cached
        }

        // Step 3: Try Gemini fallback
        if let geminiService = GeminiService.create() {
            let existingHabitNames = habits.map(\.name)
            do {
                let response = try await geminiService.parseHabit(
                    input,
                    existingHabits: existingHabitNames
                )
                let matchedHabit = findBestMatch(response.habitName, in: habits)
                let result = ParsedHabit(
                    habitName: matchedHabit?.name ?? response.habitName,
                    value: response.value,
                    unit: response.unit,
                    confidence: response.confidence,
                    rawInput: input,
                    matchedHabitID: matchedHabit?.id
                )
                cacheResult(result, for: input)
                return result
            } catch {
                // Gemini failed — fall through to local result or unrecognized
            }
        }

        // Step 4: Return local result (even low confidence) or unrecognized
        if let local = parseLocally(input, habits: habits) {
            return local
        }
        return .unrecognized(input)
    }

    /// Synchronous regex-based parser. Returns nil if no pattern matches.
    func parseLocally(_ input: String, habits: [HabitReference]) -> ParsedHabit? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Try quantity parse first (more specific)
        if let result = parseQuantity(trimmed, habits: habits) {
            return result
        }

        // Try boolean parse
        if let result = parseBoolean(trimmed, habits: habits) {
            return result
        }

        // Try direct fuzzy match as last resort
        if let result = fuzzyMatch(trimmed, habits: habits) {
            return result
        }

        return nil
    }

    // MARK: - Quantity Parsing

    /// Patterns like "Drank 3L water", "Slept 8 hours", "Ran 5k", "Meditated 20 min"
    private func parseQuantity(_ input: String, habits: [HabitReference]) -> ParsedHabit? {
        let lowered = input.lowercased()

        // Pattern group 1: "{verb} {number}{unit} {habit}"
        // e.g., "Drank 3L water", "Drank 2.5L water"
        let verbNumberUnitHabit = try? NSRegularExpression(
            pattern: #"^(?:\w+\s+)?(\d+(?:\.\d+)?)\s*([a-zA-Z]+)\s+(.+)$"#,
            options: .caseInsensitive
        )

        // Pattern group 2: "{verb} {number} {unit} {habit}" (unit separated by space)
        // e.g., "Slept 8 hours", "Meditated 20 min"
        let verbNumberSpaceUnitHabit = try? NSRegularExpression(
            pattern: #"^(?:\w+\s+)?(\d+(?:\.\d+)?)\s+(\w+)\s+(.+)$"#,
            options: .caseInsensitive
        )

        // Pattern group 3: "{verb} {number}{unit}" (no trailing habit word)
        // e.g., "Ran 5k", "Slept 8h"
        let verbNumberUnit = try? NSRegularExpression(
            pattern: #"^(.+?)\s+(\d+(?:\.\d+)?)\s*([a-zA-Z]+)$"#,
            options: .caseInsensitive
        )

        let range = NSRange(lowered.startIndex..., in: lowered)

        // Try pattern 1: "Drank 3L water"
        if let regex = verbNumberUnitHabit,
           let match = regex.firstMatch(in: lowered, range: range) {
            let valueStr = String(lowered[Range(match.range(at: 1), in: lowered)!])
            let unitStr = String(lowered[Range(match.range(at: 2), in: lowered)!])
            let habitStr = String(lowered[Range(match.range(at: 3), in: lowered)!])

            // Check if unitStr is actually a unit (not a habit word)
            let normalizedUnit = normalizeUnit(unitStr)
            if normalizedUnit != nil, let value = Double(valueStr) {
                let matchedHabit = findBestMatch(habitStr, in: habits)
                    ?? findBestMatch(extractHabitKeyword(from: input), in: habits)
                return ParsedHabit(
                    habitName: matchedHabit?.name ?? habitStr.capitalized,
                    value: value,
                    unit: normalizedUnit,
                    confidence: matchedHabit != nil ? 0.95 : 0.6,
                    rawInput: input,
                    matchedHabitID: matchedHabit?.id
                )
            }
        }

        // Try pattern 2: "Slept 8 hours" or "Meditated 20 min"
        if let regex = verbNumberSpaceUnitHabit,
           let match = regex.firstMatch(in: lowered, range: range) {
            let valueStr = String(lowered[Range(match.range(at: 1), in: lowered)!])
            let unitStr = String(lowered[Range(match.range(at: 2), in: lowered)!])
            let habitStr = String(lowered[Range(match.range(at: 3), in: lowered)!])

            if let normalizedUnit = normalizeUnit(unitStr),
               let value = Double(valueStr) {
                // "Slept 8 hours" — habit might be in the verb or the trailing word
                let matchedHabit = findBestMatch(habitStr, in: habits)
                    ?? findBestMatch(extractHabitKeyword(from: input), in: habits)
                return ParsedHabit(
                    habitName: matchedHabit?.name ?? habitStr.capitalized,
                    value: value,
                    unit: normalizedUnit,
                    confidence: matchedHabit != nil ? 0.9 : 0.55,
                    rawInput: input,
                    matchedHabitID: matchedHabit?.id
                )
            }
        }

        // Try pattern 3/4: "Ran 5k", "Water 3L"
        if let regex = verbNumberUnit,
           let match = regex.firstMatch(in: lowered, range: range) {
            let habitStr = String(lowered[Range(match.range(at: 1), in: lowered)!])
            let valueStr = String(lowered[Range(match.range(at: 2), in: lowered)!])
            let unitStr = String(lowered[Range(match.range(at: 3), in: lowered)!])

            if let normalizedUnit = normalizeUnit(unitStr),
               let value = Double(valueStr) {
                let keyword = extractHabitKeyword(from: habitStr)
                let matchedHabit = findBestMatch(keyword, in: habits)
                    ?? findBestMatch(habitStr, in: habits)
                return ParsedHabit(
                    habitName: matchedHabit?.name ?? habitStr.capitalized,
                    value: value,
                    unit: normalizedUnit,
                    confidence: matchedHabit != nil ? 0.9 : 0.55,
                    rawInput: input,
                    matchedHabitID: matchedHabit?.id
                )
            }
        }

        return nil
    }

    // MARK: - Boolean Parsing

    /// Patterns like "Worked out", "Did yoga", "No alcohol", "Skipped sugar"
    private func parseBoolean(_ input: String, habits: [HabitReference]) -> ParsedHabit? {
        let lowered = input.lowercased().trimmingCharacters(in: .whitespaces)

        // "Did {habit}" — e.g., "Did yoga", "Did meditation"
        if lowered.hasPrefix("did ") {
            let habitStr = String(lowered.dropFirst(4))
            return matchBooleanHabit(habitStr, from: input, habits: habits)
        }

        // "No {habit}" — e.g., "No alcohol", "No sugar"
        if lowered.hasPrefix("no ") {
            let habitStr = String(lowered.dropFirst(3))
            return matchBooleanHabit(habitStr, from: input, habits: habits)
        }

        // "Skipped {habit}" — e.g., "Skipped sugar", "Skipped junk food"
        if lowered.hasPrefix("skipped ") {
            let habitStr = String(lowered.dropFirst(8))
            return matchBooleanHabit(habitStr, from: input, habits: habits)
        }

        // "Worked out" / "Work out" → exercise
        if lowered.contains("worked out") || lowered.contains("work out") {
            let matchedHabit = findBestMatch("exercise", in: habits)
                ?? findBestMatch("workout", in: habits)
                ?? findBestMatch("work out", in: habits)
            return ParsedHabit(
                habitName: matchedHabit?.name ?? "Exercise",
                value: nil,
                unit: nil,
                confidence: matchedHabit != nil ? 0.95 : 0.5,
                rawInput: input,
                matchedHabitID: matchedHabit?.id
            )
        }

        // Single-word action verbs as habits: "Meditated", "Exercised", "Read"
        let actionVerbs: [String: [String]] = [
            "meditated": ["meditation", "meditate"],
            "exercised": ["exercise", "workout"],
            "journaled": ["journal", "journaling"],
            "stretched": ["stretch", "stretching"],
            "read": ["reading", "read"],
            "walked": ["walk", "walking"],
            "ran": ["run", "running"],
            "cycled": ["cycling", "cycle", "bike"],
            "swam": ["swim", "swimming"],
            "prayed": ["prayer", "pray"],
            "fasted": ["fasting", "fast"],
            "coded": ["coding", "code"],
            "studied": ["study", "studying"],
            "flossed": ["flossing", "floss"],
        ]

        for (verb, habitNames) in actionVerbs {
            if lowered == verb || lowered.hasPrefix(verb + " ") {
                for name in habitNames {
                    if let matched = findBestMatch(name, in: habits) {
                        return ParsedHabit(
                            habitName: matched.name,
                            value: nil,
                            unit: nil,
                            confidence: 0.9,
                            rawInput: input,
                            matchedHabitID: matched.id
                        )
                    }
                }
                // No matched habit but recognized verb
                return ParsedHabit(
                    habitName: habitNames.first?.capitalized ?? verb.capitalized,
                    value: nil,
                    unit: nil,
                    confidence: 0.5,
                    rawInput: input,
                    matchedHabitID: nil
                )
            }
        }

        return nil
    }

    private func matchBooleanHabit(_ habitStr: String, from input: String, habits: [HabitReference]) -> ParsedHabit? {
        let trimmed = habitStr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let matchedHabit = findBestMatch(trimmed, in: habits)
        return ParsedHabit(
            habitName: matchedHabit?.name ?? trimmed.capitalized,
            value: nil,
            unit: nil,
            confidence: matchedHabit != nil ? 0.9 : 0.5,
            rawInput: input,
            matchedHabitID: matchedHabit?.id
        )
    }

    // MARK: - Fuzzy Matching

    /// Direct fuzzy match — the input itself matches a habit name.
    private func fuzzyMatch(_ input: String, habits: [HabitReference]) -> ParsedHabit? {
        guard let matched = findBestMatch(input, in: habits) else { return nil }
        return ParsedHabit(
            habitName: matched.name,
            value: nil,
            unit: nil,
            confidence: 0.85,
            rawInput: input,
            matchedHabitID: matched.id
        )
    }

    /// Find the best matching habit from the list.
    /// Priority: exact match > prefix match > contains match > abbreviation match.
    func findBestMatch(_ query: String, in habits: [HabitReference]) -> HabitReference? {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }

        // Exact match (case insensitive)
        if let exact = habits.first(where: { $0.name.lowercased() == q }) {
            return exact
        }

        // Prefix match — "med" matches "Meditation"
        if let prefix = habits.first(where: { $0.name.lowercased().hasPrefix(q) }) {
            return prefix
        }

        // Contains match — "yoga" matches "Hot Yoga"
        if let contains = habits.first(where: { $0.name.lowercased().contains(q) }) {
            return contains
        }

        // Reverse contains — "meditation practice" contains "meditation"
        if let reverseContains = habits.first(where: { q.contains($0.name.lowercased()) }) {
            return reverseContains
        }

        // Abbreviation map
        let abbreviations: [String: [String]] = [
            "med": ["meditation", "meditate"],
            "ex": ["exercise"],
            "wt": ["water", "weight training"],
            "cg": ["coding"],
            "wo": ["workout", "work out"],
            "jnl": ["journal"],
            "vit": ["vitamins"],
        ]

        if let expansions = abbreviations[q] {
            for expansion in expansions {
                if let match = habits.first(where: { $0.name.lowercased().contains(expansion) }) {
                    return match
                }
            }
        }

        return nil
    }

    // MARK: - Unit Normalization

    /// Recognized units mapped to their canonical form.
    private static let unitMap: [String: String] = [
        // Volume
        "l": "L", "liter": "L", "liters": "L", "litre": "L", "litres": "L",
        "ml": "mL", "milliliter": "mL", "milliliters": "mL",
        "oz": "oz", "ounce": "oz", "ounces": "oz",
        "cup": "cups", "cups": "cups",
        "gal": "gal", "gallon": "gal", "gallons": "gal",
        // Time
        "h": "hours", "hr": "hours", "hrs": "hours", "hour": "hours", "hours": "hours",
        "m": "min", "min": "min", "mins": "min", "minute": "min", "minutes": "min",
        "s": "sec", "sec": "sec", "secs": "sec", "second": "sec", "seconds": "sec",
        // Distance
        "k": "km", "km": "km", "kilometer": "km", "kilometers": "km", "kilometre": "km",
        "mi": "mi", "mile": "mi", "miles": "mi",
        "yd": "yd", "yard": "yd", "yards": "yd",
        // Weight
        "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb",
        "kg": "kg", "kilogram": "kg", "kilograms": "kg",
        // Count
        "x": "reps", "rep": "reps", "reps": "reps",
        "set": "sets", "sets": "sets",
        "pg": "pages", "page": "pages", "pages": "pages",
        "ch": "chapters", "chapter": "chapters", "chapters": "chapters",
        // Calories
        "cal": "cal", "cals": "cal", "calorie": "cal", "calories": "cal", "kcal": "cal",
    ]

    /// Returns canonical unit string if recognized, nil otherwise.
    func normalizeUnit(_ raw: String) -> String? {
        Self.unitMap[raw.lowercased()]
    }

    // MARK: - Helpers

    /// Extracts likely habit keyword from a verb phrase.
    /// "Drank" → "water" (via verb→habit map), "Slept" → "sleep"
    private func extractHabitKeyword(from input: String) -> String {
        let lowered = input.lowercased()
        let firstWord = lowered.split(separator: " ").first.map(String.init) ?? lowered

        let verbToHabit: [String: String] = [
            "drank": "water",
            "drink": "water",
            "slept": "sleep",
            "sleep": "sleep",
            "ran": "running",
            "run": "running",
            "walked": "walking",
            "walk": "walking",
            "meditated": "meditation",
            "meditate": "meditation",
            "read": "reading",
            "studied": "study",
            "study": "study",
            "exercised": "exercise",
            "cycled": "cycling",
            "swam": "swimming",
            "lifted": "weight training",
        ]

        return verbToHabit[firstWord] ?? firstWord
    }

    // MARK: - Gemini Result Cache

    /// Retrieves a cached Gemini parse result if it exists and hasn't expired.
    private func getCachedResult(for input: String) -> ParsedHabit? {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let cache = try? JSONDecoder().decode([String: CachedParse].self, from: data),
              let entry = cache[input.lowercased()],
              Date().timeIntervalSince(entry.cachedAt) < Self.cacheTTLSeconds
        else { return nil }
        return entry.result
    }

    /// Stores a Gemini parse result in the cache.
    private func cacheResult(_ result: ParsedHabit, for input: String) {
        var cache: [String: CachedParse] = [:]
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let existing = try? JSONDecoder().decode([String: CachedParse].self, from: data) {
            cache = existing
        }
        cache[input.lowercased()] = CachedParse(result: result, cachedAt: Date())
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }
}
