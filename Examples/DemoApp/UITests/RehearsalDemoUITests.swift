// RehearsalDemoUITests.swift
// Two runnable, green UI tests that drive the demo through Rehearsal's SHIPPED
// helpers (Sources/Helpers/XCUIApplication+Helpers.swift, referenced by
// project.yml — not copied). Both reach the SAME "Demo Success!" screen — one by
// tapping, one by SEEDING straight to it — and both freeze the app's continuous
// animation via the seam (`--reduce-motion`) so the run is deterministic.
import XCTest

final class RehearsalDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The journey: launch → "Hello" → tap → "Demo Success!".
    func test_tapHello_revealsSuccess() throws {
        let app = XCUIApplication()
        app.launchForUITest()

        app.assertVisible(id: "demo.hello.tap.button")
        app.tapButton(id: "demo.hello.tap.button")
        app.assertVisible(id: "demo.success.title.label")
    }

    /// The shortcut (Mode B state-seeding): launch SEEDED straight to success —
    /// the app boots on "Demo Success!" with no tap, because one launch argument
    /// told it where to start. The test never touches Hello.
    func test_seededStart_landsOnSuccess() throws {
        let app = XCUIApplication()
        app.launchAtSuccess()

        app.assertVisible(id: "demo.success.title.label")
        app.assertNotVisible(id: "demo.hello.tap.button")
    }
}
