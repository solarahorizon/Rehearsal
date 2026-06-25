# UPDATING.md — re-syncing the helper when Rehearsal changes

Rehearsal is a **copy-into-your-project** toolkit, not a package — so there's no
`swift package update`. That's deliberate (no dependency, you own your fork), but
it means when Rehearsal fixes or adds a helper, you pull the change yourself.
This is the recipe.

## The one rule that makes updates painless

**Never edit `XCUIApplication+Helpers.swift` in place.** It's meant to stay
*byte-identical* to upstream (CHECKLIST.md §2 even verifies this with a `diff`).
All your project-specific helpers live in a **separate** file —
`XCUIApplication+<YourApp>.swift` (the Page-Object file from CHECKLIST.md §3).

Keep that boundary and updating is a one-line re-copy. Break it (by editing the
generic file) and every update becomes a manual merge.

## Check whether you're behind

```bash
# from your project root — compares your copy to upstream main
diff <(curl -sL https://raw.githubusercontent.com/solarahorizon/Rehearsal/main/Sources/Helpers/XCUIApplication+Helpers.swift) \
     YourAppUITests/Helpers/XCUIApplication+Helpers.swift
```
- **No output** → you're in sync, nothing to do.
- **A diff** → upstream changed. If you never edited your copy (you shouldn't
  have), just re-copy the file over yours and re-run your tests.

## If you *did* modify your copy (not recommended)

Then the diff above is a mix of your edits and upstream's. Three-way merge it,
or — better — **move your edits into `XCUIApplication+<YourApp>.swift`** so the
generic file is clean again and future updates go back to a one-line re-copy.

## What changed?

Rehearsal's commit history is the changelog — skim the commits touching
`Sources/Helpers/` since you last synced. Helpers only ever get added or hardened
within their existing MARK categories (per CONVENTIONS.md), so updates are
additive and low-risk — your existing tests should keep compiling; re-run them to confirm.

## How the runnable demo stays honest

`Examples/DemoApp` doesn't copy the helper — its `project.yml` **references**
`../../Sources/Helpers/XCUIApplication+Helpers.swift` directly. So a green demo
run always exercises the *current* helper, proving it compiles and works before
you ever sync it into your own project.
