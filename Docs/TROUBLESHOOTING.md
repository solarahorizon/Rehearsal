# TROUBLESHOOTING.md — SwiftUI + XCUITest gotchas

The `CHECKLIST.md` is the happy path. This is the part nobody writes down:
the SwiftUI + XCUITest + CoreSimulator footguns we hit during adoption, roughly
in the order they tend to bite. Each was hit for real during Rehearsal's first
adoption on a production SwiftUI app — symptom, root cause, fix.

If a test "should work" but doesn't, scan the symptoms here first.

---

## 1. `.accessibilityIdentifier` cascades to every descendant

**Symptom:** your query finds the *screen-root* id everywhere — including on
child buttons and labels. The children's own ids are missing from the tree.

**Root cause:** SwiftUI can propagate `.accessibilityIdentifier` from a container
view to its descendants, overwriting their own identifiers — seen when the
modifier sits on a container view. (Behavior has varied across SwiftUI / OS
versions, so verify it in your setup; `.accessibilityLabel` does not propagate
this way.)

**Wrong:**

```swift
ScreenView { ... }
    .accessibilityIdentifier("app.screen.root.view")
// Every descendant button/text now reports "app.screen.root.view".
```

**Right — the sentinel pattern.** Put the screen id on an invisible 1×1
element, not on the container:

```swift
ZStack {
    Color.clear
        .frame(width: 1, height: 1)
        .accessibilityIdentifier("app.screen.root.view")  // sentinel
    // …rest of the screen — descendants keep their own ids
}
```

Host the sentinel in the *screen's own* root, not the routing layer, so each
screen owns its identification.

**Verify:** `print(app.debugDescription)` in a test and confirm interior
elements carry their own ids, not the screen-root id.

---

## 2. `.buttonStyle(.plain)` buttons don't classify as `.button`

**Symptom:** `app.buttons[id]` returns nothing; the id is visibly in the tree
(you can see it in `debugDescription`) but `tapButton(id:)` can't find it.

**Root cause:** a SwiftUI `Button` with complex content (nested stacks, a
background, a shadow) plus `.buttonStyle(.plain)` often renders as an element
of type **Other**, not `.button`, under XCUITest's *typed* query. `buttons[id]`
filters by type and misses it.

**Fix — query by id across any type.** Rehearsal ships `tapElement(id:)` for
exactly this (it queries `descendants(matching: .any)[id]` instead of
`buttons[id]`):

```swift
app.tapElement(id: "app.screen.cta.button")   // finds Button-classified-as-Other
```

Rule of thumb:
- `tapButton(label:)` — system-style buttons with stable visible text.
- `tapElement(id:)` — SwiftUI buttons with custom content (the common case).
- `tapButton(id:)` — only when you *know* it renders as a real `.button` (rare
  with custom SwiftUI).

---

## 3. Tap event "succeeds" but the action never fires

**Symptom:** the activity log says *"Synthesize event"* succeeded on a button,
but the button's action never runs and your assertion on its effect fails.

**Root cause (still open):** seen specifically on `.buttonStyle(.plain)`
buttons whose label is a *text-only* stack (no icon) wrapped in a
`.background(Capsule()/RoundedRectangle())` + `.shadow`. The synthesized tap
lands somewhere the hit-test geometry doesn't route to the action. Plain
buttons elsewhere (numeric pads, icon buttons, list rows) work fine — the
breaking pattern is text-only-label + decorative background/shadow.

**Workaround:** drive a parallel surface that fires the same action (e.g. the
same dismiss is often reachable via an `.onTapGesture` element that is
structurally immune), or add an explicit hit area. If you must tap *that*
element, give the label a definite frame/`contentShape(Rectangle())` so the
hit region is unambiguous.

---

## 4. State-reset launch arg races the first render

**Symptom:** a test that launches with your "wipe + reset" flag (e.g.
`--reset-state`) fails to find the first screen within the default timeout —
but passes when run in isolation. It only fails when a *prior* test left state
behind.

**Root cause:** if you apply the reset in a SwiftUI `.task`/`.onAppear` (which
runs *after* the first body render), a previously-seeded state briefly renders
the post-reset screen + preloads heavy assets, *then* wipes and re-renders to
the initial screen. The default assertion timeout can expire during that
flicker.

**Two fixes:**
- *Architectural (preferred):* apply the reset in `App.init()` — before
  SwiftData/state binds — so there's no stale render at all. Default timeouts
  then work.
- *Defensive (until then):* bump the first assertion's timeout (e.g. 5s → 30s)
  on any test that starts with the reset flag.

---

## 5. `xcrun simctl shutdown all` kills *other* projects' test runs

**Symptom:** your test run shuts down a *different* repo's simulator mid-run,
even though you target different devices.

**Root cause:** `simctl shutdown all` is global — it stops every booted
simulator on the machine, not just yours.

**Fix — never use `all`. Target your sim, or let `xcodebuild` manage it:**

```bash
# Preferred: let xcodebuild boot+kill its own sim
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# If you must shut one down, name it
xcrun simctl shutdown 'iPhone 17 Pro'   # never 'all'
```

---

## 6. Closing a backdrop while a sheet is still presented

**Symptom:** a test taps a "close" id that belongs to a *backdrop* modal while
a foreground sheet is still up. The backdrop dismisses, the sheet's `@State`
leaks past unmount, and the next interaction (reopen backdrop → tap a child)
races the lazy re-mount and can't find the child within the timeout.

**Root cause:** dismissing the wrong layer leaves stale presentation state and
forces a re-mount the next query outruns.

**Fix:** when the test will keep interacting with the backdrop, dismiss only
the *foreground* sheet via its own close control — leave the backdrop open so
its children stay addressable. Reserve the close-backdrop tap for when you're
done with the backdrop entirely. (Make sure the sheet's own close control has
an id, e.g. `app.<surface>.close.button`.)

---

## 7. The simulator audio wedge — the silent suite-killer

**Symptom:** a `xcodebuild test` run *crawls* — every test that plays a sound
sits ~15s before passing, so a 3-minute suite drags past 30 minutes, or wedges
entirely. Worse for automation: a backgrounded test command produces no output
for >10 min and looks exactly like a code hang when it isn't.

**The fingerprint (grep the log for this):**

```
AQMEIO.cpp:201   timed out after 15.000s
HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload
MEDeviceStreamClient.cpp ... client stopping after failed start
```

**Root cause:** the simulator's CoreAudio output device wedges under contention
/ long uptime. Each audio-touching test blocks on a 15-second CoreAudio
timeout. The build is fine; non-sim (package) tests are fine — it's purely the
simulator audio stack.

**Behavioral tell:** any normally-sub-second test that suddenly takes **>15s**
is the wedge, not a slow test. One is suspect; two in a row is confirmed.

**Prevention:** boot a *fresh* sim before a long run —
`xcrun simctl shutdown '<your sim>'` (not `all`, see #5), then let `xcodebuild`
reboot it. In our runs, a clean boot hasn't reproduced the wedge.

**If already wedged:** kill the hung `xcodebuild` + the sim's app host process,
`simctl shutdown '<your sim>'`, wait a few seconds, relaunch. Don't keep
retrying against a wedged sim — it's environmental; the fix is the boot, not
the code.

**For CI / headless runs:** never run a long test blind in a background job.
Stream to a log and watch for either the wedge fingerprint above *or* the
normal `Test Suite … passed/failed` line, so you catch the wedge in ~15s
instead of waiting out a watchdog.

---

## Where these came from

Gotchas 1–7 were each hit during Rehearsal's first external adoption (an
offline SwiftUI + SwiftData app). They're SwiftUI/XCUITest/CoreSimulator
behaviours, not bugs in your code — which is exactly why they're worth writing
down once. If you hit a new one, a PR adding it here is the most useful
contribution you can make.
