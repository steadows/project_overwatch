import Foundation
import Observation
import SwiftData

/// ViewModel for the Journal page — entry CRUD, save-time sentiment scoring
/// (Gemini-first with NLTagger fallback), trend visualization, filtering,
/// and monthly regression analysis.
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

    struct MonthOption: Identifiable, Equatable {
        let month: Int
        let year: Int
        let label: String
        let shortLabel: String
        var id: String { "\(year)-\(month)" }
    }

    /// Global period filter for charts and analysis — ALL, 3M, 1M, or a specific month.
    enum PeriodFilter: Equatable, Identifiable {
        case all
        case threeMonths
        case oneMonth
        case specific(index: Int)

        var id: String {
            switch self {
            case .all: "all"
            case .threeMonths: "3m"
            case .oneMonth: "1m"
            case .specific(let i): "month-\(i)"
            }
        }

        var label: String {
            switch self {
            case .all: "ALL"
            case .threeMonths: "3M"
            case .oneMonth: "1M"
            case .specific: ""
            }
        }
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

    struct DailyHabitCompletion: Identifiable, Equatable {
        let id: Date
        let date: Date
        let count: Int
    }

    // MARK: - Dependencies

    private let sentimentService: SentimentAnalysisService
    private let geminiService: GeminiService?
    private let regressionService: RegressionService

    // MARK: - State

    var entries: [JournalItem] = []
    var selectedEntryID: UUID?
    var selectedEntryContent: String = ""
    var editorTitle: String = ""
    var editorContent: String = ""
    var editorTags: [String] = []
    var isEditing: Bool = false
    var editingEntryID: UUID?

    var sentimentTrend: [SentimentDataPoint] = []
    var habitCompletionData: [DailyHabitCompletion] = []

    var dateFilter: DateFilter = .all
    var sentimentFilter: SentimentFilter = .all
    var searchText: String = ""

    var latestAnalysis: MonthlyAnalysisItem?
    var isGeneratingAnalysis: Bool = false
    var analysisError: String?
    var availableMonths: [MonthOption] = []
    var selectedMonthIndex: Int = 0
    var selectedPeriod: PeriodFilter = .all
    var currentMonthEntryCount: Int = 0

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

    /// Date range for the current period selection.
    private var periodDateRange: (start: Date, end: Date)? {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .all:
            return nil
        case .threeMonths:
            let end = calendar.startOfDay(for: .now)
            let start = calendar.date(byAdding: .month, value: -3, to: end)!
            return (start, end.addingTimeInterval(86400))
        case .oneMonth:
            let end = calendar.startOfDay(for: .now)
            let start = calendar.date(byAdding: .month, value: -1, to: end)!
            return (start, end.addingTimeInterval(86400))
        case .specific(let index):
            guard index < availableMonths.count else { return nil }
            let option = availableMonths[index]
            let startOfMonth = calendar.date(
                from: DateComponents(year: option.year, month: option.month, day: 1)
            )!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
        }
    }

    /// Sentiment trend filtered to the currently selected period.
    var filteredSentimentTrend: [SentimentDataPoint] {
        guard let range = periodDateRange else { return sentimentTrend }
        return sentimentTrend.filter { $0.date >= range.start && $0.date < range.end }
    }

    /// Habit completion data filtered to the currently selected period.
    var filteredHabitCompletionData: [DailyHabitCompletion] {
        guard let range = periodDateRange else { return habitCompletionData }
        return habitCompletionData.filter { $0.date >= range.start && $0.date < range.end }
    }

    // MARK: - Month Navigation

    /// Label for the currently selected month (e.g. "January 2026").
    var selectedMonthLabel: String {
        guard !availableMonths.isEmpty, selectedMonthIndex < availableMonths.count else {
            return ""
        }
        return availableMonths[selectedMonthIndex].label
    }

    /// Short label for the currently selected month (e.g. "JAN '26").
    var selectedMonthShortLabel: String {
        guard !availableMonths.isEmpty, selectedMonthIndex < availableMonths.count else {
            return ""
        }
        return availableMonths[selectedMonthIndex].shortLabel
    }

    /// Whether the current period is a range (ALL/3M/1M) rather than a specific month.
    var isRangeMode: Bool {
        switch selectedPeriod {
        case .all, .threeMonths, .oneMonth: true
        case .specific: false
        }
    }

    /// Whether there's an older month to navigate to.
    var canSelectPreviousMonth: Bool {
        selectedMonthIndex < availableMonths.count - 1
    }

    /// Whether there's a newer month to navigate to.
    var canSelectNextMonth: Bool {
        selectedMonthIndex > 0
    }

    // MARK: - Init

    init(
        sentimentService: SentimentAnalysisService = SentimentAnalysisService(),
        geminiService: GeminiService? = GeminiService.create(),
        regressionService: RegressionService = RegressionService()
    ) {
        self.sentimentService = sentimentService
        self.geminiService = geminiService
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
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        editingEntryID = nil
        editorTitle = ""
        editorContent = ""
        editorTags = []
    }

    func selectEntry(_ id: UUID, from context: ModelContext) {
        selectedEntryID = id
        isEditing = false
        editingEntryID = nil

        let descriptor = FetchDescriptor<JournalEntry>()
        guard let allEntries = try? context.fetch(descriptor),
              let entry = allEntries.first(where: { $0.id == id }) else {
            selectedEntryContent = ""
            return
        }

        selectedEntryContent = entry.content
    }

    func editEntry(_ id: UUID, from context: ModelContext) {
        selectedEntryID = id

        let descriptor = FetchDescriptor<JournalEntry>()
        guard let allEntries = try? context.fetch(descriptor),
              let entry = allEntries.first(where: { $0.id == id }) else { return }

        editingEntryID = entry.id
        editorTitle = entry.title
        editorContent = entry.content
        editorTags = entry.tags
        isEditing = true
    }

    func saveEntry(in context: ModelContext) async {
        let content = editorContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let title = editorTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = content.split(separator: " ").count

        // Gemini-first sentiment: try Gemini, fall back to NLTagger if unavailable/fails
        let sentiment: SentimentResult
        if let gemini = geminiService,
           let geminiResult = await gemini.analyzeSentiment(title: title, content: content) {
            sentiment = geminiResult
        } else {
            sentiment = await sentimentService.analyzeSentiment(content)
        }

        if let existingID = editingEntryID {
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

        selectedEntryContent = content
        isEditing = false
        editingEntryID = nil
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
            selectedEntryContent = ""
            isEditing = false
            editingEntryID = nil
        }

        loadEntries(from: context)
        loadSentimentTrend(from: context)
    }

    // MARK: - Monthly Analysis

    func generateMonthlyAnalysis(for date: Date, from context: ModelContext) async {
        guard !isGeneratingAnalysis else { return }
        isGeneratingAnalysis = true
        analysisError = nil
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
        guard let allEntries = try? context.fetch(entryDescriptor) else {
            analysisError = "Failed to fetch journal entries"
            return
        }
        let monthEntries = allEntries.filter { $0.date >= startDate && $0.date < endDate }

        guard monthEntries.count >= 14 else {
            analysisError = "Need at least 14 entries (\(monthEntries.count) found)"
            return
        }

        // Fetch habits for the regression matrix
        let habitDescriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        guard let habits = try? context.fetch(habitDescriptor), !habits.isEmpty else {
            analysisError = "No habits found — add habits to enable analysis"
            return
        }

        // Build regression input — only include days with journal data and habits with variance
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 30

        // Fetch WHOOP cycles for the month to use sleep/HRV as biometric predictors
        let whoopDescriptor = FetchDescriptor<WhoopCycle>(sortBy: [SortDescriptor(\.date)])
        let allCycles = (try? context.fetch(whoopDescriptor)) ?? []
        let monthCycles = allCycles.filter { $0.date >= startDate && $0.date < endDate }
        // Build date → cycle lookup (use start-of-day as key)
        var whoopByDay: [Date: WhoopCycle] = [:]
        for cycle in monthCycles {
            whoopByDay[calendar.startOfDay(for: cycle.date)] = cycle
        }

        // Pass 1: collect only days that have journal entries (skip zero-padded gaps)
        var sentimentValues: [Double] = []
        var habitCompletionRows: [[Double]] = []
        var completionCounts = [Int](repeating: 0, count: habits.count)
        // Track biometric values per day (nil = no WHOOP data that day)
        var dailySleep: [Double?] = []
        var dailyHRV: [Double?] = []

        for dayOffset in 0..<dayCount {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let dayEntries = monthEntries.filter { $0.date >= dayStart && $0.date < dayEnd }
            guard !dayEntries.isEmpty else { continue }

            let avgSentiment = dayEntries.map(\.sentimentScore).reduce(0, +) / Double(dayEntries.count)
            sentimentValues.append(avgSentiment)

            var row = [Double](repeating: 0.0, count: habits.count)
            for (habitIdx, habit) in habits.enumerated() {
                let completed = habit.entries.contains { entry in
                    entry.completed && calendar.isDate(entry.date, inSameDayAs: dayDate)
                }
                if completed {
                    row[habitIdx] = 1.0
                    completionCounts[habitIdx] += 1
                }
            }
            habitCompletionRows.append(row)

            // Capture biometric values for this day
            if let cycle = whoopByDay[dayStart] {
                dailySleep.append(cycle.sleepPerformance / 100.0)  // Normalize to 0–1
                dailyHRV.append(cycle.hrvRmssdMilli / 100.0)       // Scale to ~0–2 range
            } else {
                dailySleep.append(nil)
                dailyHRV.append(nil)
            }
        }

        let validDays = sentimentValues.count

        // Pass 2: filter out habits with no variance (e.g. 100% or 0% completion)
        // These are collinear with the intercept and make X'X singular.
        var includedIndices: [Int] = []
        for habitIdx in 0..<habits.count {
            let sum = habitCompletionRows.reduce(0.0) { $0 + $1[habitIdx] }
            let mean = sum / max(1.0, Double(validDays))
            if mean > 1e-6, mean < (1.0 - 1e-6) {
                includedIndices.append(habitIdx)
            }
        }

        guard includedIndices.count >= 2 else {
            analysisError = "Need at least 2 habits with varied completion — habits done every day or never are excluded"
            return
        }

        var filteredNames = includedIndices.map { habits[$0].name }
        var filteredEmojis = includedIndices.map { habits[$0].emoji }
        var filteredRates = includedIndices.map { Double(completionCounts[$0]) / max(1, Double(validDays)) }

        // Determine which biometric features have enough data (≥50% of days)
        let sleepValues = dailySleep.compactMap { $0 }
        let hrvValues = dailyHRV.compactMap { $0 }
        let biometricThreshold = validDays / 2
        let includeSleep = sleepValues.count >= biometricThreshold
        let includeHRV = hrvValues.count >= biometricThreshold

        // Mean-impute missing biometric values for days without WHOOP data
        let sleepMean = includeSleep ? sleepValues.reduce(0, +) / Double(sleepValues.count) : 0
        let hrvMean = includeHRV ? hrvValues.reduce(0, +) / Double(hrvValues.count) : 0

        // Build column-major feature matrix for included habits only
        let biometricCols = (includeSleep ? 1 : 0) + (includeHRV ? 1 : 0)
        let totalCols = includedIndices.count + biometricCols
        var featureMatrix = [Double](repeating: 0.0, count: validDays * totalCols)

        // Habit columns
        for (newCol, origCol) in includedIndices.enumerated() {
            for row in 0..<validDays {
                featureMatrix[newCol * validDays + row] = habitCompletionRows[row][origCol]
            }
        }

        // Biometric columns (appended after habits)
        var biometricColIdx = includedIndices.count
        if includeSleep {
            filteredNames.append("Sleep Quality")
            filteredEmojis.append("🌙")
            filteredRates.append(sleepMean)
            for row in 0..<validDays {
                featureMatrix[biometricColIdx * validDays + row] = dailySleep[row] ?? sleepMean
            }
            biometricColIdx += 1
        }
        if includeHRV {
            filteredNames.append("Heart Rate Variability")
            filteredEmojis.append("💓")
            filteredRates.append(hrvMean)
            for row in 0..<validDays {
                featureMatrix[biometricColIdx * validDays + row] = dailyHRV[row] ?? hrvMean
            }
        }

        let input = RegressionInput(
            habitNames: filteredNames,
            habitEmojis: filteredEmojis,
            featureMatrix: featureMatrix,
            targetVector: sentimentValues,
            completionRates: filteredRates
        )

        // Run regression
        guard let output = regressionService.computeRegression(input) else {
            analysisError = "Regression failed — entries may lack sentiment scores (try re-seeding data)"
            return
        }

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

    // MARK: - Month Selection & Available Months

    func loadAvailableMonths(from context: ModelContext) {
        let calendar = Calendar.current
        let now = Date.now
        let currentComponents = calendar.dateComponents([.month, .year], from: now)

        var months: [MonthOption] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM ''yy"

        // Current month + up to 11 previous months that have journal entries
        for offset in 0..<12 {
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let comps = calendar.dateComponents([.month, .year], from: date)
            guard let month = comps.month, let year = comps.year else { continue }

            let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
            guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { continue }

            let descriptor = FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { entry in
                    entry.date >= startOfMonth && entry.date < endOfMonth
                }
            )
            let count = (try? context.fetchCount(descriptor)) ?? 0
            if count > 0 || (month == currentComponents.month && year == currentComponents.year) {
                months.append(MonthOption(
                    month: month,
                    year: year,
                    label: formatter.string(from: startOfMonth),
                    shortLabel: shortFormatter.string(from: startOfMonth).uppercased()
                ))
            }
        }

        availableMonths = months
        if selectedMonthIndex >= months.count {
            selectedMonthIndex = 0
        }

        // Default the month index to the first month with data (for the navigator display)
        // but keep selectedPeriod as .all so we don't auto-select a specific month.
        for (index, option) in months.enumerated() {
            let start = calendar.date(from: DateComponents(year: option.year, month: option.month, day: 1))!
            guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { continue }
            let desc = FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { entry in
                    entry.date >= start && entry.date < end
                }
            )
            let count = (try? context.fetchCount(desc)) ?? 0
            if count > 0 {
                selectedMonthIndex = index
                break
            }
        }

        loadCurrentMonthEntryCount(from: context)
    }

    func selectPeriod(_ period: PeriodFilter, from context: ModelContext) {
        selectedPeriod = period
        // When a specific month is selected, also update the month index
        // so analysis and entry count stay in sync.
        if case .specific(let index) = period, index < availableMonths.count {
            selectedMonthIndex = index
            let option = availableMonths[index]
            loadAnalysis(month: option.month, year: option.year, from: context)
            loadCurrentMonthEntryCount(from: context)
        } else if !availableMonths.isEmpty {
            // For range filters, load analysis for the most recent month
            selectedMonthIndex = 0
            let option = availableMonths[0]
            loadAnalysis(month: option.month, year: option.year, from: context)
            loadCurrentMonthEntryCount(from: context)
        }
    }

    func selectMonth(at index: Int, from context: ModelContext) {
        guard index >= 0 && index < availableMonths.count else { return }
        selectedPeriod = .specific(index: index)
        selectedMonthIndex = index
        let option = availableMonths[index]
        loadAnalysis(month: option.month, year: option.year, from: context)
        loadCurrentMonthEntryCount(from: context)
    }

    /// Navigate to the previous (older) available month.
    func selectPreviousMonth(from context: ModelContext) {
        let newIndex = selectedMonthIndex + 1
        guard newIndex < availableMonths.count else { return }
        selectMonth(at: newIndex, from: context)
    }

    /// Navigate to the next (newer) available month.
    func selectNextMonth(from context: ModelContext) {
        let newIndex = selectedMonthIndex - 1
        guard newIndex >= 0 else { return }
        selectMonth(at: newIndex, from: context)
    }

    func loadAnalysis(month: Int, year: Int, from context: ModelContext) {
        let descriptor = FetchDescriptor<MonthlyAnalysis>()
        guard let analyses = try? context.fetch(descriptor) else {
            latestAnalysis = nil
            return
        }

        guard let match = analyses.first(where: { $0.month == month && $0.year == year }) else {
            latestAnalysis = nil
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        latestAnalysis = MonthlyAnalysisItem(
            id: match.id,
            month: match.month,
            year: match.year,
            monthLabel: formatter.string(from: match.startDate),
            averageSentiment: match.averageSentiment,
            entryCount: match.entryCount,
            forceMultiplierHabit: match.forceMultiplierHabit,
            modelR2: match.modelR2,
            summary: match.summary,
            coefficients: match.habitCoefficients,
            generatedAt: match.generatedAt
        )
    }

    func generateAnalysisForSelectedMonth(from context: ModelContext) async {
        guard !availableMonths.isEmpty, selectedMonthIndex < availableMonths.count else { return }
        var option = availableMonths[selectedMonthIndex]

        // If the selected month has < 14 entries, find the first month that qualifies
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: option.year, month: option.month, day: 1))!
        if let end = calendar.date(byAdding: .month, value: 1, to: start) {
            let desc = FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { entry in
                    entry.date >= start && entry.date < end
                }
            )
            let count = (try? context.fetchCount(desc)) ?? 0
            if count < 14 {
                // Try to find a month with enough data
                for candidate in availableMonths {
                    let cStart = calendar.date(from: DateComponents(year: candidate.year, month: candidate.month, day: 1))!
                    guard let cEnd = calendar.date(byAdding: .month, value: 1, to: cStart) else { continue }
                    let cDesc = FetchDescriptor<JournalEntry>(
                        predicate: #Predicate<JournalEntry> { entry in
                            entry.date >= cStart && entry.date < cEnd
                        }
                    )
                    let cCount = (try? context.fetchCount(cDesc)) ?? 0
                    if cCount >= 14 {
                        option = candidate
                        break
                    }
                }
            }
        }

        guard let date = calendar.date(
            from: DateComponents(year: option.year, month: option.month, day: 15)
        ) else { return }
        await generateMonthlyAnalysis(for: date, from: context)
    }

    func checkAutoTrigger(from context: ModelContext) async {
        let calendar = Calendar.current
        let now = Date.now
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) else { return }
        let comps = calendar.dateComponents([.month, .year], from: lastMonth)
        guard let month = comps.month, let year = comps.year else { return }

        let analysisDescriptor = FetchDescriptor<MonthlyAnalysis>()
        let existing = (try? context.fetch(analysisDescriptor))?.first {
            $0.month == month && $0.year == year
        }
        guard existing == nil else { return }

        let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }

        let entryDescriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { entry in
                entry.date >= startOfMonth && entry.date < endOfMonth
            }
        )
        let count = (try? context.fetchCount(entryDescriptor)) ?? 0
        guard count >= 14 else { return }

        guard let midMonth = calendar.date(
            from: DateComponents(year: year, month: month, day: 15)
        ) else { return }
        await generateMonthlyAnalysis(for: midMonth, from: context)
        // Auto-trigger is best-effort background work — don't surface errors
        analysisError = nil
    }

    private func loadCurrentMonthEntryCount(from context: ModelContext) {
        guard !availableMonths.isEmpty, selectedMonthIndex < availableMonths.count else {
            currentMonthEntryCount = 0
            return
        }

        let option = availableMonths[selectedMonthIndex]
        let calendar = Calendar.current
        let startOfMonth = calendar.date(
            from: DateComponents(year: option.year, month: option.month, day: 1)
        )!
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            currentMonthEntryCount = 0
            return
        }

        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { entry in
                entry.date >= startOfMonth && entry.date < endOfMonth
            }
        )
        currentMonthEntryCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Habit Completion Data (for chart overlay)

    func loadHabitCompletionData(from context: ModelContext) {
        let descriptor = FetchDescriptor<HabitEntry>(
            sortBy: [SortDescriptor(\.date)]
        )
        guard let allEntries = try? context.fetch(descriptor) else {
            habitCompletionData = []
            return
        }

        let completedEntries = allEntries.filter(\.completed)
        let calendar = Calendar.current
        var dayMap: [Date: Int] = [:]

        for entry in completedEntries {
            let day = calendar.startOfDay(for: entry.date)
            dayMap[day, default: 0] += 1
        }

        habitCompletionData = dayMap
            .map { DailyHabitCompletion(id: $0.key, date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Report Data Packaging
    // Sentiment data is integrated into IntelligenceManager.generateWeeklyReport() (Phase 7.2).
    // That method computes averageSentiment and sentimentTrend directly from JournalEntry records.
    // This method remains available for any caller needing pre-packaged sentiment data.

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
