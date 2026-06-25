# CHECKLIST.md

Adoption checklist for Rehearsal. Aim: a first green UI test in about a day on
an app with a compatible seam — larger migrations vary.

Each step is a separate commit checkpoint — small, reviewable, revertable.

---

## Step 1: Clone Rehearsal at the latest stable commit

Pick the latest tag (e.g., `v1.0.0`) and clone it locally. Rehearsal is
a template-clone repo — you'll copy files into YOUR project, you won't
add it as a dependency.

```
git clone https://github.com/<owner>/Rehearsal.git ~/dev/Rehearsal
```

(Clone it parallel to your consumer repo, e.g. at `~/dev/Rehearsal/`,
so the `cmp -s` byte-identity checks below have a stable path.)

## Step 2: Copy the 11 generic helpers into your UI test target

Copy `Sources/Helpers/XCUIApplication+Helpers.swift` byte-identically
into `<YourApp>UITests/Helpers/XCUIApplication+Helpers.swift`.

Verify byte-identity:

```
cmp -s ~/dev/Rehearsal/Sources/Helpers/XCUIApplication+Helpers.swift \
       <YourApp>UITests/Helpers/XCUIApplication+Helpers.swift
# exit 0 = byte-identical
```

Optionally create a `<YourApp>UITests/ADOPTION_DELTAS.md` file to
document any future deviations from byte-identity.

## Step 3: Create your project-domain Page-Object helper file

In `<YourApp>UITests/Helpers/`, create
`XCUIApplication+<YourApp>.swift`. This is where your project-specific
Page-Object helpers live (e.g., `openLoginFlow()`,
`completeOnboarding()`, `dismissPaywall()`). They COMPOSE the 11 generic
helpers from Step 2.

Don't put project-specific helpers in `XCUIApplication+Helpers.swift` —
keep that file byte-identical to the upstream so you can re-sync on
upstream updates.

## Step 4: Pick your adoption mode (A: service-mock vs B: state-seeding)

Pick by what makes your app non-deterministic:

- **Mode A — service-mock** (your app calls a network/API/service). Read
  `Docs/MOCK_SERVICE_PATTERN.md`, then choose the seam layer:
  - *Option A (high-level service protocol)* — simple canned-`Result` mocking.
  - *Option B (low-level HTTP client)* — end-to-end coverage through the
    parsing / domain / view-model pipeline. **Recommended default.**
- **Mode B — state-seeding** (offline / local-state app — SwiftData, Core
  Data, on-device). Read `Docs/STATE_SEEDING_PATTERN.md`. There's no service
  to mock; you seed local state + RNG via launch args.

Apps that do both use both. Steps 5–7 below are written Mode-A-first; the
**Mode B equivalents** are in `STATE_SEEDING_PATTERN.md` (§3 the `TestModeConfig`
parser, §4 applying it in `App.init()`, §5 typed launch presets — and you can
skip Step 7's fixture pipeline unless your flows take media input).

## Step 5: Implement your mock in the APP target

Create `<YourApp>/UITestSupport/Mock<Service>.swift` (or wherever fits
your folder convention). **It MUST be in your app target, not the UI
test target.** Wrap the entire file in `#if DEBUG`:

```swift
#if DEBUG
import Foundation

struct MockHTTPClient: HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // canned-response lookup logic (see FIXTURE_PIPELINE.md §4)
    }
}
#endif
```

See `Examples/ReferenceMockService.swift` for both Option A and Option B
skeletons.

## Step 6: Add the launch-arg lazy-static at your service seam

At your seam declaration (the static or instance that production reads),
gate on `ProcessInfo.processInfo.arguments.contains("--use-mock-<service>")`:

```swift
static var httpClient: HTTPClient = {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--use-mock-api") {
        return MockHTTPClient()
    }
    #endif
    return URLSession.shared
}()
```

Naming: use `--use-mock-<service>` (lowercase, hyphenated). Add the flag
to your project's README "known launch arguments" list so future
contributors find it.

## Step 7: Set up the fixture pipeline

Copy `Scripts/prepare-simulator-fixtures.sh` byte-identically into your
project (e.g., `<YourApp>UITests/Scripts/prepare-simulator-fixtures.sh`)
and `chmod +x` it.

Author fixture pairs per `Docs/FIXTURE_PIPELINE.md` §2 conventions:

```
<YourApp>UITests/Fixtures/
├── fixture_<name>.jpg
├── fixture_<name>.<sha256>.json
└── ...
```

Pre-test invocation:

```
./<YourApp>UITests/Scripts/prepare-simulator-fixtures.sh "iPhone 17 Pro" \
    <YourApp>UITests/Fixtures/
```

## Step 8: Migrate accessibility identifiers to the 4-segment namespace

Per `Docs/ACCESSIBILITY_IDS.md` §4 migration recipe:

1. Grep your view code for `.accessibilityIdentifier(` calls.
2. Rewrite each to `<app-prefix>.<feature>.<element>.<state>` shape.
3. Update existing UI tests (if any) to query the new ids.
4. Optionally add a lint rule rejecting non-conforming ids.

This is the one project-side migration step — every other step is a
copy. Plan for a few hours if the project has accumulated organic flat
strings.

## Step 9: Write your first hello-world UI test

In `<YourApp>UITests/`, create `HelloWorldUITest.swift`:

```swift
import XCTest

final class HelloWorldUITest: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_launches() throws {
        let app = XCUIApplication()
        app.launchWithMockMode(args: ["--use-mock-api"])
        app.assertVisible(id: "myapp.shell.tabBar", timeout: 10)
    }
}
```

Run via Cmd+U in Xcode or `xcodebuild test -scheme <YourApp>UITests
-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`. Should pass.

If it fails, the most common causes:

- Mock didn't link (Step 5 — wrong target).
- Launch arg name mismatch (Step 6 string vs Step 9 string).
- Tab bar id doesn't exist (Step 8 — accessibility id migration
  incomplete).

## Step 10: Add CI integration (optional)

Rehearsal doesn't ship a CI config — your CI tool is your choice. The
shape of the integration is typically:

1. Boot a simulator.
2. Run `./Scripts/prepare-simulator-fixtures.sh` to load fixtures.
3. Run `xcodebuild test -scheme <YourApp>UITests -destination ...`.
4. Capture the `.xcresult` artifact for failure debugging.

Most CI systems (GitHub Actions, CircleCI, Bitrise, Xcode Cloud) have
existing recipes for the first and third steps. The second step is the
only Rehearsal-specific addition.

---

## After Step 10

You have:

- A working hello-world UI test.
- A documented mock pattern for adding more.
- A fixture pipeline for photo / media inputs.
- A naming convention for accessibility ids.

Next: extend by writing the next test. The 11 helpers + Page-Object
pattern compose; most flows are ~20-line tests once the chassis is in
place.
