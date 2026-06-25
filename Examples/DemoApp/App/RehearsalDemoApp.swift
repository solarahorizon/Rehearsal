// RehearsalDemoApp.swift
// The smallest possible SwiftUI app that exercises Rehearsal's launch-arg seam.
// The seam is read in App.init() — BEFORE the view tree binds — per
// Docs/STATE_SEEDING_PATTERN.md §4 (this is where a real app would seed its
// persistent store; the demo just computes the starting values).
import SwiftUI

@main
struct RehearsalDemoApp: App {
    private let startOnboarding: Bool
    private let startCount: Int

    init() {
        #if DEBUG
        startOnboarding = !TestModeConfig.skipOnboarding
        startCount = TestModeConfig.seedCount ?? 0
        #else
        startOnboarding = true
        startCount = 0
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(startOnboarding: startOnboarding, startCount: startCount)
        }
    }
}
