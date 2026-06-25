// TestModeConfig.swift
// Mode B — state-seeding seam. Parses launch arguments into typed test flags.
// The WHOLE type is wrapped in #if DEBUG so it physically cannot ship in a
// Release build. See Docs/STATE_SEEDING_PATTERN.md.
#if DEBUG
import Foundation

enum TestModeConfig {
    private static let args = ProcessInfo.processInfo.arguments

    /// `--skip-onboarding` → start on the counter, not the onboarding screen.
    static var skipOnboarding: Bool { args.contains("--skip-onboarding") }

    /// `--seed-count=<n>` → start the counter at n.
    static var seedCount: Int? { value(for: "--seed-count").flatMap(Int.init) }

    /// Shared parser for `--flag=value` payloads (per STATE_SEEDING_PATTERN.md §3).
    private static func value(for flag: String) -> String? {
        args.first { $0.hasPrefix("\(flag)=") }?
            .split(separator: "=", maxSplits: 1).last.map(String.init)
    }
}
#endif
