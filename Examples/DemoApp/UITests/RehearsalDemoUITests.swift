// RehearsalDemoUITests.swift
// A runnable, green UI test that drives the demo app through Rehearsal's SHIPPED
// helpers (Sources/Helpers/XCUIApplication+Helpers.swift, referenced by project.yml
// — not copied). A passing run proves the real helpers work. Launches go through
// the named presets in XCUIApplication+RehearsalDemo.swift, per the docs.
import XCTest

final class RehearsalDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// State-seeding (Mode B): launch straight onto the counter, seeded to 5,
    /// then increment — deterministic, no network.
    func test_seededCounter_incrementsFromSeed() throws {
        let app = XCUIApplication()
        app.launchSeededCounter(5)   // named preset → --skip-onboarding --seed-count=5

        app.assertText(id: "demo.counter.value.label", matches: "5")
        app.tapButton(id: "demo.counter.increment.button")
        app.assertText(id: "demo.counter.value.label", matches: "6")
    }

    /// Default path: no seam flags → plain `launch()`. (The shipped
    /// `launchWithMockMode` requires at least one flag by design, so the
    /// production/default path uses the standard launch.) Onboarding shows;
    /// "Get Started" navigates to a fresh (zero) counter.
    func test_onboarding_navigatesToCounter() throws {
        let app = XCUIApplication()
        app.launch()

        app.assertVisible(id: "demo.onboarding.start.button")
        app.tapButton(id: "demo.onboarding.start.button")
        app.assertVisible(id: "demo.counter.value.label")
        app.assertText(id: "demo.counter.value.label", matches: "0")
    }
}
