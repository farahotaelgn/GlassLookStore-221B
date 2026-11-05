import XCTest

/// Quality gates on the simulator (Codemagic): screenshots of every tab in light and dark, the drag lens (slow drag,
/// fast flick, tap, past the edges) and the built-in 🧪 Test. Screenshots go to SCREENSHOT_DIR when it is set
/// (Codemagic passes TEST_RUNNER_SCREENSHOT_DIR) and are attached to the test report too.
@MainActor
final class GlassLookStoreUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", mode]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = app.screenshot().pngRepresentation
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    /// Settings is a Form: rows further down load only when scrolled into view.
    private func scrollTo(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let e = app.descendants(matching: .any)[id]
        var tries = 0
        while !e.exists && tries < 8 {
            app.swipeUp()
            tries += 1
        }
        return e
    }

    private func tab(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.descendants(matching: .any)["tab.\(title)"]
    }

    private func screenshotsOfEveryTab(_ mode: String, _ suffix: String) {
        let app = launch(mode)
        XCTAssertTrue(tab(app, "Live").waitForExistence(timeout: 10))
        sleep(2)
        shot(app, "Live-\(suffix)")
        for t in ["Projects", "Stats", "Logs", "Settings"] {
            tab(app, t).tap()
            sleep(1)
            XCTAssertEqual(tab(app, t).value as? String, "selected", "\(t) should be selected after a tap")
            shot(app, "\(t)-\(suffix)")
        }
        tab(app, "Live").tap()
        sleep(1)
        app.terminate()
    }

    func testScreenshotsLight() { screenshotsOfEveryTab("-forceLight", "Light") }

    func testScreenshotsDark() { screenshotsOfEveryTab("-forceDark", "Dark") }

    func testDragLens() {
        let app = launch("-forceLight")
        let live = tab(app, "Live"), stats = tab(app, "Stats"), settings = tab(app, "Settings")
        XCTAssertTrue(live.waitForExistence(timeout: 10))

        // Slow drag from Live to Stats: lands on Stats.
        let from = live.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = stats.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.3, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        sleep(1)
        XCTAssertEqual(stats.value as? String, "selected", "slow drag should land on Stats")
        shot(app, "Lens-SlowDrag")

        // Fast flick from Stats past the right edge: lands on Settings, never outside the bar.
        let past = settings.coordinate(withNormalizedOffset: CGVector(dx: 3, dy: 0.5))
        to.press(forDuration: 0.05, thenDragTo: past, withVelocity: .fast, thenHoldForDuration: 0)
        sleep(1)
        XCTAssertEqual(settings.value as? String, "selected", "flick past the edge should land on Settings")

        // Drag past the left edge: lands on Live.
        let farLeft = live.coordinate(withNormalizedOffset: CGVector(dx: -3, dy: 0.5))
        settings.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.2, thenDragTo: farLeft)
        sleep(1)
        XCTAssertEqual(live.value as? String, "selected", "drag past the left edge should land on Live")

        // Tap: the lens moves over with the same spring.
        stats.tap()
        sleep(1)
        XCTAssertEqual(stats.value as? String, "selected")
        shot(app, "Lens-Tap")
    }

    func testBuiltInSelfTestPasses() {
        let app = launch("-forceLight")
        XCTAssertTrue(tab(app, "Settings").waitForExistence(timeout: 10))
        tab(app, "Settings").tap()
        let row = scrollTo(app, "settings.test")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "🧪 Test row not found in Settings")
        row.tap()
        let run = app.buttons["test.run"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        let state = app.staticTexts["test.state"]
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "the app closed while the 🧪 Test ran (crash report in the Codemagic artifacts)")
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline && !(state.label.contains("Passed") || state.label.contains("Failed") || state.label.contains("Stopped")) { sleep(1) }
        shot(app, "SelfTest")
        XCTAssertTrue(state.label.contains("Passed"), "the built-in 🧪 Test said \(state.label); see the SelfTest screenshot")
    }

    func testVersionIsShownInSettings() {
        let app = launch("-forceLight")
        XCTAssertTrue(tab(app, "Settings").waitForExistence(timeout: 10))
        tab(app, "Settings").tap()
        let version = scrollTo(app, "settings.version")
        XCTAssertTrue(version.waitForExistence(timeout: 5), "Version row not found in Settings")
        shot(app, "Settings-Version")
    }
}
