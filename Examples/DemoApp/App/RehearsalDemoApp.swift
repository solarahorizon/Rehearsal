// RehearsalDemoApp.swift
// The smallest SwiftUI app that exercises Rehearsal's launch-arg seam. The seam is
// read in App.init() — BEFORE the view tree binds — per Docs/STATE_SEEDING_PATTERN.md
// §4 (a real app would seed its persistent store here; the demo just picks the
// starting screen and whether the continuous backdrop animation runs).
import SwiftUI

@main
struct RehearsalDemoApp: App {
    private let start: DemoState
    private let reduceMotion: Bool

    init() {
        #if DEBUG
        start = TestModeConfig.startState ?? .hello
        reduceMotion = TestModeConfig.reduceMotion
        #else
        start = .hello
        reduceMotion = false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(start: start, reduceMotion: reduceMotion)
        }
    }
}
