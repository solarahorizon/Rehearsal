// XCUIApplication+RehearsalDemo.swift
// Page-Object presets for the demo. Each meaningful launch is a named helper that
// composes the shipped `launchWithMockMode(args:)`, so tests read like prose (per
// Docs/STATE_SEEDING_PATTERN.md §5). Both presets pass `--reduce-motion`: the seam
// controls MOTION as well as state, freezing the continuous backdrop so XCUITest's
// wait-for-idle can't hang. This is the per-project file CHECKLIST.md §3 has you
// create alongside the generic helpers.
import XCTest

extension XCUIApplication {
    /// The normal journey (start on "Hello"), with the continuous animation frozen
    /// for a deterministic, hang-free test.
    func launchForUITest() {
        launchWithMockMode(args: ["--reduce-motion"])
    }

    /// Seed straight to the success screen (Mode B) — skips the greeting + the tap,
    /// animation frozen.
    func launchAtSuccess() {
        launchWithMockMode(args: ["--start-at=success", "--reduce-motion"])
    }
}
