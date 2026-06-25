# ACCESSIBILITY_IDS.md

A naming convention for accessibility identifiers that survives refactoring,
scales to dozens of screens, and reads like a path you can navigate from
top-down.

This doc covers:

1. The 4-segment namespace: `<app-prefix>.<feature>.<element>.<state>`
2. Why this shape (vs. flat strings or screen-scoped strings)
3. Worked example: a migrated id set
4. Migration recipe: how to migrate a project's flat ids
5. Edge cases: dynamic ids (5-segment for indexed elements)
6. Tooling: pre-flight grep for unmigrated old ids

---

## 1. The 4-segment namespace

```
<app-prefix>.<feature>.<element>.<state>
```

| Segment | Purpose | Examples |
|---|---|---|
| `<app-prefix>` | Project name in lowercase. One token. | `myapp`, `acme`, `demo` |
| `<feature>` | The functional area the element belongs to. One token. | `cart`, `catalog`, `account`, `onboarding` |
| `<element>` | What kind of element it is + optional disambiguation. CamelCase. One token. | `itemRemove`, `itemsList`, `itemCount`, `saveCta` |
| `<state>` | The element role (button / label / image / etc.). One token. | `button`, `label`, `image`, `field` |

Joined with `.` (dot). Always 4 segments for static elements.

Examples:

```
myapp.cart.itemRemove.button
myapp.cart.itemsList.label
myapp.catalog.itemAdd.button
myapp.onboarding.continueCta.button
```

## 2. Why this shape

**vs. flat strings (`photo-remove-button`):**

- No feature attribution. When 4 screens have a "Save" button, you end up
  with `save-button`, `save-button-1`, `save-button-final` — string drift.
- No grep-ability. `grep save-button` returns dozens of unrelated matches.
- No tooling hooks. You can't write a lint rule that says "every button
  must have an id starting with `<feature>.`".

**vs. screen-scoped strings (`CartScreen.saveButton`):**

- Screens get renamed; ids should not have to be rewritten across the
  codebase every time you refactor a SwiftUI view.
- "Feature" is a more stable unit than "screen". One feature can span
  multiple screens (modal flows, navigation stacks).

**The 4-segment shape:**

- Easy to grep: `grep myapp.cart.` finds every cart-feature id.
- Reads like a path: `myapp.cart.itemRemove.button` is unambiguous
  even out of context.
- Stable under view refactors: changing a SwiftUI view's name doesn't
  change its element's feature.
- Greps + lints scale: `awk -F. '{print $2}'` extracts the feature column.

## 3. Worked example: a migrated id set

Take a hypothetical `MyApp` shopping-cart feature whose ids accumulated as flat
strings over early development.

Pre-migration (flat strings, accumulated organically):

```
"image-remove-button"
"item-1-remove"
"item-2-remove"
"save"
"cart-items-list"
"item-count"
```

Post-migration (4-segment namespace):

```
"myapp.cart.imageRemove.button"                       # 4-segment static — single-image X
"myapp.cart.imageRemove.button.\(index)"              # 5-segment dynamic — N>=2 images
"myapp.cart.imageRemoveFailure.button"                # 4-segment static — X shown on an image-load failure
"myapp.cart.imageFailure.label"                       # 4-segment static — error message under a failed image
"myapp.cart.imageFailureRetry.button"                 # 4-segment static — retry button next to the failure message
"myapp.cart.emptySave.label"                          # 4-segment static — inline guidance on an empty-cart save
"myapp.cart.itemRemove.button.\(index)"               # 5-segment dynamic — item-row X in an N-item cart
"myapp.cart.itemThumbnail.image"                       # 4-segment static — single-item thumbnail
"myapp.cart.itemThumbnail.image.\(index)"              # 5-segment dynamic — N>=2 item thumbnails
```

**Element-combining for multi-state elements:** when an element has a single semantically-distinct state worth its own identifier (e.g. the `imageRemove` button shown specifically on failure), combine the state into the `<element>` segment via camelCase rather than appending a 5th segment. The 5th segment is reserved for collection indices per §5. So `imageRemoveFailure.button` (element = combined noun) NOT `imageRemove.button.failure` (5-segment static is non-conformant).

**Text-element role taxonomy:** `<state>` for static text content uses `label` (not `message`, `text`, `caption`, etc.) — keeps the role vocabulary small.

XCUITest queries become predictable:

```swift
app.tapButton(id: "myapp.cart.save.button")
app.assertVisible(id: "myapp.cart.itemsList.label")
app.assertText(id: "myapp.cart.itemCount.label", matches: "3")
```

## 4. Migration recipe

For an existing project with flat ids:

**Step 1 — Inventory.** Grep your view code for `.accessibilityIdentifier(`
calls. List every string. Group by feature in a spreadsheet.

**Step 2 — Translate.** For each old id, write the new 4-segment form.
Keep the spreadsheet for the duration of the migration.

**Step 3 — Update views.** Replace each `.accessibilityIdentifier("old")`
with `.accessibilityIdentifier("myapp.feature.element.state")`. Do this
in small batches per feature — easy to review, easy to revert if a UI test
breaks.

**Step 4 — Update existing UI tests** (if any). Find every test that
queries by old id; update to the new id. The Rehearsal helpers
(`tapButton(id:)`, `assertVisible(id:)`) make this a string replacement.

**Step 5 — Lint.** Add a pre-commit lint that rejects new
`.accessibilityIdentifier` strings not matching the 4-segment shape.
Optional but stops drift from coming back.

**Step 6 — Pre-flight grep** (see §6).

## 5. Edge cases: dynamic ids (5-segment)

Lists of repeating elements need a 5th segment for disambiguation:

```
myapp.cart.itemRemove.button.0
myapp.cart.itemRemove.button.1
myapp.cart.itemRemove.button.2
```

The 5th segment is a zero-based index (or another disambiguator like a
short stable id). XCUITest can query each individually:

```swift
app.tapButton(id: "myapp.cart.itemRemove.button.\(index)")
```

The 4-segment vs 5-segment split is intentional: a static element is
4-segments; a dynamic-collection element is 4-segments + an index. Don't
mix the two.

## 6. Tooling: pre-flight grep

Before a UI test run, sanity-check that no old (un-migrated) ids remain in
view code:

```
# Old flat strings should be zero hits after migration
grep -rn "accessibilityIdentifier(\"image-remove" YourApp/Views/
grep -rn "accessibilityIdentifier(\"item-.*-remove" YourApp/Views/

# Every new id should match the 4-segment (or 5-segment dynamic) pattern
grep -rEn "accessibilityIdentifier\\(\"[a-z]+(\\.[a-zA-Z]+)+\"\\)" YourApp/Views/
```

A pre-commit hook can enforce the pattern globally; Rehearsal doesn't
ship one (project-specific lint config is out of scope).

## 7. Bypass-seam pattern: `testFixture.<name>`

For consumers adopting the PhotosPicker bypass-seam mechanism (see
`Docs/FIXTURE_PIPELINE.md` + `pickPhotoFromLibrary(named:)` in the
generic helpers), debug fixture cells live under a dedicated 3-segment
family separate from the production 4-segment namespace:

```
<app-prefix>.testFixture.<name>
```

| Segment | Purpose | Examples |
|---|---|---|
| `<app-prefix>` | Same as production — project name in lowercase. | `myapp` |
| `testFixture` | Literal token marking this id as a test-only bypass cell. | `testFixture` |
| `<name>` | Fixture filename basename (sans extension). One token. | `sample_image`, `sample_receipt` |

Two-segment example (header caption above the fixture buttons):

```
myapp.testFixture.header
```

### Why a separate family

`testFixture.<name>` cells live wholly inside `#if DEBUG` in consumer
view code. The 3-segment form (vs. the 4-segment production namespace)
makes the test-only family visible at a glance during grep / code
review:

```
grep -rn "accessibilityIdentifier(\"<app-prefix>.testFixture" YourApp/
```

The helper `pickPhotoFromLibrary(named:)` queries by
`ENDSWITH ".testFixture.\(named)"` so the leading app-prefix can vary
across consumers without breaking byte-identity of the helper file.

### Worked example: a bypass-seam picker

```swift
#if DEBUG
@ViewBuilder
private var bypassFixturePicker: some View {
    if isBypassPhotosPickerActive {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test fixtures (debug)")
                .accessibilityIdentifier("myapp.testFixture.header")
            ForEach(bypassFixtureNames, id: \.self) { name in
                Button(name.replacingOccurrences(of: "_", with: " ").capitalized) {
                    loadFixtureForTest(name: name)
                }
                .accessibilityIdentifier("myapp.testFixture.\(name)")
            }
        }
    }
}
#endif
```

UI tests then tap by name:

```swift
app.pickPhotoFromLibrary(named: "sample_image")
// Resolves to: descendants(matching: .button)
//   .matching(NSPredicate(format: "identifier ENDSWITH %@", ".testFixture.sample_image"))
//   .firstMatch
//   .tap()
```

See `CONVENTIONS.md §1a` for the condensed convention.

## See also

- `CONVENTIONS.md` §Accessibility-id namespace — condensed convention
  reference
- `Examples/ReferenceUITestMethod.swift` — example test using the
  namespace
