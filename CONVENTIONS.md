# CONVENTIONS.md

Condensed convention reference. For long-form rationale, see `Docs/`.

---

## 1. Accessibility-id namespace

Format: `<app-prefix>.<feature>.<element>.<state>` (4 segments, dot-joined).

| Segment | Token shape | Example |
|---|---|---|
| `<app-prefix>` | lowercase, one word | `myapp` |
| `<feature>` | lowercase, one word | `cart` |
| `<element>` | lowerCamelCase, one word | `itemRemove` |
| `<state>` | lowercase, one word | `button` |

Dynamic-collection elements use a 5th segment (zero-based index or stable
disambiguator):

```
myapp.cart.itemRemove.button.0
myapp.cart.itemRemove.button.1
```

### 1a. `testFixture.<name>` — bypass-seam fixture-picker convention

When using the `--bypass-photos-picker` launch arg pattern with
`pickPhotoFromLibrary(named:)`, the consumer app's debug fixture cells
expose accessibility ids of the form:

```
<app-prefix>.testFixture.<name>
```

`<name>` matches the fixture filename basename (without extension). The
helper queries by `ENDSWITH ".testFixture.\(named)"`, so the leading
`<app-prefix>` segment can vary per consumer without breaking the
helper.

Example: `myapp.testFixture.sample_image`.

See `Docs/ACCESSIBILITY_IDS.md` for full rationale + migration recipe.

## 2. Launch-arg mock pattern

Flag naming: `--use-mock-<service>` (lowercase, hyphenated).

Activation shape:

```swift
static var service: ServiceProtocol = {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--use-mock-<service>") {
        return MockService()
    }
    #endif
    return LiveService()
}()
```

Discipline:

- Mock implementation file is whole-file `#if DEBUG`-wrapped.
- Mock lives in the APP target, NOT the UI test target.
- One launch-arg per mockable service; combine in test launches:
  `app.launchWithMockMode(args: ["--use-mock-api", "--unlimited-items"])`.

See `Docs/MOCK_SERVICE_PATTERN.md` for full rationale + seam-layer
choice.

## 3. Fixture naming

For each fixture, two paired files:

```
fixture_<name>.<ext>                       # the media
fixture_<name>.<sha256>.json               # the canned mock response
```

Where `<sha256>` is the SHA-256 of the media bytes (64 hex chars). The
paired filename is bound to the media's bytes — if media content
changes, the canned filename changes too.

Naming rules:

- Lowercase, underscore-separated.
- `fixture_` prefix for grep-ability.
- Media extension is what the production app expects (`.jpg`, `.png`,
  `.heic`, `.mp4`, `.m4a`).
- One canned-response file per fixture.

See `Docs/FIXTURE_PIPELINE.md` for full rationale + script invocation.

## 4. Helper organization

`Sources/Helpers/XCUIApplication+Helpers.swift` (the 11-helper generic
file) uses `// MARK:` sections to group helpers by category:

```swift
// MARK: - Taps
//   - tapButton(id:timeout:)
//   - tapButton(label:timeout:)

// MARK: - Assertions
//   - assertVisible(id:timeout:)
//   - assertNotVisible(id:timeout:)
//   - assertText(id:matches:timeout:)

// MARK: - Input
//   - typeText(_:into:timeout:)

// MARK: - Photo Library
//   - pickPhotoFromLibrary(named:timeout:)

// MARK: - Lifecycle
//   - waitForElement(id:timeout:)
//   - launchWithMockMode(args:)
```

New helpers slot into existing categories or add new MARK sections.
Don't reorder existing MARK sections — order is stable in v1.0+.

Project-specific Page-Object helpers go in a SEPARATE file
(`XCUIApplication+<YourApp>.swift`), NOT in
`XCUIApplication+Helpers.swift`. The generic file stays byte-identical
to the Rehearsal upstream so it can be re-synced on upstream updates.

## 5. UITest target settings

For a `<YourApp>UITests` target:

- `productType = com.apple.product-type.bundle.ui-testing`
- `USES_XCTRUNNER = YES`
- **OMIT** `TEST_HOST` and `BUNDLE_LOADER` (UI test targets are
  out-of-process — they don't host or load the app).
- `TEST_TARGET_NAME = <YourApp>` (the app target it tests).

If you use Xcode 16+ synced root groups (`PBXFileSystemSynchronizedRootGroup`),
new files in `<YourApp>UITests/` auto-discover — no pbxproj edits
needed for new test files. If you need to exclude a non-code file from
the test bundle resources (e.g., an `ADOPTION_DELTAS.md` doc), add a
`PBXFileSystemSynchronizedBuildFileExceptionSet` entry.

## 6. Per-test launch args

Set launch args ON `XCUIApplication.launchArguments` in the test
method body (or `setUp`), NOT on the Xcode scheme:

```swift
func test_something() throws {
    let app = XCUIApplication()
    app.launchWithMockMode(args: ["--use-mock-api"])
    // ...
}
```

Scheme-level launch args apply to every test run launched from the
scheme — fine for `--unlimited-items`-style "default for all UI tests",
but bad for per-test mock-mode toggling. Prefer per-test
`launchArguments` assignment for anything test-specific.

## 7. Byte-identity discipline

If you've adopted `Sources/Helpers/XCUIApplication+Helpers.swift` byte-
identically, run `cmp -s` between upstream and your copy at adoption
time AND any time you suspect a drift:

```
cmp -s ~/dev/Rehearsal/Sources/Helpers/XCUIApplication+Helpers.swift \
       <YourApp>UITests/Helpers/XCUIApplication+Helpers.swift
# exit 0 = byte-identical
# exit 1 = bytes differ — see ADOPTION_DELTAS.md
```

Any intentional deviation goes in `<YourApp>UITests/ADOPTION_DELTAS.md`.
The deviation log is the escape hatch for upstream-blocked changes.

---

For long-form rationale on any of the above, see the matching `Docs/`
file or the worked example in `Examples/`.
