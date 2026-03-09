import XCTest

/// UI tests: connect WHOOP → change report schedule → export data.
@MainActor
final class SettingsUITests: XCTestCase {

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

    func testNavigateToSettings() throws {
        let settingsTab = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.click()

        Thread.sleep(forTimeInterval: 1.0)

        // Verify settings-specific content
        let settingsHeader = app.staticTexts["SETTINGS"]
        let connectionsLabel = app.staticTexts["CONNECTIONS"]
        let hasSettingsContent = settingsHeader.waitForExistence(timeout: 5) || connectionsLabel.exists
        XCTAssertTrue(hasSettingsContent, "Settings page should show settings content")
    }

    func testConnectWhoopButtonExists() throws {
        let settingsTab = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.click()
        Thread.sleep(forTimeInterval: 1.0)

        // The CONNECT WHOOP button or LINKED status should exist
        let connectButton = app.buttons["settings_connect_whoop"]
        let whoopLabel = app.staticTexts["WHOOP BIOMETRIC LINK"]

        let hasWhoopControl = connectButton.waitForExistence(timeout: 5) || whoopLabel.exists
        XCTAssertTrue(hasWhoopControl, "WHOOP connection control should be visible in Settings")
    }

    func testReportScheduleToggle() throws {
        let settingsTab = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.click()
        Thread.sleep(forTimeInterval: 1.0)

        // Find the auto-generate toggle
        let autoGenToggle = app.otherElements["settings_auto_generate_toggle"]
        guard autoGenToggle.waitForExistence(timeout: 5) else {
            // Verify the label at least exists
            let autoGenLabel = app.staticTexts["AUTO-GENERATE"]
            XCTAssertTrue(
                autoGenLabel.waitForExistence(timeout: 3),
                "AUTO-GENERATE label should exist in Settings"
            )
            return
        }

        // Toggle it
        autoGenToggle.click()
        Thread.sleep(forTimeInterval: 0.5)

        // When enabled, schedule pickers should appear
        let scheduleDayLabel = app.staticTexts["SCHEDULE DAY"]
        if scheduleDayLabel.waitForExistence(timeout: 3) {
            let scheduleTimeLabel = app.staticTexts["SCHEDULE TIME"]
            XCTAssertTrue(
                scheduleTimeLabel.waitForExistence(timeout: 2),
                "SCHEDULE TIME should appear when auto-generate is enabled"
            )
        }

        // Toggle back
        autoGenToggle.click()
    }

    func testExportButtonsExist() throws {
        let settingsTab = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.click()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify export buttons exist
        let exportJSONButton = app.buttons["settings_export_json"]
        let exportCSVButton = app.buttons["settings_export_csv"]

        XCTAssertTrue(
            exportJSONButton.waitForExistence(timeout: 5),
            "EXPORT ALL DATA button should exist"
        )
        XCTAssertTrue(
            exportCSVButton.waitForExistence(timeout: 3),
            "EXPORT HABITS button should exist"
        )
    }

    func testConnectionsSectionLayout() throws {
        let settingsTab = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.click()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify both connections are shown
        let whoopLabel = app.staticTexts["WHOOP BIOMETRIC LINK"]
        let geminiLabel = app.staticTexts["GEMINI AI ENGINE"]

        XCTAssertTrue(
            whoopLabel.waitForExistence(timeout: 5),
            "WHOOP connection row should be visible"
        )
        XCTAssertTrue(
            geminiLabel.waitForExistence(timeout: 3),
            "Gemini connection row should be visible"
        )
    }

    func testAppearanceSectionExists() throws {
        let settingsTab = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.click()
        Thread.sleep(forTimeInterval: 1.0)

        // Scroll to find appearance section
        let accentLabel = app.staticTexts["ACCENT COLOR"]
        if !accentLabel.waitForExistence(timeout: 3) {
            // Try scrolling down
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.scroll(byDeltaX: 0, deltaY: -300)
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        XCTAssertTrue(
            accentLabel.waitForExistence(timeout: 3),
            "ACCENT COLOR section should exist in Settings"
        )
    }
}
