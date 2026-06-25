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

> **Running in Xcode?** Set the destination to an **iOS Simulator** (not a physical
> device) before ⌘U. UI tests run on the simulator; a device build would ask for
> your own signing team (`Signing for "RehearsalDemo" requires a development team`).

## What it demonstrates
- **The launch-arg seam (Mode B — state-seeding).** `App/TestModeConfig.swift` parses
  `--start-at=<state>` into a typed flag, whole type `#if DEBUG` so it can't ship in
  Release. The seam is read in `App.init()`, before the view tree binds.
- **The 4-segment accessibility-id convention** (`<app>.<feature>.<element>.<state>`, e.g. `demo.hello.tap.button`, `demo.success.title.label`) — see the views.
- **The shipped helpers drive the test.** The UI-test target *references the real*
  `Sources/Helpers/XCUIApplication+Helpers.swift` (via `project.yml`), not a copy — so a
  green run validates the actual helper file, with no drift.
- **Animating apps under test (a real gotcha).** The backdrop runs a *continuous*
  neon animation (a 360° rotation + a breathing zoom). A never-ending animation stops
  the app going "idle", and XCUITest waits for idle before every step — so it would
  hang. The fix is the seam: both tests pass `--reduce-motion`, which freezes the
  motion. Beautiful in normal use, deterministic under test — demonstrated end-to-end.

## The two tests

Both reach the **same** "Demo Success!" screen — one by tapping, one by *seeding
straight to it*. That contrast is Mode B in a nutshell.

| Test | Shows |
|---|---|
| `test_tapHello_revealsSuccess` | the journey — launch → "Hello" → `tapButton` → "Demo Success!" (`assertVisible`) |
| `test_seededStart_landsOnSuccess` | the shortcut — `--start-at=success` boots straight to "Demo Success!", **no tap** (state-seeding) |

Both presets also pass `--reduce-motion`, freezing the continuous backdrop so the
run stays idle-able (see "Animating apps under test" above).

This demo is **Mode B** (offline / local-state). For a network app, the **Mode A**
service-mock seam is in [`../../Docs/MOCK_SERVICE_PATTERN.md`](../../Docs/MOCK_SERVICE_PATTERN.md).
