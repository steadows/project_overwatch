import Foundation

/// Owns all report generation logic. Uses GeminiService for AI-powered narrative
/// generation and manages the performance coach persona via RISEN-structured prompts.
@Observable
@MainActor
final class IntelligenceManager {

    // MARK: - State

    var isGenerating = false
    var lastError: String?

    // MARK: - Dependencies

    private let geminiService: GeminiService?

    init(geminiService: GeminiService? = GeminiService.create()) {
        self.geminiService = geminiService
    }

    // MARK: - Weekly Insight Generation

    /// Sends weekly data to Gemini for a structured intelligence briefing using RISEN framework.
    ///
    /// Returns a parsed `WeeklyInsightResponse` containing summary, recommendations,
    /// force multiplier, and sentiment analysis. Falls back to template when Gemini is unavailable.
    func generateWeeklyNarrative(
        habitCompletions: [HabitCompletionData],
        sentimentScores: [DailySentiment],
        correlations: [HabitCoefficient],
        forceMultiplierHabit: String?,
        dateRangeLabel: String
    ) async throws -> WeeklyInsightResponse {
        guard let service = geminiService else {
            return Self.weeklyFallback(
                habitCompletions: habitCompletions,
                sentimentScores: sentimentScores,
                correlations: correlations,
                forceMultiplierHabit: forceMultiplierHabit,
                dateRangeLabel: dateRangeLabel
            )
        }

        let prompt = buildWeeklyBriefingPrompt(
            habitCompletions: habitCompletions,
            sentimentScores: sentimentScores,
            correlations: correlations,
            forceMultiplierHabit: forceMultiplierHabit,
            dateRangeLabel: dateRangeLabel
        )

        do {
            isGenerating = true
            defer { isGenerating = false }

            let text = try await service.generateWeeklyBriefing(prompt: prompt)
            return parseWeeklyResponse(text) ?? Self.weeklyFallback(
                habitCompletions: habitCompletions,
                sentimentScores: sentimentScores,
                correlations: correlations,
                forceMultiplierHabit: forceMultiplierHabit,
                dateRangeLabel: dateRangeLabel
            )
        } catch {
            lastError = error.localizedDescription
            return Self.weeklyFallback(
                habitCompletions: habitCompletions,
                sentimentScores: sentimentScores,
                correlations: correlations,
                forceMultiplierHabit: forceMultiplierHabit,
                dateRangeLabel: dateRangeLabel
            )
        }
    }

    // MARK: - RISEN Prompt Builder

    private func buildWeeklyBriefingPrompt(
        habitCompletions: [HabitCompletionData],
        sentimentScores: [DailySentiment],
        correlations: [HabitCoefficient],
        forceMultiplierHabit: String?,
        dateRangeLabel: String
    ) -> String {
        let completionsJSON = habitCompletions.map { habit in
            """
            {"habitName": "\(habit.habitName)", "emoji": "\(habit.emoji)", \
            "completedDays": \(habit.completedDays), "totalDays": \(habit.totalDays), \
            "completionRate": \(String(format: "%.2f", habit.completionRate))}
            """
        }.joined(separator: ",\n")

        let sentimentJSON = sentimentScores.map { day in
            """
            {"date": "\(day.dateLabel)", "score": \(String(format: "%.3f", day.score)), \
            "label": "\(day.label)"}
            """
        }.joined(separator: ",\n")

        let coeffJSON = correlations.map { coeff in
            """
            {"habitName": "\(coeff.habitName)", "emoji": "\(coeff.habitEmoji)", \
            "coefficient": \(String(format: "%.4f", coeff.coefficient)), \
            "direction": "\(coeff.direction.rawValue)", \
            "completionRate": \(String(format: "%.2f", coeff.completionRate))}
            """
        }.joined(separator: ",\n")

        let avgSentiment: Double = sentimentScores.isEmpty
            ? 0.0
            : sentimentScores.reduce(0.0) { $0 + $1.score } / Double(sentimentScores.count)

        let fmName = forceMultiplierHabit ?? "none identified"

        return """
        <role>
        You are a performance coach who analyzes habit and wellbeing data. You are encouraging \
        but honest, data-driven, and always actionable. You speak directly to the user as "you." \
        You reference specific numbers from the data and name habits by name.
        </role>

        <instructions>
        Analyze the following weekly habit completion, sentiment, and correlation data. Produce a \
        structured intelligence briefing for the week of \(dateRangeLabel). The briefing must include:
        1. A 2-3 paragraph narrative summary
        2. The force multiplier habit (highest positive impact on wellbeing)
        3. Exactly 3-5 actionable recommendations
        4. A sentiment trend assessment ("improving", "declining", or "stable")

        Wrap your entire response in a <weekly_report> XML tag with the following structure:
        <weekly_report>
        <summary>Your 2-3 paragraph narrative here</summary>
        <force_multiplier>habit name</force_multiplier>
        <recommendations>
        <rec>First recommendation</rec>
        <rec>Second recommendation</rec>
        <rec>Third recommendation</rec>
        </recommendations>
        <sentiment_trend>improving|declining|stable</sentiment_trend>
        </weekly_report>
        </instructions>

        <steps>
        1. Review habit completion rates and identify standout performers and gaps.
        2. Analyze daily sentiment scores — look for patterns, trends, and outliers.
        3. Cross-reference correlations to identify which habits most influence mood.
        4. Highlight the force multiplier habit with specific data (completion rate, coefficient).
        5. Assess whether sentiment is improving, declining, or stable over the period.
        6. Generate 3-5 concrete, actionable recommendations grounded in the data.
        7. Write the narrative summary weaving together habits, sentiment, and recommendations.
        </steps>

        <expectations>
        Respond ONLY with the <weekly_report> XML structure described above. The summary should be \
        2-3 paragraphs of narrative prose — no bullet points or numbered lists in the summary. \
        Use a motivational but data-grounded tone. Reference specific habit names, completion rates, \
        and sentiment scores. Each recommendation must be a single, actionable sentence. \
        Keep the total response under 400 words. The sentiment_trend must be exactly one of: \
        "improving", "declining", or "stable".
        </expectations>

        <narrowing>
        Do not invent data points not present in the input. Do not provide medical advice. \
        Do not reference habits not included in the data. Do not use generic platitudes — \
        every sentence should reference specific data from the input. Do not include any \
        text outside the <weekly_report> XML tags.
        </narrowing>

        <habit_completions>
        [\(completionsJSON)]
        </habit_completions>

        <sentiment_data>
        {"dailyScores": [\(sentimentJSON)], "weeklyAverage": \(String(format: "%.3f", avgSentiment)), \
        "entryCount": \(sentimentScores.count), "period": "\(dateRangeLabel)"}
        </sentiment_data>

        <habit_correlations>
        [\(coeffJSON)]
        </habit_correlations>

        <force_multiplier>
        \(fmName)
        </force_multiplier>
        """
    }

    // MARK: - Response Parsing

    private func parseWeeklyResponse(_ text: String) -> WeeklyInsightResponse? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let summaryContent = extractXMLContent(from: cleaned, tag: "summary") else {
            return nil
        }

        let forceMultiplier = extractXMLContent(from: cleaned, tag: "force_multiplier")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let recommendations = extractAllXMLContent(from: cleaned, tag: "rec")

        let sentimentTrend = extractXMLContent(from: cleaned, tag: "sentiment_trend")?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !summaryContent.isEmpty, !recommendations.isEmpty else {
            return nil
        }

        return WeeklyInsightResponse(
            summary: summaryContent.trimmingCharacters(in: .whitespacesAndNewlines),
            forceMultiplierHabit: forceMultiplier,
            recommendations: recommendations,
            sentimentTrend: sentimentTrend
        )
    }

    private func extractXMLContent(from text: String, tag: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private func extractAllXMLContent(from text: String, tag: String) -> [String] {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return []
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Template Fallback

    static func weeklyFallback(
        habitCompletions: [HabitCompletionData],
        sentimentScores: [DailySentiment],
        correlations: [HabitCoefficient],
        forceMultiplierHabit: String?,
        dateRangeLabel: String
    ) -> WeeklyInsightResponse {
        let sorted = correlations.sorted { $0.coefficient > $1.coefficient }
        let forceMultiplier = sorted.first(where: { $0.direction == .positive })
        let detractor = sorted.last(where: { $0.direction == .negative })

        let avgSentiment: Double = sentimentScores.isEmpty
            ? 0.0
            : sentimentScores.reduce(0.0) { $0 + $1.score } / Double(sentimentScores.count)

        let sentimentLabel: String
        if avgSentiment > 0.2 { sentimentLabel = "positive" }
        else if avgSentiment > 0.05 { sentimentLabel = "slightly positive" }
        else if avgSentiment > -0.05 { sentimentLabel = "neutral" }
        else if avgSentiment > -0.2 { sentimentLabel = "slightly negative" }
        else { sentimentLabel = "negative" }

        // Compute trend from daily scores
        let trend: String
        if sentimentScores.count >= 3 {
            let midpoint = sentimentScores.count / 2
            let firstHalf = sentimentScores.prefix(midpoint).reduce(0.0) { $0 + $1.score } / Double(midpoint)
            let secondHalf = sentimentScores.suffix(from: midpoint).reduce(0.0) { $0 + $1.score }
                / Double(sentimentScores.count - midpoint)
            let delta = secondHalf - firstHalf
            if delta > 0.1 { trend = "improving" }
            else if delta < -0.1 { trend = "declining" }
            else { trend = "stable" }
        } else {
            trend = "stable"
        }

        // Build summary
        var paragraphs: [String] = []

        let topHabits = habitCompletions
            .sorted { $0.completionRate > $1.completionRate }
            .prefix(3)
            .map { "\($0.emoji) \($0.habitName) (\(Int($0.completionRate * 100))%)" }
            .joined(separator: ", ")

        paragraphs.append(
            "Here's your \(dateRangeLabel) briefing. " +
            "Your overall sentiment averaged \(String(format: "%.2f", avgSentiment)) " +
            "(\(sentimentLabel)) across \(sentimentScores.count) journal entries. " +
            (topHabits.isEmpty ? "" : "Your top habits by completion: \(topHabits).")
        )

        var p2 = ""
        if let fm = forceMultiplier {
            p2 += "\(fm.habitEmoji) \(fm.habitName) was your force multiplier this period " +
                  "with a coefficient of \(String(format: "+%.3f", fm.coefficient)), " +
                  "meaning days you completed it tended to have noticeably higher mood scores. "
        }
        if let det = detractor {
            p2 += "On the flip side, \(det.habitEmoji) \(det.habitName) showed a negative correlation " +
                  "(\(String(format: "%.3f", det.coefficient))), worth examining."
        }
        if p2.isEmpty {
            p2 = "No single habit dominated as a wellbeing driver this period. " +
                 "Consistency across your routines is likely maintaining a stable baseline."
        }
        paragraphs.append(p2)

        let summary = paragraphs.joined(separator: "\n\n")

        // Build recommendations
        var recs: [String] = []
        if let fm = forceMultiplier {
            recs.append(
                "Prioritize \(fm.habitName) — your completion rate was " +
                "\(Int(fm.completionRate * 100))%, and increasing it could boost wellbeing."
            )
        }
        if let det = detractor {
            recs.append(
                "Re-evaluate \(det.habitName) — consider adjusting timing or frequency."
            )
        }
        let lowCompletionHabits = habitCompletions
            .filter { $0.completionRate < 0.5 }
            .prefix(2)
        for habit in lowCompletionHabits {
            recs.append(
                "Boost \(habit.habitName) consistency (currently \(Int(habit.completionRate * 100))%)."
            )
        }
        if recs.count < 3 {
            recs.append("Keep up your current momentum — consistency compounds over time.")
        }

        return WeeklyInsightResponse(
            summary: summary,
            forceMultiplierHabit: forceMultiplierHabit ?? forceMultiplier?.habitName ?? "",
            recommendations: recs,
            sentimentTrend: trend
        )
    }
}

// MARK: - Supporting Types

/// Data passed to IntelligenceManager for habit completion context.
struct HabitCompletionData: Sendable {
    let habitName: String
    let emoji: String
    let completedDays: Int
    let totalDays: Int
    let completionRate: Double
}

/// Data passed to IntelligenceManager for daily sentiment context.
struct DailySentiment: Sendable {
    let dateLabel: String
    let score: Double
    let label: String
}

/// Structured response from Gemini weekly briefing generation.
struct WeeklyInsightResponse: Sendable {
    let summary: String
    let forceMultiplierHabit: String
    let recommendations: [String]
    let sentimentTrend: String?
}
