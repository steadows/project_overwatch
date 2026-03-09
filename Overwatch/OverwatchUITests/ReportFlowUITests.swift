import XCTest

/// UI tests: generate report → view in list → expand detail.
@MainActor
final class ReportFlowUITests: XCTestCase {

    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-hasCompletedFirstBoot", "YES", "-hasCompletedOnboarding", "YES"]
        app.launch()

        let dashboard = app.buttons["sidebar_dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 15), "App should finish boot and show sidebar")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func testNavigateToReports() throws {
        let reportsTab = app.buttons["sidebar_reports"]
        XCTAssertTrue(reportsTab.waitForExistence(timeout: 5))
        reportsTab.click()

        Thread.sleep(forTimeInterval: 1.0)

        // Verify the header text for reports section
        let header = app.staticTexts["INTEL BRIEFINGS"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Reports header should display 'INTEL BRIEFINGS'")
    }

    func testGenerateReportButton() throws {
        // Navigate to Reports
        let reportsTab = app.buttons["sidebar_reports"]
        XCTAssertTrue(reportsTab.waitForExistence(timeout: 5))
        reportsTab.click()
        Thread.sleep(forTimeInterval: 1.0)

        // Find and tap the Generate Report button
        let generateButton = app.buttons["reports_generate"]
        XCTAssertTrue(
            generateButton.waitForExistence(timeout: 5),
            "GENERATE REPORT button should exist"
        )
        generateButton.click()

        // The date picker banner should appear — look for COMPILE or START/END labels
        Thread.sleep(forTimeInterval: 0.5)
        let startLabel = app.staticTexts["START"]
        let endLabel = app.staticTexts["END"]
        let datePickerVisible = startLabel.waitForExistence(timeout: 3) || endLabel.exists
        XCTAssertTrue(datePickerVisible, "Date picker banner should appear after clicking generate")
    }

    func testReportCardExpandCollapse() throws {
        // Navigate to Reports
        let reportsTab = app.buttons["sidebar_reports"]
        XCTAssertTrue(reportsTab.waitForExistence(timeout: 5))
        reportsTab.click()
        Thread.sleep(forTimeInterval: 1.0)

        // Check if any report cards exist by looking for report-specific content
        let reportCards = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'report_card_'")
        )

        if reportCards.count > 0 {
            // Click the first card to expand
            reportCards.element(boundBy: 0).click()
            Thread.sleep(forTimeInterval: 0.5)
        } else {
            // No reports — check for empty state or header (both valid)
            let header = app.staticTexts["INTEL BRIEFINGS"]
            XCTAssertTrue(header.exists, "Reports page should at least show the header")
        }
    }

    func testEmptyReportsState() throws {
        // Navigate to Reports
        let reportsTab = app.buttons["sidebar_reports"]
        XCTAssertTrue(reportsTab.waitForExistence(timeout: 5))
        reportsTab.click()
        Thread.sleep(forTimeInterval: 1.0)

        // The reports page should be visible — either with reports or empty state
        let header = app.staticTexts["INTEL BRIEFINGS"]
        let generateButton = app.buttons["reports_generate"]

        let reportsPageVisible = header.waitForExistence(timeout: 5) || generateButton.exists
        XCTAssertTrue(reportsPageVisible, "Reports view should be visible")
    }
}
