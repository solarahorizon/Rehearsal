# STATE_SEEDING_PATTERN.md

How to make an **offline / local-state** app deterministic under XCUITest by
seeding its starting state and randomness from a launch argument — the
companion to `MOCK_SERVICE_PATTERN.md` for apps that have no network service
to mock.

This doc covers:

1. When you want this instead of service-mocking
2. The same process boundary — different payload
3. The solution: a `#if DEBUG` launch-arg config, applied at app launch
4. WHERE to apply it (and the first-render race to avoid)
5. Typed launch presets in your Page-Object helper
6. Deterministic randomness
7. Worked example: the runnable DemoApp's `TestModeConfig`
8. Anti-patterns

---

## 1. Two adoption modes — which are you?

Rehearsal's launch-arg seam supports two payloads. Pick by what your app's
non-determinism actually *is*:

| | **Mode A — Service-mock** | **Mode B — State-seeding** |
|---|---|---|
| Your app's non-determinism comes from… | a network/API/service response | local persisted state + RNG (no server) |
| You swap… | a service/HTTP client for a mock | nothing — you *seed* SwiftData / Core Data / UserDefaults + the RNG |
| Reference | `MyApp` placeholder (network-backed) | [`Examples/DemoApp/`](../Examples/DemoApp/) (runnable SwiftUI) |
| Read | `MOCK_SERVICE_PATTERN.md` | **this doc** |

Many apps use **both** — mock the network seam *and* seed local state. The two
compose; they're just different launch args read at startup.

If your app makes no network calls in the flows you're testing (offline-first,
on-device, SwiftData/Core Data), Mode B is all you need — and there's nothing
to mock.

## 2. The same process boundary, a different payload

The process-boundary constraint from `MOCK_SERVICE_PATTERN.md` §1 is identical
here: the test process is separate from the app process, and the only thing it
can hand the app at startup is **launch arguments**
(`XCUIApplication.launchArguments`).

Mode A uses that channel to say *"return this canned service result."*
Mode B uses the same channel to say *"start from this exact state."* — e.g.
*"wipe persistence and start fresh,"* *"skip onboarding,"* *"seed one
fully-grown item,"* *"use RNG seed 42."* Same seam, different instruction.

## 3. The solution: a `#if DEBUG` launch-arg config, parsed once at startup

Put a debug-only config type in the **app target** that parses the launch
arguments into typed flags. Whole type wrapped in `#if DEBUG` so it physically
cannot ship in a release build:

```swift
// In your APP target — TestModeConfig.swift
#if DEBUG
import Foundation

enum TestModeConfig {
    private static let args = ProcessInfo.processInfo.arguments

    static var resetState: Bool   { args.contains("--reset-state") }
    static var skipOnboarding: Bool { args.contains("--skip-onboarding") }

    /// Parsed value flags use a `--flag=value` shape.
    static var randomSeed: UInt64? {
        value(for: "--seed-rng").flatMap(UInt64.init)
    }
    static var seedGrownItem: String? { value(for: "--seed-grown-item") }

    private static func value(for flag: String) -> String? {
        args.first { $0.hasPrefix("\(flag)=") }?
            .split(separator: "=", maxSplits: 1).last.map(String.init)
    }
}
#endif
```

When the whole type stays inside `#if DEBUG` (and is target-membered correctly),
release builds don't compile it — so the flags can't reach production, whatever
arguments are passed.

## 4. WHERE to apply the seed — before your state binds

This is the one subtle part, and it has bitten every adopter (see
`TROUBLESHOOTING.md` §4).

Apply the seed **before** your persistent store binds to the view tree —
ideally in `App.init()`:

```swift
@main
struct MyApp: App {
    init() {
        #if DEBUG
        if TestModeConfig.resetState { Persistence.wipeAndReseed() }
        Persistence.applyTestSeeds(TestModeConfig.self)
        #endif
    }
    var body: some Scene { WindowGroup { RootView() } }
}
```

**Do NOT** apply it in a `.task`/`.onAppear` on your root view. Those run
*after* the first body render, so a previously-persisted state renders briefly,
preloads heavy assets, *then* gets wiped and re-rendered — a flicker that races
your test's first assertion and produces order-dependent flake. Seed before the
store binds and the flicker doesn't exist.

## 5. Typed launch presets in your Page-Object helper

Don't scatter raw argument arrays across tests. Wrap each meaningful starting
state in a named preset in your `XCUIApplication+<YourApp>.swift` (the
Page-Object file from `CHECKLIST.md` §3). Each composes
`launchWithMockMode(args:)`:

```swift
extension XCUIApplication {
    /// Fresh store, onboarding shown.
    func launchFresh() {
        launchWithMockMode(args: ["--reset-state"])
    }
    /// Fresh store, onboarding skipped, jump to the main screen.
    func launchSkippingOnboarding() {
        launchWithMockMode(args: ["--reset-state", "--skip-onboarding"])
    }
    /// Skip onboarding AND seed one fully-grown item for a harvest test.
    func launchWithGrownItem(_ type: String) {
        launchWithMockMode(args: ["--reset-state", "--skip-onboarding",
                                  "--seed-grown-item=\(type)"])
    }
    /// Deterministic RNG for randomized systems (loot, shuffles, spawns).
    func launchDeterministic(seed: UInt64 = 42) {
        launchWithMockMode(args: ["--skip-onboarding", "--seed-rng=\(seed)"])
    }
}
```

Tests then read like prose: `app.launchWithGrownItem("appleTree")`. A test that
mutates state it later asserts on should always include the reset flag so a
prior run can't change its starting point.

## 6. Deterministic randomness

If any flow under test uses randomness (loot drops, shuffles, procedural
spawns), a launch-arg seed is the clean way to make assertions stable. Route
**all** randomness through a single injectable source and seed it from the
config:

```swift
#if DEBUG
if let seed = TestModeConfig.randomSeed {
    RandomSource.shared = SeededRandomSource(seed: seed)
}
#endif
```

The catch worth stating: parsing the seed flag is not the same as *using* it.
Make sure every random call site actually reads `RandomSource.shared` — a flag
that's parsed but not threaded through gives you false confidence (tests look
deterministic but aren't). Verify by running a randomized test twice with the
same seed and asserting identical outcomes.

## 7. Worked example: the runnable DemoApp's `TestModeConfig`

[`Examples/DemoApp/`](../Examples/DemoApp/) ("RehearsalDemo", offline SwiftUI)
uses Mode B exclusively — it makes no network calls, so there is nothing to
mock. It's a real, runnable example: run `xcodegen generate`, then ⌘U in Xcode
(or the `xcodebuild test` command in its [README](../Examples/DemoApp/README.md)),
and green UI tests drive the shipped helpers.

Its `TestModeConfig` (whole enum `#if DEBUG`) parses a small family of flags;
the same shape extends to whatever starting states your own app needs:

| Flag | Effect |
|---|---|
| `--skip-onboarding` | Skip the welcome screen, jump straight to the main screen |
| `--seed-count=<n>` | Seed the counter to a known starting value |

A larger app would add more flags in the same style, e.g. `--reset-state`
(wipe SwiftData and start fresh) or `--seed-rng=<n>` (seed the process-wide
RNG for any randomized system).

The config is applied in the app's launch path before SwiftData binds, and each
starting state is exposed as a typed preset (`launchSeededCounter(_:)`) in the
project's Page-Object helper (`XCUIApplication+RehearsalDemo.swift`). UI tests
assert on the real on-device UI produced from that seeded state — the same
screens a real user sees.

## 8. Anti-patterns

- **Seeding from the test target.** Same boundary rule as Mode A
  (`MOCK_SERVICE_PATTERN.md` §5): the seed logic lives in the **app target**,
  `#if DEBUG`-wrapped, selected at startup by the launch argument. The test
  process can't reach into the app's store.
- **Seeding in `.task`/`.onAppear`.** Causes the first-render race (§4 +
  `TROUBLESHOOTING.md` §4). Seed before the store binds.
- **Parsing a seed you never use.** Thread the RNG seed through every random
  call site, or your "deterministic" tests aren't (§6).
- **Letting flags leak to release.** The config type must be entirely inside
  `#if DEBUG`; never read a test flag from non-debug code.

## See also

- `MOCK_SERVICE_PATTERN.md` — Mode A (mock a network/service seam)
- `TROUBLESHOOTING.md` §4 — the first-render reset race in detail
- `CONVENTIONS.md` — launch-arg + accessibility-id naming
