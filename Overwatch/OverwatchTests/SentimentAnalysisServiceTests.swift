import Testing
import Foundation
@testable import Overwatch

// MARK: - SentimentResult

@Suite("SentimentResult")
struct SentimentResultTests {

    @Test
    func neutralConstant() {
        let neutral = SentimentResult.neutral
        #expect(neutral.score == 0.0)
        #expect(neutral.label == .neutral)
        #expect(neutral.magnitude == 0.0)
    }

    @Test
    func labelRawValues() {
        #expect(SentimentResult.SentimentLabel.positive.rawValue == "positive")
        #expect(SentimentResult.SentimentLabel.negative.rawValue == "negative")
        #expect(SentimentResult.SentimentLabel.neutral.rawValue == "neutral")
    }
}

// MARK: - SentimentAnalysisService

@Suite("SentimentAnalysisService")
struct SentimentAnalysisServiceTests {

    let service = SentimentAnalysisService()

    @Test
    func emptyText() async {
        let result = await service.analyzeSentiment("")
        #expect(result.score == 0.0)
        #expect(result.label == .neutral)
        #expect(result.magnitude == 0.0)
    }

    @Test
    func shortText() async {
        let result = await service.analyzeSentiment("Hi")
        #expect(result.label == .neutral)
        #expect(result.magnitude == 0.0)
    }

    @Test
    func whitespaceOnly() async {
        let result = await service.analyzeSentiment("     \n\t   ")
        #expect(result.label == .neutral)
    }

    @Test
    func knownPositivePhrase() async {
        let result = await service.analyzeSentiment("I am so happy and excited about this wonderful amazing day!")
        #expect(result.score > 0.0)
        #expect(result.label == .positive)
        #expect(result.magnitude > 0.0)
    }

    @Test
    func knownNegativePhrase() async {
        let result = await service.analyzeSentiment("This is absolutely terrible and I feel awful about everything going wrong today.")
        #expect(result.score < 0.0)
        #expect(result.label == .negative)
        #expect(result.magnitude > 0.0)
    }

    @Test
    func scoreRange() async {
        let result = await service.analyzeSentiment("The weather today is quite nice and pleasant, I enjoyed my walk through the park.")
        #expect(result.score >= -1.0)
        #expect(result.score <= 1.0)
        #expect(result.magnitude >= 0.0)
        #expect(result.magnitude <= 1.0)
    }

    @Test
    func magnitudeEqualsAbsScore() async {
        let result = await service.analyzeSentiment("I had a really great experience at the conference today, learned a lot.")
        #expect(result.magnitude == abs(result.score))
    }

    @Test
    func multiParagraph() async {
        let text = """
        Today was a mixed bag. The morning started rough with a missed alarm \
        and a spilled coffee. But the afternoon was great — nailed the presentation \
        and got positive feedback from the team. Overall feeling cautiously optimistic.
        """
        let result = await service.analyzeSentiment(text)
        // Multi-paragraph text should still produce a valid result
        #expect(result.score >= -1.0)
        #expect(result.score <= 1.0)
    }
}
