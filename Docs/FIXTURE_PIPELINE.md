# FIXTURE_PIPELINE.md

How to pre-load fixture media (photos, videos, audio) onto an iOS simulator
so your XCUITest can drive system pickers (PhotosPicker, document pickers)
deterministically, plus a canned-response convention that pairs each fixture
with its expected mock-server output.

This doc covers:

1. `xcrun simctl addmedia` mechanics
2. Fixture naming convention: `<name>.<ext>` + `<name>.<sha>.json` pairing
3. The `prepare-simulator-fixtures.sh` script — invocation + customization
4. Canned-response lookup pattern (image-bytes SHA-256 → response dictionary)
5. Worked example: a fixture pipeline
6. Extension seam: JSON / audio / video fixtures via the same naming pattern

---

## 1. `xcrun simctl addmedia` mechanics

Apple's `simctl` (Simulator control) ships with a `addmedia` subcommand that
adds files to the simulator's Photos library:

```
xcrun simctl addmedia <device-udid-or-name> <file-path> [<file-path> ...]
```

- `<device-udid-or-name>` is the simulator the test will run against
  (e.g., `"iPhone 17 Pro"` or `booted` for the currently-booted simulator).
- `<file-path>` is any local image (PNG, JPEG, HEIC) or video file.
- After the command runs, the file appears in the simulator's Photos app and
  is selectable from `PhotosPicker` / `UIImagePickerController`.

The fixture is persistent across simulator boots (it's written to the
simulator's container). Re-running `addmedia` for the same file is idempotent
(a new copy appears each time — clean the simulator's Photos library between
test runs if exact-state isolation matters).

## 2. Fixture naming convention

Rehearsal prescribes two paired files per fixture:

```
fixture_sample.jpg                   # the photo
fixture_sample.<sha256>.json         # the canned mock response
```

Where `<sha256>` is the SHA-256 of the photo bytes. The pairing makes the
canned-response lookup unambiguous: when the mock HTTP client receives a
request whose image hash equals `<sha256>`, it returns the contents of the
matching `.json` file as the response body.

**Naming rules:**

- Lowercase, underscore-separated.
- Prefix `fixture_` to make grep-ability obvious.
- The photo extension is `.jpg`, `.png`, or `.heic` (whatever the production
  app expects).
- The canned-response file always ends in `.<sha>.json`. The 64-character SHA
  is bound to the photo's bytes — if the photo content changes, the canned
  filename must change too (catches accidental rebases that desync the pair).
- One canned-response file per fixture. If you need different responses for
  the same photo (e.g., different mock-mode variants), use different photo
  fixtures and document the mapping.

## 3. The `prepare-simulator-fixtures.sh` script

Rehearsal ships a reusable wrapper at `Scripts/prepare-simulator-fixtures.sh`:

```
./Scripts/prepare-simulator-fixtures.sh <device-udid-or-name> <fixture-dir>
```

- `<device-udid-or-name>`: the target simulator.
- `<fixture-dir>`: a directory containing your fixture media (e.g.,
  `<YourApp>UITests/Fixtures/`).

The script iterates the directory, finds image extensions, and calls
`xcrun simctl addmedia` for each. It's intentionally thin — most projects
will customize it (e.g., to add video support, to skip already-loaded
fixtures, to wipe before re-loading).

**When to call it:**

- Before running UI tests locally for the first time on a fresh simulator.
- In CI: as a pre-test step in the same job that runs `xcodebuild test`.
- After any fixture change that adds new files (re-running is safe but slow).

## 4. Canned-response lookup pattern

Inside your mock HTTP client (Option B per `MOCK_SERVICE_PATTERN.md`), the
lookup looks like:

```swift
struct MockHTTPClient: HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // 1. Extract the image bytes from the request body (multipart, base64, etc.)
        let imageBytes = extractImageBytes(from: request)

        // 2. Hash the bytes
        let sha = SHA256.hash(data: imageBytes).hexString

        // 3. Look up the canned response in CannedResponses
        guard let cannedData = CannedResponses.entries[sha] else {
            throw MockError.unknownFixture(sha: sha)
        }

        // 4. Wrap in an HTTPURLResponse
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: nil
        )!
        return (cannedData, response)
    }
}
```

`CannedResponses.entries` is a `[String: Data]` dictionary keyed by SHA — the
project's build system embeds the `.json` files from `Fixtures/` and the
runtime parses them into the dictionary at first access. The exact codegen
approach is your project's choice; the convention is just the key shape.

## 5. Worked example: a fixture pipeline

A hypothetical `MyApp` whose flows take a photo input would lay out its
fixtures like this:

```
MyAppUITests/Fixtures/
├── fixture_sample.jpg
├── fixture_sample.a1b2...c3d4.json
├── fixture_receipt.jpg
└── fixture_receipt.e5f6...7890.json
```

`MockHTTPClient` reads `CannedResponses.entries[sha]` to retrieve the JSON
blob, then returns it as the HTTP response body. The production
`ResponseContract.decode` runs against the canned JSON identically to a
live response — that's the Option B benefit.

CI / local pre-test invocation:

```
./Scripts/prepare-simulator-fixtures.sh "iPhone 17 Pro" MyAppUITests/Fixtures/
```

(The Rehearsal `Scripts/prepare-simulator-fixtures.sh` is cloned
byte-identical into the consumer's repo.)

## 6. Extension seam: JSON / audio / video

The same `<name>.<ext>` + `<name>.<sha>.json` pattern extends to other media
types:

- **Audio** (`.m4a`, `.wav`): `addmedia` supports audio; canned response
  pairs to a hash of the audio bytes.
- **Video** (`.mp4`, `.mov`): same pattern; SHA the video bytes; canned
  response is the JSON the live service would return.
- **Document fixtures** (`.pdf`): not handled by `addmedia`; use a different
  mechanism (e.g., placing the file in the app's Documents container at
  startup via a launch-arg seam).

The canned-response key is always SHA-256 of the BYTES the production
service would hash. If your service hashes a transform (resized image,
re-encoded audio), hash the transform output, not the raw bytes.

## See also

- `Scripts/prepare-simulator-fixtures.sh` — the reusable shell wrapper
- `MOCK_SERVICE_PATTERN.md` §4 — a `MockHTTPClient` as a worked Option B
  reference
- `CONVENTIONS.md` §Fixture naming — condensed convention reference
