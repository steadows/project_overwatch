import Foundation
import SwiftData

/// Owns all report generation logic. Uses GeminiService for AI-powered narrative
/// generation and manages the performance coach persona via RISEN-structured prompts.
@Observable
@MainActor
final class IntelligenceManager {

    // MARK: - State

    var isGenerating = false
    var lastError: String?
    var generationProgress: String?

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
        whoopMetrics: [WhoopDailyMetrics] = [],
        habitMetadata: [HabitMetadataItem] = [],
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
            whoopMetrics: whoopMetrics,
            habitMetadata: habitMetadata,
            correlations: correlations,
            forceMultiplierHabit: forceMultiplierHabit,
            dateRangeLabel: dateRangeLabel
        )

        do {
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

    // MARK: - Weekly Report Orchestration (Phase 7.2)

    /// Generates a complete weekly report by querying all data sources from SwiftData,
    /// packaging data as RISEN-structured XML, sending to Gemini, and persisting the result.
    func generateWeeklyReport(
        startDate: Date,
        endDate: Date,
        from context: ModelContext
    ) async throws -> WeeklyInsight {
        isGenerating = true
        generationProgress = "QUERYING DATA SOURCES..."
        defer { isGenerating = false; generationProgress = nil }

        let calendar = Calendar.current
        let totalDays = max(1, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 7)

        // --- Query SwiftData ---

        let habits = (try? context.fetch(FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []

        let allHabitEntries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []
        let rangeHabitEntries = allHabitEntries.filter {
            $0.date >= startDate && $0.date < endDate && $0.completed
        }

        let journalEntries = ((try? context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.date >= startDate && $0.date < endDate }

        let whoopCycles = ((try? context.fetch(FetchDescriptor<WhoopCycle>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.date >= startDate && $0.date < endDate }

        // Latest MonthlyAnalysis overlapping the report period
        let analyses = (try? context.fetch(FetchDescriptor<MonthlyAnalysis>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        ))) ?? []
        let relevantAnalysis = analyses.first { $0.startDate <= endDate && $0.endDate >= startDate }

        // --- Build data packages ---

        generationProgress = "PACKAGING INTEL..."

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        // Habit completions
        let habitCompletions: [HabitCompletionData] = habits.map { habit in
            let completed = rangeHabitEntries.filter { $0.habit?.id == habit.id }.count
            return HabitCompletionData(
                habitName: habit.name,
                emoji: habit.emoji,
                completedDays: completed,
                totalDays: totalDays,
                completionRate: Double(completed) / Double(totalDays)
            )
        }

        // Daily sentiment scores from journal entries
        let sentimentScores: [DailySentiment] = journalEntries.map { entry in
            DailySentiment(
                dateLabel: dateFormatter.string(from: entry.date),
                score: entry.sentimentScore,
                label: entry.sentimentLabel
            )
        }

        // WHOOP biometric metrics
        let whoopMetrics: [WhoopDailyMetrics] = whoopCycles.map { cycle in
            WhoopDailyMetrics(
                dateLabel: dateFormatter.string(from: cycle.date),
                recoveryScore: cycle.recoveryScore,
                strain: cycle.strain,
                sleepPerformance: cycle.sleepPerformance,
                hrvRmssdMilli: cycle.hrvRmssdMilli,
                restingHeartRate: cycle.restingHeartRate
            )
        }

        // Habit metadata for context
        let habitMetadata: [HabitMetadataItem] = habits.map { habit in
            HabitMetadataItem(
                name: habit.name,
                emoji: habit.emoji,
                category: habit.category,
                targetFrequency: habit.targetFrequency
            )
        }

        // Correlations and force multiplier from regression
        let correlations = relevantAnalysis?.habitCoefficients ?? []
        let forceMultiplier = relevantAnalysis?.forceMultiplierHabit

        // --- Compute sentiment summary (6.5.13 integration) ---

        let avgSentiment: Double? = journalEntries.isEmpty ? nil :
            journalEntries.map(\.sentimentScore).reduce(0, +) / Double(journalEntries.count)

        let computedSentimentTrend: String?
        if journalEntries.count >= 2 {
            let midpoint = journalEntries.count / 2
            let firstAvg = journalEntries.prefix(midpoint).map(\.sentimentScore).reduce(0, +)
                / Double(midpoint)
            let secondAvg = journalEntries.suffix(from: midpoint).map(\.sentimentScore).reduce(0, +)
                / Double(journalEntries.count - midpoint)
            let delta = secondAvg - firstAvg
            computedSentimentTrend = delta > 0.05 ? "improving" : delta < -0.05 ? "declining" : "stable"
        } else {
            computedSentimentTrend = journalEntries.isEmpty ? nil : "stable"
        }

        // --- Generate AI narrative ---

        generationProgress = "COMPILING INTELLIGENCE BRIEFING..."

        let rangeLabel = "\(dateFormatter.string(from: startDate)) — \(dateFormatter.string(from: endDate))"

        let response = try await generateWeeklyNarrative(
            habitCompletions: habitCompletions,
            sentimentScores: sentimentScores,
            whoopMetrics: whoopMetrics,
            habitMetadata: habitMetadata,
            correlations: correlations,
            forceMultiplierHabit: forceMultiplier,
            dateRangeLabel: rangeLabel
        )

        // --- Persist WeeklyInsight ---

        generationProgress = "ARCHIVING BRIEFING..."

        let insight = WeeklyInsight(
            dateRangeStart: startDate,
            dateRangeEnd: endDate,
            summary: response.summary,
            forceMultiplierHabit: response.forceMultiplierHabit,
            recommendations: response.recommendations,
            correlations: correlations,
            averageSentiment: avgSentiment,
            sentimentTrend: response.sentimentTrend ?? computedSentimentTrend,
            generatedAt: .now
        )

        context.insert(insight)
        return insight
    }

    // MARK: - Auto-Generation Scheduling

    /// Checks whether a scheduled weekly report should be auto-generated.
    /// Call on app launch / foreground. Reads schedule from UserDefaults.
    /// Skips if auto-generate is disabled or a report already exists for this week.
    func checkAutoGenerate(from context: ModelContext) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "settings_autoGenerateReports") else { return }

        let scheduledDay = defaults.integer(forKey: "settings_reportDayOfWeek")
        let day = scheduledDay > 0 ? scheduledDay : 1 // default Sunday
        let hour = defaults.integer(forKey: "settings_reportHour")
        let minute = defaults.integer(forKey: "settings_reportMinute")

        let calendar = Calendar.current
        let now = Date.now

        // Find the most recent scheduled time
        let currentWeekday = calendar.component(.weekday, from: now)
        var daysBack = currentWeekday - day
        if daysBack < 0 { daysBack += 7 }

        guard let scheduledDate = calendar.date(byAdding: .day, value: -daysBack, to: now) else { return }
        var scheduledComponents = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        scheduledComponents.hour = hour
        scheduledComponents.minute = minute
        guard let scheduledTime = calendar.date(from: scheduledComponents) else { return }

        // Only generate if we're past the scheduled time
        guard now >= scheduledTime else { return }

        // Compute the week range (7 days ending at the scheduled date)
        let weekStart = calendar.startOfDay(for: scheduledDate)
        guard let weekRangeStart = calendar.date(byAdding: .day, value: -7, to: weekStart) else { return }

        // Check if we already have a report covering this period
        let existingDescriptor = FetchDescriptor<WeeklyInsight>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        let existingReports = (try? context.fetch(existingDescriptor)) ?? []
        let alreadyGenerated = existingReports.contains { insight in
            insight.dateRangeStart == weekRangeStart && insight.dateRangeEnd == weekStart
        }
        guard !alreadyGenerated else { return }

        _ = try? await generateWeeklyReport(
            startDate: weekRangeStart,
            endDate: weekStart,
            from: context
        )
    }

    // MARK: - RISEN Prompt Builder

    private func buildWeeklyBriefingPrompt(
        habitCompletions: [HabitCompletionData],
        sentimentScores: [DailySentiment],
        whoopMetrics: [WhoopDailyMetrics] = [],
        habitMetadata: [HabitMetadataItem] = [],
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

        let hasWhoop = !whoopMetrics.isEmpty

        let whoopJSON = whoopMetrics.map { m in
            """
            {"date": "\(m.dateLabel)", "recovery": \(String(format: "%.1f", m.recoveryScore)), \
            "strain": \(String(format: "%.1f", m.strain)), \
            "sleepPerformance": \(String(format: "%.1f", m.sleepPerformance)), \
            "hrvMilli": \(String(format: "%.1f", m.hrvRmssdMilli)), \
            "restingHR": \(String(format: "%.1f", m.restingHeartRate))}
            """
        }.joined(separator: ",\n")

        let metadataJSON = habitMetadata.map { h in
            """
            {"name": "\(h.name)", "emoji": "\(h.emoji)", "category": "\(h.category)", \
            "targetFrequency": \(h.targetFrequency)}
            """
        }.joined(separator: ",\n")

        let whoopInstruction = hasWhoop
            ? " and WHOOP biometric data (recovery, strain, sleep, HRV)"
            : ""

        let whoopStep = hasWhoop
            ? "\n        3. Analyze WHOOP recovery and sleep patterns — correlate with habit completions."
            : ""

        let whoopExpectation = hasWhoop
            ? " Reference specific WHOOP metrics (recovery %, strain, HRV) when available."
            : ""

        var dataSections = """
        <habit_completions>
        [\(completionsJSON)]
        </habit_completions>

        <sentiment_data>
        {"dailyScores": [\(sentimentJSON)], "weeklyAverage": \(String(format: "%.3f", avgSentiment)), \
        "entryCount": \(sentimentScores.count), "period": "\(dateRangeLabel)"}
        </sentiment_data>
        """

        if hasWhoop {
            dataSections += """

            <whoop_metrics>
            [\(whoopJSON)]
            </whoop_metrics>
            """
        }

        if !habitMetadata.isEmpty {
            dataSections += """

            <habit_metadata>
            [\(metadataJSON)]
            </habit_metadata>
            """
        }

        if !correlations.isEmpty {
            dataSections += """

            <monthly_regression>
            {"forceMultiplier": "\(fmName)", "coefficients": [\(coeffJSON)]}
            </monthly_regression>
            """
        } else {
            dataSections += """

            <habit_correlations>
            [\(coeffJSON)]
            </habit_correlations>
            """
        }

        dataSections += """

        <force_multiplier>
        \(fmName)
        </force_multiplier>
        """

        return """
        <role>
        You are a performance coach who analyzes habit and wellbeing data. You are encouraging \
        but honest, data-driven, and always actionable. You speak directly to the user as "you." \
        You reference specific numbers from the data and name habits by name.
        </role>

        <instructions>
        Analyze the following weekly habit completion, sentiment,\(whoopInstruction) and correlation data. \
        Produce a structured intelligence briefing for the week of \(dateRangeLabel). The briefing must include:
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
        2. Analyze daily sentiment scores — look for patterns, trends, and outliers.\(whoopStep)
        \(hasWhoop ? "4" : "3"). Cross-reference correlations to identify which habits most influence mood\(hasWhoop ? " and recovery" : "").
        \(hasWhoop ? "5" : "4"). Highlight the force multiplier habit with specific data (completion rate, coefficient).
        \(hasWhoop ? "6" : "5"). Assess whether sentiment is improving, declining, or stable over the period.
        \(hasWhoop ? "7" : "6"). Generate 3-5 concrete, actionable recommendations grounded in the data.
        \(hasWhoop ? "8" : "7"). Write the narrative summary weaving together habits, sentiment,\(hasWhoop ? " biometrics," : "") and recommendations.
        </steps>

        <expectations>
        Respond ONLY with the <weekly_report> XML structure described above. The summary should be \
        2-3 paragraphs of narrative prose — no bullet points or numbered lists in the summary. \
        Use a motivational but data-grounded tone. Reference specific habit names, completion rates, \
        and sentiment scores.\(whoopExpectation) Each recommendation must be a single, actionable sentence. \
        Keep the total response under 400 words. The sentiment_trend must be exactly one of: \
        "improving", "declining", or "stable".
        </expectations>

        <narrowing>
        Do not invent data points not present in the input. Do not provide medical advice. \
        Do not reference habits not included in the data. Do not use generic platitudes — \
        every sentence should reference specific data from the input. Do not include any \
        text outside the <weekly_report> XML tags.
        </narrowing>

        \(dataSections)
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

/// WHOOP biometric data for a single day, passed to the RISEN prompt.
struct WhoopDailyMetrics: Sendable {
    let dateLabel: String
    let recoveryScore: Double
    let strain: Double
    let sleepPerformance: Double
    let hrvRmssdMilli: Double
    let restingHeartRate: Double
}

/// Habit metadata for context in the RISEN prompt.
struct HabitMetadataItem: Sendable {
    let name: String
    let emoji: String
    let category: String
    let targetFrequency: Int
}
