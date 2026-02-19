import Testing
@testable import Overwatch

// MARK: - Test Helpers

private let sampleHabits: [HabitReference] = [
    HabitReference(id: .init(), name: "Water", isQuantitative: true, unitLabel: "L"),
    HabitReference(id: .init(), name: "Exercise", isQuantitative: false, unitLabel: ""),
    HabitReference(id: .init(), name: "Meditation", isQuantitative: true, unitLabel: "min"),
    HabitReference(id: .init(), name: "Reading", isQuantitative: true, unitLabel: "pages"),
    HabitReference(id: .init(), name: "Sleep", isQuantitative: true, unitLabel: "hours"),
    HabitReference(id: .init(), name: "Running", isQuantitative: true, unitLabel: "km"),
    HabitReference(id: .init(), name: "No Alcohol", isQuantitative: false, unitLabel: ""),
    HabitReference(id: .init(), name: "Yoga", isQuantitative: false, unitLabel: ""),
    HabitReference(id: .init(), name: "Journaling", isQuantitative: false, unitLabel: ""),
    HabitReference(id: .init(), name: "Stretching", isQuantitative: false, unitLabel: ""),
    HabitReference(id: .init(), name: "Fasting", isQuantitative: false, unitLabel: ""),
    HabitReference(id: .init(), name: "Coding", isQuantitative: true, unitLabel: "hours"),
]

private let parser = NaturalLanguageParser()

// MARK: - Quantity Patterns

@Suite("Quantity Parsing")
struct QuantityParsingTests {

    @Test
    func drankThreeLitersWater() {
        let result = parser.parseLocally("Drank 3L water", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 3.0)
        #expect(result?.unit == "L")
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Water")
        #expect(result!.confidence >= 0.9)
    }

    @Test
    func drankDecimalLitersWater() {
        let result = parser.parseLocally("Drank 2.5L water", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 2.5)
        #expect(result?.unit == "L")
        #expect(result?.matchedHabitID != nil)
    }

    @Test
    func sleptEightHours() {
        let result = parser.parseLocally("Slept 8 hours", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 8.0)
        #expect(result?.unit == "hours")
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Sleep")
    }

    @Test
    func meditatedTwentyMin() {
        let result = parser.parseLocally("Meditated 20 min", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 20.0)
        #expect(result?.unit == "min")
        #expect(result?.matchedHabitID != nil)
    }

    @Test
    func ranFiveK() {
        let result = parser.parseLocally("Ran 5k", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 5.0)
        #expect(result?.unit == "km")
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Running")
    }

    @Test
    func waterThreeL() {
        let result = parser.parseLocally("Water 3L", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 3.0)
        #expect(result?.unit == "L")
        #expect(result?.matchedHabitID != nil)
    }

    @Test
    func readThirtyPages() {
        let result = parser.parseLocally("Read 30 pages", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 30.0)
        #expect(result?.unit == "pages")
    }

    @Test
    func sleptSevenPointFiveHours() {
        let result = parser.parseLocally("Slept 7.5 hours", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 7.5)
        #expect(result?.unit == "hours")
    }

    @Test
    func codedTwoHours() {
        let result = parser.parseLocally("Coded 2 hours", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == 2.0)
        #expect(result?.unit == "hours")
    }
}

// MARK: - Boolean Patterns

@Suite("Boolean Parsing")
struct BooleanParsingTests {

    @Test
    func workedOut() {
        let result = parser.parseLocally("Worked out", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Exercise")
        #expect(result!.confidence >= 0.9)
    }

    @Test
    func noAlcohol() {
        let result = parser.parseLocally("No alcohol", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "No Alcohol")
    }

    @Test
    func didYoga() {
        let result = parser.parseLocally("Did yoga", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Yoga")
    }

    @Test
    func skippedAlcohol() {
        let result = parser.parseLocally("Skipped alcohol", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == nil)
        // Should match "No Alcohol" habit via contains
        #expect(result?.matchedHabitID != nil)
    }

    @Test
    func meditated() {
        let result = parser.parseLocally("Meditated", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.value == nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Meditation")
    }

    @Test
    func stretched() {
        let result = parser.parseLocally("Stretched", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Stretching")
    }

    @Test
    func fasted() {
        let result = parser.parseLocally("Fasted", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Fasting")
    }

    @Test
    func journaled() {
        let result = parser.parseLocally("Journaled", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Journaling")
    }
}

// MARK: - Fuzzy Matching

@Suite("Fuzzy Matching")
struct FuzzyMatchingTests {

    @Test
    func exactMatchCaseInsensitive() {
        let result = parser.parseLocally("water", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Water")
    }

    @Test
    func prefixMatch() {
        let result = parser.parseLocally("med", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Meditation")
    }

    @Test
    func containsMatch() {
        let result = parser.parseLocally("yoga", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Yoga")
    }

    @Test
    func directHabitName() {
        let result = parser.parseLocally("Exercise", habits: sampleHabits)
        #expect(result != nil)
        #expect(result?.matchedHabitID != nil)
        #expect(result?.habitName == "Exercise")
        #expect(result!.confidence >= 0.8)
    }

    @Test
    func abbreviationMed() {
        let match = parser.findBestMatch("med", in: sampleHabits)
        #expect(match != nil)
        #expect(match?.name == "Meditation")
    }

    @Test
    func abbreviationEx() {
        let match = parser.findBestMatch("ex", in: sampleHabits)
        #expect(match != nil)
        #expect(match?.name == "Exercise")
    }
}

// MARK: - Unit Normalization

@Suite("Unit Normalization")
struct UnitNormalizationTests {

    @Test
    func liters() {
        #expect(parser.normalizeUnit("l") == "L")
        #expect(parser.normalizeUnit("L") == "L")
        #expect(parser.normalizeUnit("liter") == "L")
        #expect(parser.normalizeUnit("liters") == "L")
        #expect(parser.normalizeUnit("litre") == "L")
    }

    @Test
    func hours() {
        #expect(parser.normalizeUnit("h") == "hours")
        #expect(parser.normalizeUnit("hr") == "hours")
        #expect(parser.normalizeUnit("hrs") == "hours")
        #expect(parser.normalizeUnit("hour") == "hours")
        #expect(parser.normalizeUnit("hours") == "hours")
    }

    @Test
    func minutes() {
        #expect(parser.normalizeUnit("m") == "min")
        #expect(parser.normalizeUnit("min") == "min")
        #expect(parser.normalizeUnit("mins") == "min")
        #expect(parser.normalizeUnit("minute") == "min")
        #expect(parser.normalizeUnit("minutes") == "min")
    }

    @Test
    func kilometers() {
        #expect(parser.normalizeUnit("k") == "km")
        #expect(parser.normalizeUnit("km") == "km")
        #expect(parser.normalizeUnit("kilometer") == "km")
    }

    @Test
    func unrecognizedUnit() {
        #expect(parser.normalizeUnit("zyx") == nil)
        #expect(parser.normalizeUnit("asdf") == nil)
    }

    @Test
    func pages() {
        #expect(parser.normalizeUnit("pg") == "pages")
        #expect(parser.normalizeUnit("page") == "pages")
        #expect(parser.normalizeUnit("pages") == "pages")
    }

    @Test
    func calories() {
        #expect(parser.normalizeUnit("cal") == "cal")
        #expect(parser.normalizeUnit("kcal") == "cal")
        #expect(parser.normalizeUnit("calories") == "cal")
    }
}

// MARK: - Edge Cases

@Suite("Edge Cases")
struct EdgeCaseTests {

    @Test
    func emptyString() {
        let result = parser.parseLocally("", habits: sampleHabits)
        #expect(result == nil)
    }

    @Test
    func whitespaceOnly() {
        let result = parser.parseLocally("   ", habits: sampleHabits)
        #expect(result == nil)
    }

    @Test
    func numbersOnly() {
        let result = parser.parseLocally("42", habits: sampleHabits)
        #expect(result == nil)
    }

    @Test
    func emojiOnly() {
        let result = parser.parseLocally("🧘", habits: sampleHabits)
        #expect(result == nil)
    }

    @Test
    func gibberish() {
        let result = parser.parseLocally("xyzzy plugh", habits: sampleHabits)
        #expect(result == nil)
    }

    @Test
    func noHabitsAvailable() {
        let result = parser.parseLocally("Drank 3L water", habits: [])
        // Should still parse the quantity, just no matched habit
        #expect(result != nil)
        #expect(result?.value == 3.0)
        #expect(result?.unit == "L")
        #expect(result?.matchedHabitID == nil)
        #expect(result!.confidence < 0.9)
    }

    @Test
    func rawInputPreserved() {
        let input = "Drank 3L water"
        let result = parser.parseLocally(input, habits: sampleHabits)
        #expect(result?.rawInput == input)
    }

    @Test
    func unrecognizedReturnsNil() {
        let result = parser.parseLocally("something completely unknown", habits: sampleHabits)
        #expect(result == nil)
    }
}

// MARK: - Async Parse

@Suite("Async Parse")
struct AsyncParseTests {

    @Test
    func asyncParseMatchesLocal() async {
        let result = await parser.parse("Drank 3L water", habits: sampleHabits)
        #expect(result.value == 3.0)
        #expect(result.unit == "L")
        #expect(result.matchedHabitID != nil)
    }

    @Test
    func asyncParseUnrecognized() async {
        let result = await parser.parse("xyzzy plugh", habits: sampleHabits)
        #expect(result.matchedHabitID == nil)
        #expect(result.confidence == 0)
    }
}
