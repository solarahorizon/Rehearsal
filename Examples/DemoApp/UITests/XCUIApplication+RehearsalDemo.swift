// XCUIApplication+RehearsalDemo.swift
// Page-Object presets for the demo. Each meaningful starting state is a named
// launch that composes the shipped `launchWithMockMode(args:)` helper, so tests
// read like prose instead of scattering raw argument arrays (per
// Docs/STATE_SEEDING_PATTERN.md §5). This is the per-project file CHECKLIST.md
// §3 has you create alongside the generic helpers.
import XCTest

extension XCUIApplication {
    /// Seed straight to the success screen (Mode B) — skips the greeting + the tap.
    func launchAtSuccess() {
        launchWithMockMode(args: ["--start-at=success"])
    }
}
