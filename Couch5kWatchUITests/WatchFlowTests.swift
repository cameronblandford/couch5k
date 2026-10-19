import XCTest

/// Taps through the watch app in the simulator: a full fast session from Start to the saved run.
/// `-noprompts` keeps Health and location off, so no permission prompt covers the screen.
final class WatchFlowTests: XCTestCase {
    private let shots = ProcessInfo.processInfo.environment["WATCH_SHOTS"]

    override func setUp() { continueAfterFailure = false }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-noprompts", "-uitest"] + args
        app.launch()
        return app
    }

    /// Keeps a screenshot with the test result, for a look at the layout.
    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testWarmupRunSaveAndHistory() {
        let app = launch(["-fast", "30"])
        XCTAssertTrue(app.staticTexts["Week 1, Run 1"].waitForExistence(timeout: 20))
        shot("01-home")
        app.buttons["Start"].tap()

        // The warmup: the first drill, then the controls page, then on to the run.
        XCTAssertTrue(app.staticTexts["A-SKIPS"].waitForExistence(timeout: 5))
        shot("02-warmup")
        app.swipeRight()
        XCTAssertTrue(app.buttons["Skip warmup"].waitForExistence(timeout: 5))
        shot("03-warmup-controls")
        app.buttons["Next drill"].tap()
        XCTAssertTrue(app.staticTexts["B-SKIPS"].waitForExistence(timeout: 5))
        app.swipeRight()
        app.buttons["Skip warmup"].tap()

        // The run: pause and resume from the controls page, look at the figures, then let it end.
        XCTAssertTrue(app.staticTexts["WARM UP"].waitForExistence(timeout: 5))
        shot("04-run")
        app.swipeRight()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
        shot("05-run-controls")
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 5))
        shot("06-paused")
        app.swipeRight()
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.staticTexts["PAUSED"].waitForNonExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Distance"].waitForExistence(timeout: 5))
        shot("07-figures")
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["RUN"].waitForExistence(timeout: 30))
        shot("08-run-interval")
        XCTAssertTrue(app.staticTexts["DONE"].waitForExistence(timeout: 120))
        shot("09-done")
        app.buttons["Finish"].tap()

        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 5))
        shot("10-summary")
        app.swipeUp()
        shot("11-summary-buttons")
        app.buttons["Save"].tap()

        // Home again, and the plan moved to the next session.
        XCTAssertTrue(app.staticTexts["Week 1, Run 2"].waitForExistence(timeout: 10))
        shot("12-home-next")
        app.swipeUp()
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Week 1, Run 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'waits for the iPhone'")).firstMatch.waitForExistence(timeout: 5))
        shot("13-history")
    }

    func testEndEarlyAndDiscardKeepsThePlan() {
        let app = launch(["-fast", "30", "-nowarmup"])
        XCTAssertTrue(app.staticTexts["Week 1, Run 1"].waitForExistence(timeout: 20))
        app.buttons["Start"].tap()
        XCTAssertTrue(app.staticTexts["WARM UP"].waitForExistence(timeout: 5))
        app.swipeRight()
        app.buttons["End"].tap()
        shot("20-end-dialog")
        app.buttons["End run"].tap()
        XCTAssertTrue(app.staticTexts["Ended early"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons["Discard"].tap()
        app.buttons["Discard run"].tap()
        XCTAssertTrue(app.staticTexts["Week 1, Run 1"].waitForExistence(timeout: 10))
    }

    func testPlanAndSettings() {
        let app = launch([])
        XCTAssertTrue(app.staticTexts["Week 1, Run 1"].waitForExistence(timeout: 20))
        app.swipeUp()
        app.buttons["The plan"].tap()
        XCTAssertTrue(app.staticTexts["Week 1"].waitForExistence(timeout: 5))
        shot("30-plan")
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Run 2'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Week 1, Run 2"].waitForExistence(timeout: 5))
        shot("31-session")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.swipeUp()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Voice cues"].waitForExistence(timeout: 5))
        shot("32-settings")
    }
}
