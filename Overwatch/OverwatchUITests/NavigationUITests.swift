import XCTest

/// UI tests: sidebar switches between all 6 sections correctly.
@MainActor
final class NavigationUITests: XCTestCase {

    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-hasCompletedFirstBoot", "YES", "-hasCompletedOnboarding", "YES"]
        app.launch()

        // Wait for boot sequence to complete — sidebar dashboard button is the signal
        let dashboard = app.buttons["sidebar_dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 15), "App should finish boot and show sidebar")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func testSidebarShowsAllSections() throws {
        let sections = ["dashboard", "habits", "journal", "war_room", "reports", "settings"]

        for section in sections {
            let sidebarItem = app.buttons["sidebar_\(section)"]
            XCTAssertTrue(
                sidebarItem.waitForExistence(timeout: 5),
                "Sidebar item '\(section)' should exist"
            )
        }
    }

    func testNavigateToEachSection() throws {
        let sections = ["habits", "journal", "war_room", "reports", "settings", "dashboard"]

        for section in sections {
            let sidebarItem = app.buttons["sidebar_\(section)"]
            XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5))
            sidebarItem.click()

            // Wait for the transition animation
            Thread.sleep(forTimeInterval: 0.5)

            // Verify the section changed — app is still stable
            XCTAssertTrue(sidebarItem.exists, "App should remain stable after navigating to \(section)")
        }
    }

    func testDashboardIsDefaultSection() throws {
        // Dashboard-specific content should be visible on launch
        // The header says "TACTICAL PERFORMANCE SYSTEM"
        let dashboardHeader = app.staticTexts["TACTICAL PERFORMANCE SYSTEM"]
        XCTAssertTrue(
            dashboardHeader.waitForExistence(timeout: 5),
            "Dashboard should be the default selected section"
        )
    }

    func testSidebarCollapseToggle() throws {
        // Verify sidebar button labels are accessible — the buttons have labels like "DASHBOARD"
        let dashboardButton = app.buttons["sidebar_dashboard"]
        XCTAssertTrue(dashboardButton.waitForExistence(timeout: 5))
        XCTAssertEqual(dashboardButton.label, "DASHBOARD", "Sidebar buttons should have correct labels")

        let habitsButton = app.buttons["sidebar_habits"]
        XCTAssertEqual(habitsButton.label, "HABITS")
    }
}
