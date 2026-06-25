// RehearsalDemoApp.swift
// The smallest possible SwiftUI app that exercises Rehearsal's launch-arg seam.
// The seam is read in App.init() — BEFORE the view tree binds — per
// Docs/STATE_SEEDING_PATTERN.md §4 (this is where a real app would seed its
// persistent store; the demo just picks the starting screen).
import SwiftUI

@main
struct RehearsalDemoApp: App {
    private let start: DemoState

    init() {
        #if DEBUG
        start = TestModeConfig.startState ?? .hello
        #else
        start = .hello
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(start: start)
        }
    }
}
