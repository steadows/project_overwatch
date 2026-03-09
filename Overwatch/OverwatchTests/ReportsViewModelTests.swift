import Testing
import Foundation
import SwiftData
@testable import Overwatch

// MARK: - Test Helpers

@MainActor
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Habit.self, HabitEntry.self, JournalEntry.self,
        MonthlyAnalysis.self, WhoopCycle.self, WeeklyInsight.self,
        configurations: config
    )
}

@MainActor
private func seedReports(in context: ModelContext) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let report1 = WeeklyInsight(
        dateRangeStart: calendar.date(byAdding: .day, value: -14, to: today)!,
        dateRangeEnd: calendar.date(byAdding: .day, value: -7, to: today)!,
        summary: "First week summary with enough text to test preview functionality properly.",
        forceMultiplierHabit: "Meditation",
        recommendations: ["Keep meditating", "Exercise more"],
        correlations: [
            HabitCoefficient(
                habitName: "Meditation", habitEmoji: "🧘",
                coefficient: 0.34, pValue: 0.02,
                completionRate: 0.75, direction: .positive
            ),
        ],
        averageSentiment: 0.42,
        sentimentTrend: "improving",
        generatedAt: Date(timeIntervalSince1970: 2_000_000)
    )

    let report2 = WeeklyInsight(
        dateRangeStart: calendar.date(byAdding: .day, value: -7, to: today)!,
        dateRangeEnd: today,
        summary: "Second week summary.",
        forceMultiplierHabit: "Exercise",
        recommendations: ["Keep exercising"],
        averageSentiment: 0.55,
        sentimentTrend: "stable",
        generatedAt: Date(timeIntervalSince1970: 3_000_000)
    )

    context.insert(report1)
    context.insert(report2)
    try? context.save()
}

// MARK: - Tests

@Suite("ReportsViewModel")
struct ReportsViewModelTests {

    // MARK: - Initial State

    @Test @MainActor
    func initialState() {
        let vm = ReportsViewModel()

        #expect(vm.reports.isEmpty)
        #expect(vm.selectedReportID == nil)
        #expect(vm.selectedReport == nil)
        #expect(vm.isGenerating == false)
        #expect(vm.generationProgress == nil)
        #expect(vm.isEmpty == true)
        #expect(vm.showDatePicker == false)
        #expect(vm.isThrottled == false)
    }

    // MARK: - Load Reports

    @Test @MainActor
    func loadReportsPopulatesList() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedReports(in: context)

        let vm = ReportsViewModel()
        vm.loadReports(from: context)

        #expect(vm.reports.count == 2)
        #expect(vm.isEmpty == false)
        // Should be sorted newest first
        #expect(vm.reports[0].generatedAt > vm.reports[1].generatedAt)
    }

    @Test @MainActor
    func loadReportsWithEmptyDatabase() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let vm = ReportsViewModel()
        vm.loadReports(from: context)

        #expect(vm.reports.isEmpty)
        #expect(vm.isEmpty == true)
    }

    // MARK: - Selection

    @Test @MainActor
    func selectReport() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedReports(in: context)

        let vm = ReportsViewModel()
        vm.loadReports(from: context)

        let firstID = vm.reports[0].id
        vm.selectReport(firstID)
        #expect(vm.selectedReportID == firstID)
        #expect(vm.selectedReport?.id == firstID)
    }

    @Test @MainActor
    func selectReportToggle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedReports(in: context)

        let vm = ReportsViewModel()
        vm.loadReports(from: context)

        let firstID = vm.reports[0].id

        // Select
        vm.selectReport(firstID)
        #expect(vm.selectedReportID == firstID)

        // Toggle off
        vm.selectReport(firstID)
        #expect(vm.selectedReportID == nil)
    }

    @Test @MainActor
    func selectDifferentReport() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedReports(in: context)

        let vm = ReportsViewModel()
        vm.loadReports(from: context)

        vm.selectReport(vm.reports[0].id)
        vm.selectReport(vm.reports[1].id)
        #expect(vm.selectedReportID == vm.reports[1].id)
    }

    @Test @MainActor
    func selectNil() {
        let vm = ReportsViewModel()
        vm.selectedReportID = UUID()

        vm.selectReport(nil)
        #expect(vm.selectedReportID == nil)
    }

    // MARK: - Delete Report

    @Test @MainActor
    func deleteReport() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedReports(in: context)

        let vm = ReportsViewModel()
        vm.loadReports(from: context)
        #expect(vm.reports.count == 2)

        let idToDelete = vm.reports[0].id
        vm.selectedReportID = idToDelete

        vm.deleteReport(idToDelete, from: context)

        #expect(vm.reports.count == 1)
        #expect(vm.selectedReportID == nil) // Deselected
    }

    @Test @MainActor
    func deleteNonSelectedReport() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedReports(in: context)

        let vm = ReportsViewModel()
        vm.loadReports(from: context)

        let selectedID = vm.reports[0].id
        let deleteID = vm.reports[1].id
        vm.selectedReportID = selectedID

        vm.deleteReport(deleteID, from: context)

        #expect(vm.reports.count == 1)
        #expect(vm.selectedReportID == selectedID) // Still selected
    }

    // MARK: - ReportCard Properties

    @Test @MainActor
    func reportCardDateRangeLabel() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedReports(in: context)

        let vm = ReportsViewModel()
        vm.loadReports(from: context)

        let label = vm.reports[0].dateRangeLabel
        #expect(!label.isEmpty)
        #expect(label.contains("—"))
        // Should be uppercase
        #expect(label == label.uppercased())
    }

    @Test @MainActor
    func reportCardSummaryPreview() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedReports(in: context)

        let vm = ReportsViewModel()
        vm.loadReports(from: context)

        let preview = vm.reports[0].summaryPreview
        #expect(!preview.isEmpty)
        #expect(preview.count <= 203) // 200 + "..."
    }

    @Test @MainActor
    func reportCardSentimentTrendArrow() {
        let improving = ReportsViewModel.ReportCard(
            id: UUID(), dateRangeStart: .now, dateRangeEnd: .now,
            summary: "", forceMultiplierHabit: "", recommendations: [],
            correlations: [], averageSentiment: 0.5,
            sentimentTrend: "improving", generatedAt: .now
        )
        #expect(improving.sentimentTrendArrow == "arrow.up.right")

        let declining = ReportsViewModel.ReportCard(
            id: UUID(), dateRangeStart: .now, dateRangeEnd: .now,
            summary: "", forceMultiplierHabit: "", recommendations: [],
            correlations: [], averageSentiment: -0.2,
            sentimentTrend: "declining", generatedAt: .now
        )
        #expect(declining.sentimentTrendArrow == "arrow.down.right")

        let stable = ReportsViewModel.ReportCard(
            id: UUID(), dateRangeStart: .now, dateRangeEnd: .now,
            summary: "", forceMultiplierHabit: "", recommendations: [],
            correlations: [], averageSentiment: 0.0,
            sentimentTrend: "stable", generatedAt: .now
        )
        #expect(stable.sentimentTrendArrow == "arrow.right")

        let noTrend = ReportsViewModel.ReportCard(
            id: UUID(), dateRangeStart: .now, dateRangeEnd: .now,
            summary: "", forceMultiplierHabit: "", recommendations: [],
            correlations: [], averageSentiment: nil,
            sentimentTrend: nil, generatedAt: .now
        )
        #expect(noTrend.sentimentTrendArrow == nil)
    }

    // MARK: - Cancel Generation

    @Test @MainActor
    func cancelGeneration() {
        let vm = ReportsViewModel()
        vm.isGenerating = true
        vm.generationProgress = "COMPILING..."

        vm.cancelGeneration()

        #expect(vm.isGenerating == false)
        #expect(vm.generationProgress == nil)
    }

    // MARK: - isEmpty

    @Test @MainActor
    func isEmptyDuringGeneration() {
        let vm = ReportsViewModel()
        vm.isGenerating = true

        #expect(vm.isEmpty == false) // Not empty while generating
    }
}
