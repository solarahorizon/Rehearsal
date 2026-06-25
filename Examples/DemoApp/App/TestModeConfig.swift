// TestModeConfig.swift
// The launch-arg seam. Parses launch arguments into typed test flags. The WHOLE
// type is wrapped in #if DEBUG so it physically cannot ship in a Release build.
// See Docs/STATE_SEEDING_PATTERN.md.
#if DEBUG
import Foundation

enum TestModeConfig {
    private static let args = ProcessInfo.processInfo.arguments

    /// `--start-at=<state>` → boot straight to a named screen instead of the
    /// default `.hello`. The demo uses `--start-at=success` to seed past the
    /// greeting and land on the success screen with no tap — state-seeding in
    /// one launch argument.
    static var startState: DemoState? {
        value(for: "--start-at").flatMap(DemoState.init(rawValue:))
    }

    /// `--reduce-motion` → freeze the continuous backdrop animation. UI tests pass
    /// this so the app can go "idle" between steps (XCUITest waits for idle; a
    /// never-ending animation would otherwise hang the test).
    static var reduceMotion: Bool { args.contains("--reduce-motion") }

    /// Shared parser for `--flag=value` payloads (per STATE_SEEDING_PATTERN.md §3).
    private static func value(for flag: String) -> String? {
        args.first { $0.hasPrefix("\(flag)=") }?
            .split(separator: "=", maxSplits: 1).last.map(String.init)
    }
}
#endif
