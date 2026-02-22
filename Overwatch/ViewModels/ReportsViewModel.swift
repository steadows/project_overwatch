import Foundation
import SwiftData

@MainActor
@Observable
final class ReportsViewModel {

    // MARK: - Display Types

    struct ReportCard: Identifiable, Equatable {
        let id: UUID
        let dateRangeStart: Date
        let dateRangeEnd: Date
        let summary: String
        let forceMultiplierHabit: String
        let recommendations: [String]
        let correlations: [HabitCoefficient]
        let averageSentiment: Double?
        let sentimentTrend: String?
        let generatedAt: Date

        var dateRangeLabel: String {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d, yyyy"
            let startLabel = fmt.string(from: dateRangeStart).uppercased()
            let endLabel = fmt.string(from: dateRangeEnd).uppercased()
            return "\(startLabel) — \(endLabel)"
        }

        var summaryPreview: String {
            let lines = summary.components(separatedBy: "\n").filter { !$0.isEmpty }
            let preview = lines.prefix(2).joined(separator: " ")
            if preview.count > 200 {
                return String(preview.prefix(200)) + "..."
            }
            return preview
        }

        var sentimentTrendArrow: String? {
            switch sentimentTrend {
            case "improving": return "arrow.up.right"
            case "declining": return "arrow.down.right"
            case "stable": return "arrow.right"
            default: return nil
            }
        }
    }

    // MARK: - State

    var reports: [ReportCard] = []
    var selectedReportID: UUID?
    var isGenerating = false
    var generationProgress: String?
    var showDatePicker = false
    var customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    var customEndDate = Date.now

    // MARK: - Dependencies

    private let intelligenceManager: IntelligenceManager

    init(intelligenceManager: IntelligenceManager = IntelligenceManager()) {
        self.intelligenceManager = intelligenceManager
    }

    // MARK: - Gemini Status

    /// Whether the Gemini API key is configured (AI features available)
    var geminiAvailable: Bool { EnvironmentConfig.geminiAPIKey != nil }

    /// Set when generation fails due to rate limiting
    var isThrottled = false
    var throttleMessage: String?

    // MARK: - Computed

    var selectedReport: ReportCard? {
        reports.first { $0.id == selectedReportID }
    }

    var isEmpty: Bool {
        reports.isEmpty && !isGenerating
    }

    // MARK: - Data Loading

    func loadReports(from context: ModelContext) {
        let descriptor = FetchDescriptor<WeeklyInsight>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        let insights = (try? context.fetch(descriptor)) ?? []

        reports = insights.map { insight in
            ReportCard(
                id: insight.id,
                dateRangeStart: insight.dateRangeStart,
                dateRangeEnd: insight.dateRangeEnd,
                summary: insight.summary,
                forceMultiplierHabit: insight.forceMultiplierHabit,
                recommendations: insight.recommendations,
                correlations: insight.correlations,
                averageSentiment: insight.averageSentiment,
                sentimentTrend: insight.sentimentTrend,
                generatedAt: insight.generatedAt
            )
        }
    }

    // MARK: - Report Generation

    private var generationTask: Task<Void, Never>?

    func generateReport(from context: ModelContext) {
        isThrottled = false
        throttleMessage = nil

        generationTask = Task {
            isGenerating = true
            generationProgress = "COMPILING INTELLIGENCE BRIEFING..."

            do {
                let _ = try await intelligenceManager.generateWeeklyReport(
                    startDate: Calendar.current.startOfDay(for: customStartDate),
                    endDate: Calendar.current.startOfDay(for: customEndDate),
                    from: context
                )
                loadReports(from: context)
            } catch is CancellationError {
                generationProgress = nil
            } catch {
                if let geminiError = error as? GeminiError {
                    switch geminiError {
                    case .rateLimited:
                        isThrottled = true
                        throttleMessage = "Rate limit exceeded — try again later"
                        generationProgress = nil
                    case .noAPIKey:
                        generationProgress = "INTELLIGENCE CORE OFFLINE — configure API key in Settings"
                    default:
                        generationProgress = "GENERATION FAILED: \(error.localizedDescription)"
                    }
                } else {
                    generationProgress = "GENERATION FAILED: \(error.localizedDescription)"
                }
            }

            isGenerating = false
            showDatePicker = false

            // Clear transient progress after a delay (keep throttle/error visible)
            if !isThrottled {
                try? await Task.sleep(for: .seconds(3))
                generationProgress = nil
            }
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        generationProgress = nil
    }

    // MARK: - Delete

    func deleteReport(_ id: UUID, from context: ModelContext) {
        let descriptor = FetchDescriptor<WeeklyInsight>()
        guard let insights = try? context.fetch(descriptor),
              let target = insights.first(where: { $0.id == id }) else { return }
        context.delete(target)
        try? context.save()

        if selectedReportID == id { selectedReportID = nil }
        loadReports(from: context)
    }

    // MARK: - Selection

    func selectReport(_ id: UUID?) {
        selectedReportID = (selectedReportID == id) ? nil : id
    }
}
