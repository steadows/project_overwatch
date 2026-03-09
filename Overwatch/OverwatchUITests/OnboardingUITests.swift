import XCTest

/// UI tests: boot sequence → setup wizard → arrives at dashboard.
@MainActor
final class OnboardingUITests: XCTestCase {

    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Reset onboarding state so the full flow plays
        app.launchArguments += ["-hasCompletedFirstBoot", "NO", "-hasCompletedOnboarding", "NO"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func testFullOnboardingFlow() throws {
        // Phase 1: Boot sequence plays (~3.3 seconds)
        // Wait for the boot to complete and onboarding to appear
        let beginSetup = app.buttons["onboarding_begin_setup"]
        XCTAssertTrue(
            beginSetup.waitForExistence(timeout: 10),
            "BEGIN SETUP button should appear after boot sequence"
        )

        // Step 1: Welcome — tap BEGIN SETUP
        beginSetup.click()

        // Step 2: Connect WHOOP — tap SKIP FOR NOW
        let skipButton = app.buttons["onboarding_skip"]
        XCTAssertTrue(
            skipButton.waitForExistence(timeout: 5),
            "SKIP FOR NOW button should appear on WHOOP step"
        )
        skipButton.click()

        // Step 3: Add Habits — select some habits, then continue
        let habitsButton = app.buttons["onboarding_habits_continue"]
        XCTAssertTrue(
            habitsButton.waitForExistence(timeout: 5),
            "Habits continue button should appear"
        )

        // Optionally select a habit chip
        let waterChip = app.buttons["habit_chip_water"]
        if waterChip.waitForExistence(timeout: 2) {
            waterChip.click()
        }

        let meditationChip = app.buttons["habit_chip_meditation"]
        if meditationChip.waitForExistence(timeout: 1) {
            meditationChip.click()
        }

        habitsButton.click()

        // Step 4: Operational — auto-advances after ~1.5 seconds
        let operationalText = app.staticTexts["YOU ARE NOW OPERATIONAL"]
        if operationalText.waitForExistence(timeout: 5) {
            // Good — operational screen appeared
        }

        // After onboarding completes, the sidebar should appear
        let sidebarDashboard = app.buttons["sidebar_dashboard"]
        XCTAssertTrue(
            sidebarDashboard.waitForExistence(timeout: 10),
            "Navigation shell should appear after onboarding completes"
        )
    }

    func testBootSequenceCompletesWithoutOnboarding() throws {
        // Re-launch with onboarding already completed
        app.terminate()

        app = XCUIApplication()
        app.launchArguments += ["-hasCompletedFirstBoot", "YES", "-hasCompletedOnboarding", "YES"]
        app.launch()

        // Should skip onboarding and go straight to navigation shell
        let sidebarDashboard = app.buttons["sidebar_dashboard"]
        XCTAssertTrue(
            sidebarDashboard.waitForExistence(timeout: 15),
            "Should skip onboarding when already completed"
        )

        // Onboarding elements should NOT be present
        let beginSetup = app.buttons["onboarding_begin_setup"]
        XCTAssertFalse(beginSetup.exists, "Onboarding should not show for returning users")
    }

    func testSkipWhoopDuringOnboarding() throws {
        // Wait for boot + welcome
        let beginSetup = app.buttons["onboarding_begin_setup"]
        XCTAssertTrue(beginSetup.waitForExistence(timeout: 10))
        beginSetup.click()

        // On WHOOP step, verify both CONNECT and SKIP exist
        let skipButton = app.buttons["onboarding_skip"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))

        // Verify the WHOOP step header text
        let whoopHeader = app.staticTexts["LINK BIOMETRIC SOURCE"]
        XCTAssertTrue(whoopHeader.exists, "WHOOP connection step should show its header")

        skipButton.click()

        // Should advance to habits step
        let habitsButton = app.buttons["onboarding_habits_continue"]
        XCTAssertTrue(
            habitsButton.waitForExistence(timeout: 5),
            "Should advance to habits step after skipping WHOOP"
        )
    }
}
