// ReferenceUITestMethod.swift
// Rehearsal Example — complete end-to-end UI test method using the 9-helper set
//
// This file is NOT shipped as a runnable test (it's an example for documentation).
// Copy the pattern into your consumer project's UI test target.

import XCTest

final class ReferenceUITestMethod_Example: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// End-to-end pattern: launch with mock mode → drive flow → assert outcome.
    func test_exampleCartFlow() throws {
        // 1. Launch the app with consumer-specific mock-mode flags
        //    (this example uses a generic placeholder — replace with your
        //    consumer's flag set per MOCK_SERVICE_PATTERN.md)
        let app = XCUIApplication()
        app.launchWithMockMode(args: ["--use-mock-api"])

        // 2. Wait for the app to reach a known UI state
        app.assertVisible(id: "myapp.shell.tabBar", timeout: 10)

        // 3. Navigate via Page-Object-style helpers (in YOUR consumer extension file)
        //    These compose the generic helpers — see XCUIApplication+<YourApp>.swift
        app.tapButton(id: "myapp.shell.catalogTab")
        app.tapButton(id: "myapp.catalog.itemAdd.button")

        // 4. Drive a media-pick flow if your form takes a photo input
        //    (fixture pre-loaded via Scripts/prepare-simulator-fixtures.sh)
        app.pickPhotoFromLibrary(named: "fixture_sample")

        // 5. Wait for the mock-driven response to surface in UI
        app.assertVisible(id: "myapp.cart.itemsList.label", timeout: 5)
        app.assertText(id: "myapp.cart.itemCount.label", matches: "1")

        // 6. Complete the flow
        app.tapButton(id: "myapp.cart.checkout.button")
        app.assertNotVisible(id: "myapp.cart.itemsList.label", timeout: 3)
    }
}
