import Foundation
import Observation
import SwiftData

/// ViewModel for the Journal page — entry CRUD, live sentiment scoring,
/// trend visualization, filtering, and monthly regression analysis.
@MainActor
@Observable
final class JournalViewModel {

    // MARK: - Display Types

    struct JournalItem: Identifiable, Equatable {
        let id: UUID
        let date: Date
        let title: String
        let contentPreview: String
        let wordCount: Int
        let sentimentScore: Double
        let sentimentLabel: String
        let tags: [String]
        let createdAt: Date
    }

    struct SentimentDataPoint: Identifiable, Equatable {
        let id: Date
        let date: Date
        let score: Double
    }

    struct MonthlyAnalysisItem: Identifiable, Equatable {
        let id: UUID
        let month: Int
        let year: Int
        let monthLabel: String
        let averageSentiment: Double
        let entryCount: Int
        let forceMultiplierHabit: String
        let modelR2: Double
        let summary: String
        let coefficients: [HabitCoefficient]
        let generatedAt: Date
    }

    // MARK: - Filter

    enum DateFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case week = "7 DAYS"
        case month = "30 DAYS"
        case threeMonths = "90 DAYS"

        var id: String { rawValue }

        var dayCount: Int? {
            switch self {
            case .all: nil
            case .week: 7
            case .month: 30
            case .threeMonths: 90
            }
        }
    }

    enum SentimentFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case positive = "+"
        case negative = "-"
        case neutral = "~"

        var id: String { rawValue }
    }

    // MARK: - Dependencies

    private let sentimentService: SentimentAnalysisService
    private let regressionService: RegressionService

    // MARK: - State

    var entries: [JournalItem] = []
    var selectedEntryID: UUID?
    var editorTitle: String = ""
    var editorContent: String = ""
    var editorTags: [String] = []
    var isEditing: Bool = false
    var editingEntryID: UUID?

    var currentSentiment: SentimentResult = .neutral
    var sentimentTrend: [SentimentDataPoint] = []

    var dateFilter: DateFilter = .all
    var sentimentFilter: SentimentFilter = .all
    var searchText: String = ""

    var latestAnalysis: MonthlyAnalysisItem?
    var isGeneratingAnalysis: Bool = false

    private var sentimentDebounceTask: Task<Void, Never>?

    // MARK: - Computed

    var filteredEntries: [JournalItem] {
        var result = entries

        // Date filter
        if let dayCount = dateFilter.dayCount {
            let cutoff = Calendar.current.date(
                byAdding: .day, value: -dayCount, to: Calendar.current.startOfDay(for: .now)
            )!
            result = result.filter { $0.date >= cutoff }
        }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.contentPreview.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }

        // Sentiment filter
        switch sentimentFilter {
        case .all: break
        case .positive: result = result.filter { $0.sentimentLabel == "positive" }
        case .negative: result = result.filter { $0.sentimentLabel == "negative" }
        case .neutral: result = result.filter { $0.sentimentLabel == "neutral" }
        }

        return result
    }

    var selectedEntry: JournalItem? {
        guard let id = selectedEntryID else { return nil }
        return entries.first { $0.id == id }
    }

    // MARK: - Init

    init(
        sentimentService: SentimentAnalysisService = SentimentAnalysisService(),
        regressionService: RegressionService = RegressionService()
    ) {
        self.sentimentService = sentimentService
        self.regressionService = regressionService
    }

    // MARK: - Data Loading

    func loadEntries(from context: ModelContext) {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let allEntries = try? context.fetch(descriptor) else {
            entries = []
            return
        }

        entries = allEntries.map { entry in
            JournalItem(
                id: entry.id,
                date: entry.date,
                title: entry.title.isEmpty ? titleFromContent(entry.content) : entry.title,
                contentPreview: String(entry.content.prefix(120)),
                wordCount: entry.wordCount,
                sentimentScore: entry.sentimentScore,
                sentimentLabel: entry.sentimentLabel,
                tags: entry.tags,
                createdAt: entry.createdAt
            )
        }
    }

    // MARK: - Sentiment Trend

    func loadSentimentTrend(from context: ModelContext) {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date)]
        )
        guard let allEntries = try? context.fetch(descriptor) else {
            sentimentTrend = []
            return
        }

        sentimentTrend = allEntries.map { entry in
            SentimentDataPoint(
                id: entry.date,
                date: entry.date,
                score: entry.sentimentScore
            )
        }
    }

    // MARK: - Entry CRUD

    func startNewEntry() {
        selectedEntryID = nil
        editingEntryID = nil
        editorTitle = ""
        editorContent = ""
        editorTags = []
        currentSentiment = .neutral
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        editingEntryID = nil
        editorTitle = ""
        editorContent = ""
        editorTags = []
        currentSentiment = .neutral
    }

    func selectEntry(_ id: UUID, from context: ModelContext) {
        selectedEntryID = id

        let descriptor = FetchDescriptor<JournalEntry>()
        guard let allEntries = try? context.fetch(descriptor),
              let entry = allEntries.first(where: { $0.id == id }) else { return }

        editingEntryID = entry.id
        editorTitle = entry.title
        editorContent = entry.content
        editorTags = entry.tags
        currentSentiment = SentimentResult(
            score: entry.sentimentScore,
            label: SentimentResult.SentimentLabel(rawValue: entry.sentimentLabel) ?? .neutral,
            magnitude: entry.sentimentMagnitude
        )
        isEditing = true
    }

    func saveEntry(in context: ModelContext) async {
        let content = editorContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        // Analyze sentiment
        let sentiment = await sentimentService.analyzeSentiment(content)
        let wordCount = content.split(separator: " ").count
        let title = editorTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingID = editingEntryID {
            // Update existing entry
            let descriptor = FetchDescriptor<JournalEntry>()
            guard let allEntries = try? context.fetch(descriptor),
                  let entry = allEntries.first(where: { $0.id == existingID }) else { return }

            entry.title = title
            entry.content = content
            entry.wordCount = wordCount
            entry.sentimentScore = sentiment.score
            entry.sentimentLabel = sentiment.label.rawValue
            entry.sentimentMagnitude = sentiment.magnitude
            entry.tags = editorTags
            entry.updatedAt = .now
        } else {
            // Create new entry
            let entry = JournalEntry(
                content: content,
                sentimentScore: sentiment.score,
                sentimentLabel: sentiment.label.rawValue,
                sentimentMagnitude: sentiment.magnitude,
                title: title,
                wordCount: wordCount,
                tags: editorTags
            )
            context.insert(entry)
            selectedEntryID = entry.id
        }

        isEditing = false
        editingEntryID = nil
        currentSentiment = .neutral
        loadEntries(from: context)
        loadSentimentTrend(from: context)
    }

    func deleteEntry(_ id: UUID, from context: ModelContext) {
        let descriptor = FetchDescriptor<JournalEntry>()
        guard let allEntries = try? context.fetch(descriptor),
              let entry = allEntries.first(where: { $0.id == id }) else { return }

        context.delete(entry)

        if selectedEntryID == id {
            selectedEntryID = nil
            isEditing = false
            editingEntryID = nil
        }

        loadEntries(from: context)
        loadSentimentTrend(from: context)
    }

    // MARK: - Live Sentiment Analysis (Debounced)

    func analyzeSentimentLive() async {
        sentimentDebounceTask?.cancel()

        let content = editorContent
        sentimentDebounceTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            let result = await sentimentService.analyzeSentiment(content)
            guard !Task.isCancelled else { return }
            currentSentiment = result
        }
    }

    // MARK: - Monthly Analysis

    func generateMonthlyAnalysis(for date: Date, from context: ModelContext) async {
        guard !isGeneratingAnalysis else { return }
        isGeneratingAnalysis = true
        defer { isGeneratingAnalysis = false }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .year], from: date)
        guard let month = components.month, let year = components.year else { return }

        let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        guard let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else { return }

        // Fetch journal entries for the month
        let entryDescriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date)]
        )
        guard let allEntries = try? context.fetch(entryDescriptor) else { return }
        let monthEntries = allEntries.filter { $0.date >= startDate && $0.date < endDate }

        guard monthEntries.count >= 14 else { return }

        // Fetch habits for the regression matrix
        let habitDescriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        guard let habits = try? context.fetch(habitDescriptor), !habits.isEmpty else { return }

        // Build regression input
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 30
        let habitNames = habits.map(\.name)
        let habitEmojis = habits.map(\.emoji)

        // Build day-by-day data
        var featureMatrix = [Double](repeating: 0.0, count: dayCount * habits.count)
        var targetVector = [Double](repeating: 0.0, count: dayCount)
        var completionCounts = [Int](repeating: 0, count: habits.count)
        var validDays = 0

        for dayOffset in 0..<dayCount {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            // Sentiment target: average of entries for this day
            let dayEntries = monthEntries.filter { $0.date >= dayStart && $0.date < dayEnd }
            guard !dayEntries.isEmpty else { continue }

            let avgSentiment = dayEntries.map(\.sentimentScore).reduce(0, +) / Double(dayEntries.count)
            targetVector[dayOffset] = avgSentiment
            validDays += 1

            // Habit features: did each habit get completed today?
            for (habitIdx, habit) in habits.enumerated() {
                let completed = habit.entries.contains { entry in
                    entry.completed && calendar.isDate(entry.date, inSameDayAs: dayDate)
                }
                let value = completed ? 1.0 : 0.0
                featureMatrix[habitIdx * dayCount + dayOffset] = value
                if completed { completionCounts[habitIdx] += 1 }
            }
        }

        let completionRates = completionCounts.map { Double($0) / max(1, Double(validDays)) }

        let input = RegressionInput(
            habitNames: habitNames,
            habitEmojis: habitEmojis,
            featureMatrix: featureMatrix,
            targetVector: targetVector,
            completionRates: completionRates
        )

        // Run regression
        guard let output = regressionService.computeRegression(input) else { return }

        let avgSentiment = monthEntries.map(\.sentimentScore).reduce(0, +) / Double(monthEntries.count)
        let forceMultiplier = output.coefficients
            .filter { $0.direction == .positive }
            .max(by: { $0.coefficient < $1.coefficient })

        // Generate summary via Gemini or template fallback
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthLabel = monthFormatter.string(from: startDate)

        let summary: String
        if let gemini = GeminiService.create() {
            summary = (try? await gemini.interpretRegressionResults(
                coefficients: output.coefficients,
                averageSentiment: avgSentiment,
                monthName: monthLabel,
                entryCount: monthEntries.count
            )) ?? GeminiService.templateFallback(
                coefficients: output.coefficients,
                averageSentiment: avgSentiment,
                monthName: monthLabel,
                entryCount: monthEntries.count
            )
        } else {
            summary = GeminiService.templateFallback(
                coefficients: output.coefficients,
                averageSentiment: avgSentiment,
                monthName: monthLabel,
                entryCount: monthEntries.count
            )
        }

        // Check for existing analysis for this month
        let analysisDescriptor = FetchDescriptor<MonthlyAnalysis>()
        let existingAnalyses = (try? context.fetch(analysisDescriptor)) ?? []
        let existing = existingAnalyses.first { $0.month == month && $0.year == year }

        if let existing {
            existing.habitCoefficients = output.coefficients
            existing.forceMultiplierHabit = forceMultiplier?.habitName ?? ""
            existing.modelR2 = output.r2
            existing.averageSentiment = avgSentiment
            existing.entryCount = monthEntries.count
            existing.summary = summary
            existing.generatedAt = .now
        } else {
            let analysis = MonthlyAnalysis(
                month: month,
                year: year,
                startDate: startDate,
                endDate: endDate,
                habitCoefficients: output.coefficients,
                forceMultiplierHabit: forceMultiplier?.habitName ?? "",
                modelR2: output.r2,
                averageSentiment: avgSentiment,
                entryCount: monthEntries.count,
                summary: summary,
                generatedAt: .now
            )
            context.insert(analysis)
        }

        // Update latest analysis state
        loadLatestAnalysis(from: context)
    }

    func loadLatestAnalysis(from context: ModelContext) {
        let descriptor = FetchDescriptor<MonthlyAnalysis>(
            sortBy: [SortDescriptor(\.year, order: .reverse), SortDescriptor(\.month, order: .reverse)]
        )
        guard let analyses = try? context.fetch(descriptor),
              let latest = analyses.first else {
            latestAnalysis = nil
            return
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        latestAnalysis = MonthlyAnalysisItem(
            id: latest.id,
            month: latest.month,
            year: latest.year,
            monthLabel: monthFormatter.string(from: latest.startDate),
            averageSentiment: latest.averageSentiment,
            entryCount: latest.entryCount,
            forceMultiplierHabit: latest.forceMultiplierHabit,
            modelR2: latest.modelR2,
            summary: latest.summary,
            coefficients: latest.habitCoefficients,
            generatedAt: latest.generatedAt
        )
    }

    // MARK: - Report Data Packaging (Phase 7.2)

    struct ReportSentimentData: Sendable {
        let averageSentiment: Double
        let trendDirection: String
        let forceMultiplierHabit: String?
        let entryCount: Int
    }

    func sentimentDataForReport(
        startDate: Date,
        endDate: Date,
        from context: ModelContext
    ) -> ReportSentimentData {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date)]
        )
        let allEntries = (try? context.fetch(descriptor)) ?? []
        let rangeEntries = allEntries.filter { $0.date >= startDate && $0.date < endDate }

        guard !rangeEntries.isEmpty else {
            return ReportSentimentData(
                averageSentiment: 0, trendDirection: "stable",
                forceMultiplierHabit: nil, entryCount: 0
            )
        }

        let avg = rangeEntries.map(\.sentimentScore).reduce(0, +) / Double(rangeEntries.count)

        // Trend: compare first half to second half
        let midpoint = rangeEntries.count / 2
        let firstHalf = Array(rangeEntries.prefix(midpoint))
        let secondHalf = Array(rangeEntries.suffix(from: midpoint))

        let firstAvg = firstHalf.isEmpty ? 0 : firstHalf.map(\.sentimentScore).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.isEmpty ? 0 : secondHalf.map(\.sentimentScore).reduce(0, +) / Double(secondHalf.count)

        let delta = secondAvg - firstAvg
        let direction: String
        if delta > 0.05 { direction = "improving" }
        else if delta < -0.05 { direction = "declining" }
        else { direction = "stable" }

        return ReportSentimentData(
            averageSentiment: avg,
            trendDirection: direction,
            forceMultiplierHabit: latestAnalysis?.forceMultiplierHabit,
            entryCount: rangeEntries.count
        )
    }

    // MARK: - Helpers

    private func titleFromContent(_ content: String) -> String {
        let firstLine = content.split(separator: "\n", maxSplits: 1).first
            .map(String.init) ?? content
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 50 { return trimmed }
        return String(trimmed.prefix(47)) + "..."
    }
}
