// XCUIApplication+Helpers.swift
// Rehearsal — Generic XCUITest helpers for any iOS project
// MIT licensed. Copy this file byte-identical into your UI test target; keep
// project-specific Page-Objects in a separate XCUIApplication+<YourApp>.swift.
//
// Category structure (per CONVENTIONS.md §Helper organization):
//   - Taps        — tap interactions
//   - Assertions  — element presence + text matching
//   - Input       — text entry
//   - Photo Library — system PhotosPicker interaction
//   - Lifecycle   — app launch + element waiting
//
// Future helpers slot into existing categories or add new MARK sections (per §5c extension seam).

import XCTest

public extension XCUIApplication {

    // MARK: - Taps

    /// Tap a button identified by its accessibility identifier.
    /// Waits up to `timeout` for the button to exist before tapping.
    /// XCTest assertion failure if the button never appears.
    func tapButton(id: String, timeout: TimeInterval = 5) {
        let button = buttons[id]
        XCTAssertTrue(
            button.waitForExistence(timeout: timeout),
            "Button with id '\(id)' did not appear within \(timeout)s"
        )
        button.tap()
    }

    /// Tap a button identified by its visible label (NOT accessibility id).
    /// Useful for system-provided buttons that don't have custom ids (e.g., "Continue", "Done").
    func tapButton(label: String, timeout: TimeInterval = 5) {
        let button = buttons[label]
        XCTAssertTrue(
            button.waitForExistence(timeout: timeout),
            "Button with label '\(label)' did not appear within \(timeout)s"
        )
        button.tap()
    }

    /// Tap any element by accessibility id, regardless of its trait/type.
    /// Use for SwiftUI `Button`s with custom content + `.buttonStyle(.plain)`,
    /// which often render as type `.other` and are missed by the typed
    /// `buttons[id]` query. See `Docs/TROUBLESHOOTING.md` §2.
    func tapElement(id: String, timeout: TimeInterval = 5) {
        let element = descendants(matching: .any)[id]
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element with id '\(id)' did not appear within \(timeout)s"
        )
        element.tap()
    }

    /// Long-press any element by accessibility id for `duration` seconds.
    /// Use for gesture-gated actions (press-to-confirm, drag handles) where a
    /// single tap is consumed by a dual-action gesture recognizer.
    func longPressElement(id: String, duration: TimeInterval = 1.2, timeout: TimeInterval = 5) {
        let element = descendants(matching: .any)[id]
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element with id '\(id)' did not appear within \(timeout)s"
        )
        element.press(forDuration: duration)
    }

    // MARK: - Assertions

    /// Assert an element is visible within `timeout`.
    /// Works for any element type — buttons, labels, images, etc.
    func assertVisible(id: String, timeout: TimeInterval = 5) {
        let element = descendants(matching: .any)[id]
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element with id '\(id)' was not visible within \(timeout)s"
        )
    }

    /// Assert an element is NOT visible within `timeout`.
    /// Used for verifying error overlays cleared, modals dismissed, etc.
    func assertNotVisible(id: String, timeout: TimeInterval = 5) {
        let element = descendants(matching: .any)[id]
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(
            result, .completed,
            "Element with id '\(id)' was still visible after \(timeout)s"
        )
    }

    /// Assert an element's text label matches the expected string (exact match).
    func assertText(id: String, matches expected: String, timeout: TimeInterval = 5) {
        let element = descendants(matching: .any)[id]
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element with id '\(id)' did not appear within \(timeout)s"
        )
        XCTAssertEqual(
            element.label, expected,
            "Element with id '\(id)' label was '\(element.label)', expected '\(expected)'"
        )
    }

    // MARK: - Input

    /// Tap a text field by id, clear its existing text, type the given string.
    /// Handles the focus + keyboard activation automatically.
    func typeText(_ text: String, into elementId: String, timeout: TimeInterval = 5) {
        let field = textFields[elementId]
        XCTAssertTrue(
            field.waitForExistence(timeout: timeout),
            "Text field with id '\(elementId)' did not appear within \(timeout)s"
        )
        field.tap()
        if let existing = field.value as? String, !existing.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)
            field.typeText(deleteString)
        }
        field.typeText(text)
    }

    // MARK: - Photo Library

    /// Pick a photo by name from the consumer app's bypass-seam fixture
    /// picker.
    ///
    /// Implementation: bypass-seam approach. Consumer must expose a debug-only
    /// fixture picker UI gated on a `--bypass-photos-picker` launch arg. This
    /// helper interacts with that UI surface, NOT the system PhotosPicker
    /// (whose iOS 26 XCUITest driveability is unverified).
    ///
    /// Accessibility id convention: `<app-prefix>.testFixture.<name>`
    /// (consumers reading Rehearsal docs see this convention in
    /// `CONVENTIONS.md` §1 + `Docs/ACCESSIBILITY_IDS.md` §Bypass-seam pattern).
    ///
    /// Predicate is `ENDSWITH ".testFixture.\(named)"` — exact-match safer
    /// than `CONTAINS[c]` (which could match unrelated elements with
    /// substring overlap).
    func pickPhotoFromLibrary(named: String, timeout: TimeInterval = 10) {
        let fixtureButton = descendants(matching: .button)
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".testFixture.\(named)"))
            .firstMatch
        XCTAssertTrue(
            fixtureButton.waitForExistence(timeout: timeout),
            "Fixture '\(named)' not found in bypass-seam picker. Confirm: (1) --bypass-photos-picker launch arg is set, (2) --fixture-dir=<path> launch arg is set, (3) consumer's debug UI exposes accessibility id '<app-prefix>.testFixture.\(named)', (4) prepare-simulator-fixtures.sh ran successfully."
        )
        fixtureButton.tap()
    }

    // MARK: - Lifecycle

    /// Wait for an element to exist; return the element if found, nil if timeout.
    /// Use when you need to conditionally branch on element presence (e.g., dismiss optional modal).
    @discardableResult
    func waitForElement(id: String, timeout: TimeInterval = 5) -> XCUIElement? {
        let element = descendants(matching: .any)[id]
        return element.waitForExistence(timeout: timeout) ? element : nil
    }

    /// Launch the app with mock-mode launch arguments set.
    /// Consumer passes their mock-mode flag set (e.g., ["--use-mock-api", "--unlimited-items"]).
    /// **Why this is a helper:** mock-mode launch is the canonical first call of every UI test in projects
    /// using the launch-arg-driven mock pattern (per MOCK_SERVICE_PATTERN.md). Centralizes the pattern.
    /// **No default:** the `args` parameter is REQUIRED to prevent silent production-mode launches that
    /// would defeat the helper's semantic promise.
    func launchWithMockMode(args: [String]) {
        precondition(!args.isEmpty, "launchWithMockMode requires at least one mock-mode launch argument — pass your consumer-defined flag(s) like [\"--use-mock-api\"]. Use the standard XCUIApplication.launch() if you want a production-mode launch.")
        launchArguments = args
        launch()
    }
}
