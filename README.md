# Rehearsal

**Playwright-style UX testing for SwiftUI & iOS.** Drive your app on a simulator
the way a user would — launch, tap, type, assert what's on screen — as a
repeatable test.

Plain XCUITest, packaged: the launch-arg seam, accessibility-id conventions, a
fixture pipeline, and a dozen wrapper helpers, as files you copy into your UI
test target. No SPM package, no dependencies, no DSL. The aim is a first green UI
test in about a day on an app with a compatible seam — larger migrations vary.

> **Built from one app, then proven by reuse on others.** The patterns were worked
> out setting up my first app (network-backed), extracted into this toolkit, then
> reused to stand up testing on more — including an offline SwiftUI + SwiftData app.
> All in development; these patterns earned their place by being *reused across
> different shapes*, not extracted once. Every issue those later adoptions hit is
> written up in [`Docs/TROUBLESHOOTING.md`](Docs/TROUBLESHOOTING.md).

> **▶ See it run first.** [`Examples/DemoApp/`](Examples/DemoApp/) is a **runnable demo** — `xcodegen generate`, then run it (⌘U in Xcode, or the one `xcodebuild test` command in the [demo README](Examples/DemoApp/README.md)) — and watch **two green UI tests** drive the real helper file (not a copy). The fastest way to see what adoption looks like before you touch your own app.

<sub>Looking for "Playwright for iOS" / a "Maestro / Detox alternative" / a Cypress-style flow for SwiftUI? Same idea, implemented as plain XCUITest — no extra runtime or runner.</sub>

## What it is

A small, opinionated, copy-into-your-project toolkit for iOS UI test
automation built on Apple's XCUITest. Eleven generic helpers, a runnable demo +
reference examples, seven long-form docs, one fixture-loading script. No build container,
no SPM package, no transitive dependencies — just files you copy into your
project's UI test target.

## The problem it solves

Setting up XCUITest from scratch on a new iOS project is a multi-day slog of the
same decisions every time:

- Working out the launch-arg mock activation pattern (a clean way to swap
  services from the test process).
- Deciding where to put mocks so they actually link (app target, not test
  target — a common stumble).
- Settling on an accessibility-id naming convention that survives view
  refactors.
- Wiring up the simulator-fixture pipeline (`simctl addmedia` + canned
  responses).
- Writing the dozen-or-so wrapper helpers around XCUITest's verbose API so
  your tests don't drown in `waitForExistence(timeout:)` boilerplate.

Rehearsal packages all of that into a template-clone repo. The
`CHECKLIST.md` walks you through adoption in ~10 numbered steps; most
projects hit their first green UI test the same day.

## Who it's for

- iOS devs starting XCUI automation on a new project.
- iOS devs adding XCUI automation to an existing project (the migration
  recipe in `Docs/ACCESSIBILITY_IDS.md` walks through the id rewrite).
- iOS devs who want to copy a small, focused toolkit instead of pulling
  in a heavyweight framework (Maestro, Detox, etc.) with its own
  dependency surface.

## Two ways to adopt — pick your mode

Rehearsal's launch-argument seam supports two payloads. Pick by what makes
your app non-deterministic:

| If your app… | Use | Read | Reference |
|---|---|---|---|
| calls a network/API/service | **Mode A — service-mock** | [`Docs/MOCK_SERVICE_PATTERN.md`](Docs/MOCK_SERVICE_PATTERN.md) | `MyApp` placeholder (network-backed) |
| is offline / local-state (SwiftData, Core Data) | **Mode B — state-seeding** | [`Docs/STATE_SEEDING_PATTERN.md`](Docs/STATE_SEEDING_PATTERN.md) | [`Examples/DemoApp/`](Examples/DemoApp/) (runnable SwiftUI) |

Same seam, different instruction — Mode A says *"return this canned response,"*
Mode B says *"start from this exact state + RNG seed."* Apps that do both just
use both sets of flags. If your tested flows make no network calls, Mode B is
all you need.

## Quick start

1. Clone or download this repo.
2. Read `CHECKLIST.md` (~10 steps; ~1-day adoption target).
3. Copy `Sources/Helpers/XCUIApplication+Helpers.swift` into your
   project's `<YourApp>UITests/Helpers/` directory (byte-identical).
4. Pick your mode (above): `Docs/MOCK_SERVICE_PATTERN.md` (network app) or
   `Docs/STATE_SEEDING_PATTERN.md` (offline / local-state app).
5. Implement your launch-arg seam — a mock or a state-seed — in the **app
   target** (`Examples/ReferenceMockService.swift` for Mode A).
6. Write your first test using the pattern in
   `Examples/ReferenceUITestMethod.swift`.
7. Hit a SwiftUI/simulator snag? `Docs/TROUBLESHOOTING.md` has the 7 most
   common ones.

## What's in scope

- **11 generic XCUITest helpers** in `Sources/Helpers/XCUIApplication+Helpers.swift`
  (Taps, Assertions, Input, Photo Library, Lifecycle).
- **Launch-arg seam, two modes** — mock a network/service
  (`Docs/MOCK_SERVICE_PATTERN.md`, Option A/B) or seed local state + RNG for
  offline apps (`Docs/STATE_SEEDING_PATTERN.md`).
- **Fixture pipeline** documented in `Docs/FIXTURE_PIPELINE.md` with the
  `<name>.<ext>` + `<name>.<sha>.json` naming convention.
- **Accessibility-id naming convention** documented in
  `Docs/ACCESSIBILITY_IDS.md` — the 4-segment
  `<app-prefix>.<feature>.<element>.<state>` namespace.
- **Reusable shell wrapper** at `Scripts/prepare-simulator-fixtures.sh`
  for `simctl addmedia` pre-test setup.

## What's out of scope (anti-goals)

Rehearsal deliberately does NOT include:

- **Snapshot testing.** Use `swift-snapshot-testing` if you want pixel
  comparisons.
- **CI integration.** Your CI tool is your business; Rehearsal
  doesn't ship `.yml` config.
- **Cross-platform support.** iOS only. Android-side and web-side UI
  testing are separate problems with separate tools.
- **Multi-framework abstraction.** Not a thin layer over Maestro / Detox.
  Pure XCUITest.
- **SPM packaging.** Rehearsal is intentionally a template-clone repo
  (see `CONVENTIONS.md`). Copy files; don't add a dependency.
- **Multi-app orchestration.** Single-app UI testing.

## Solo-maintainer expectation

Rehearsal is a personal project maintained by one person in spare time.
**There is no SLA.** Best-effort response to issues. The toolkit is
released for the community in case it's useful; it's not a vendor-backed
framework.

If you adopt Rehearsal, you own your fork. Pull requests welcome but
not guaranteed a review. File issues for discussion; expect informal
turnaround.

## License

MIT. See `LICENSE` for the standard SPDX template.

## Links

- [`CHECKLIST.md`](CHECKLIST.md) — 10-step adoption guide
- [`CONVENTIONS.md`](CONVENTIONS.md) — naming + organization conventions
- [`Docs/MOCK_SERVICE_PATTERN.md`](Docs/MOCK_SERVICE_PATTERN.md) — Mode A: mock a service
- [`Docs/STATE_SEEDING_PATTERN.md`](Docs/STATE_SEEDING_PATTERN.md) — Mode B: seed local state + RNG
- [`Docs/FIXTURE_PIPELINE.md`](Docs/FIXTURE_PIPELINE.md)
- [`Docs/ACCESSIBILITY_IDS.md`](Docs/ACCESSIBILITY_IDS.md)
- [`Docs/TROUBLESHOOTING.md`](Docs/TROUBLESHOOTING.md) — SwiftUI / XCUITest / simulator gotchas
- [`Docs/UPDATING.md`](Docs/UPDATING.md) — re-syncing the helper when Rehearsal changes
- [`Docs/CI_EXAMPLE.md`](Docs/CI_EXAMPLE.md) — reference GitHub Actions workflow (copy + adapt)
- [`Examples/DemoApp/`](Examples/DemoApp/) — **runnable demo** (clone → generate → test → green)
- [`Examples/`](Examples/) — code skeletons + the runnable demo
