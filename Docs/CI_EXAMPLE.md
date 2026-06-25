# CI_EXAMPLE.md — a reference GitHub Actions workflow

> **Reference only — not part of the toolkit.** Rehearsal ships no CI config (it's
> a stated anti-goal in the README). This is a worked example you copy into *your*
> repo and adapt; it isn't maintained as a Rehearsal component. It runs the
> [`Examples/DemoApp`](../Examples/DemoApp) demo as the concrete target — swap the
> project/scheme/working-directory for your own app.

Running XCUITest in CI is its own little gotcha-fest (runner image, Xcode
selection, which simulators exist, fixture loading, capturing failures). This
gets you past all of them.

## `.github/workflows/ui-tests.yml`

```yaml
name: UI Tests
on: [push, pull_request]

jobs:
  ui-tests:
    runs-on: macos-15            # pick a runner image that has the Xcode you need
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        # adjust to a version the runner image has — list them with: ls /Applications | grep Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      # The demo generates its project with XcodeGen — its .xcodeproj is gitignored, so
      # this step is REQUIRED for the demo. Apps that commit their .xcodeproj can skip it.
      - name: Generate project
        working-directory: Examples/DemoApp
        run: brew install xcodegen && xcodegen generate

      # Only if you use the fixture pipeline (Scripts/prepare-simulator-fixtures.sh).
      # The sim must be BOOTED first AND be the SAME device as your test -destination
      # (the script takes the device name as its first arg; default is "iPhone 17 Pro").
      # - name: Boot simulator + load fixtures
      #   run: |
      #     xcrun simctl boot 'iPhone 16' || true
      #     ./Scripts/prepare-simulator-fixtures.sh 'iPhone 16'

      - name: Run UI tests
        working-directory: Examples/DemoApp
        run: |
          set -o pipefail   # CRITICAL: without this, a failing xcodebuild is masked by
                            # the xcbeautify pipe and CI goes false-green.
          # The destination NAME must exist on the runner image. List what's there
          # with `xcrun simctl list devices available` and pin a real one, or use
          # OS=latest to dodge version drift between runner images.
          xcodebuild test \
            -project RehearsalDemo.xcodeproj \
            -scheme RehearsalDemo \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
            -resultBundlePath TestResults.xcresult \
            | xcbeautify       # optional pretty-printer; drop the pipe if not installed

      - name: Upload result bundle
        if: always()                   # capture even on failure — the .xcresult is the debugger
        uses: actions/upload-artifact@v4
        with:
          name: xcresult
          path: Examples/DemoApp/TestResults.xcresult
```

## The four things that actually break CI

1. **Xcode version.** The runner's default Xcode may not be the one you built
   against. Pin it with `xcode-select` (above) and match your local version.
2. **Simulator name drift.** A `-destination` name that exists locally may not
   exist on the runner image. `OS=latest` fixes *runtime* drift but **not**
   *device-name* drift — so first run `xcrun simctl list devices available` on the
   runner, pin a name it actually has, then optionally add `OS=latest`.
3. **Fixtures need a booted sim.** If you use `prepare-simulator-fixtures.sh`,
   the simulator must be booted before `simctl addmedia` runs.
4. **Failures are opaque without the bundle.** Always upload the
   `.xcresult` (`if: always()`) — it's how you debug a red CI run you can't
   reproduce locally.
