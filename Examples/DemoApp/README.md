# Rehearsal — Runnable Demo

A tiny SwiftUI app + a **green UI test** that proves Rehearsal works end-to-end.
This is the "see it run before you adopt it" example: clone → generate → test → watch it pass.

## Run it
```bash
cd Examples/DemoApp
xcodegen generate          # builds RehearsalDemo.xcodeproj from project.yml (gitignored)

# simulator names vary by Xcode version — pick one you actually have installed:
xcrun simctl list devices available | grep iPhone

xcodebuild test \
  -project RehearsalDemo.xcodeproj \
  -scheme RehearsalDemo \
  -destination 'platform=iOS Simulator,name=iPhone 16'   # ← adjust to one from the list above
```
Expect `** TEST SUCCEEDED **` (2 tests).

## What it demonstrates
- **The launch-arg seam (Mode B — state-seeding).** `App/TestModeConfig.swift` parses
  `--skip-onboarding` and `--seed-count=<n>` into typed flags, whole type `#if DEBUG`
  so it can't ship in Release. The seam is applied in `RootView.init()`.
- **The 4-segment accessibility-id convention** (`<app>.<feature>.<element>.<state>`, e.g. `demo.counter.value.label`) — see the views.
- **The shipped helpers drive the test.** The UI-test target *references the real*
  `Sources/Helpers/XCUIApplication+Helpers.swift` (via `project.yml`), not a copy — so a
  green run validates the actual helper file, with no drift.

## The two tests
| Test | Shows |
|---|---|
| `test_seededCounter_incrementsFromSeed` | seed state deterministically (`--seed-count=5`), then `tapButton`/`assertText` |
| `test_onboarding_navigatesToCounter` | default launch (no flags) → `assertVisible`/`tapButton` navigation |

This demo is **Mode B** (offline / local-state). For a network app, the **Mode A**
service-mock seam is in [`../../Docs/MOCK_SERVICE_PATTERN.md`](../../Docs/MOCK_SERVICE_PATTERN.md).
