# MOCK_SERVICE_PATTERN.md

How to make your app's network-dependent services deterministic under XCUITest
by mocking inside the **app target** (not the test target), activated by a
launch argument.

This doc covers:

1. The process-boundary problem (why naive mocking doesn't work)
2. The solution: mock inside the app target, gated on a launch argument
3. Seam-layer choice: high-level service protocol vs low-level HTTP client
4. Worked example: a `MockHTTPClient`
5. Anti-pattern: do NOT put the mock in the UI test target

---

## 1. The process-boundary problem

XCUITest is a black-box framework: tests run in a **separate process** from the
app under test. The XCUITest runner can only interact with the app via the
public accessibility API — taps, swipes, accessibility-id queries, text input.

Practically this means:

- You can't inject a mock instance from test code into the app's running
  service singletons — the two processes share no memory.
- You can't pass object instances or a DI container across the process
  boundary; tests can only hand the app *serialized* startup configuration
  (arguments / environment), not live objects. (It's process isolation, not a
  timing problem — the test configures `XCUIApplication` before launch, but
  only with data, not references.)
- You can't swap protocols at runtime via test-side configuration — after
  launch, the app reads nothing from the test process.

The simplest startup signal the test process can hand the app is **launch
arguments** (via `XCUIApplication.launchArguments`; `launchEnvironment` is the
other common channel). That's the boundary this toolkit builds on.

## 2. The solution: launch-arg-driven mock activation, INSIDE the app target

The mock implementation lives inside the **app target** (not in the UI test
target), wrapped in `#if DEBUG`. At the seam where production normally
instantiates the live service, a `lazy static` checks the launch argument
once at first access and returns either the mock or the live implementation:

```swift
// In your app target's service file (production code path)

static var client: APIClient = {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--use-mock-api") {
        return MockAPIClient()
    }
    #endif
    return LiveAPIClient()
}()
```

Activation:

- Release builds don't compile the mock (the whole file is wrapped in
  `#if DEBUG`), as long as its target membership + references stay debug-only.
- Debug builds run the live service unless the launch argument is present.
- UI tests pass the argument via `XCUIApplication.launchArguments = ["--use-mock-api"]`
  or, more idiomatically, via the Rehearsal helper:
  `app.launchWithMockMode(args: ["--use-mock-api"])`.

Flag naming convention: `--use-mock-<service>`. Pick a name that's specific
enough to be greppable across both your app target and your UI test target.

## 3. Seam-layer choice: Option A vs Option B

You have a choice about WHERE to put the seam. Two layers commonly work:

### Option A — High-level service protocol seam

Use when your app already exposes a service-layer protocol like:

```swift
protocol APIClient {
    func fetch(_ request: Request) async -> Result<Response, Error>
}
```

Implement `MockAPIClient` conforming to it, and swap the static
instance behind a launch-arg lazy-static.

**Pros:**

- Highest-level abstraction; you can short-circuit complex logic above the
  service boundary.
- Easy to author: just return canned `Result` values.

**Cons:**

- Any logic ABOVE the service (parsing/decoding/domain assembly) is BYPASSED
  in tests. You're not testing the production code path end-to-end; you're
  testing the UI's response to mocked service output.
- If the service contract changes, you have two implementations (live + mock)
  to keep in sync.

### Option B — Low-level HTTP client seam (recommended default)

Use when your app has a thin HTTP-transport seam like:

```swift
protocol HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
extension URLSession: HTTPClient { ... }
```

Implement `MockHTTPClient` conforming to it, and swap the static client behind
a launch-arg lazy-static.

**Pros:**

- Everything above the seam (parsing, validation, domain logic) runs through the
  SAME code path in tests as in production. The test bytes hit the same
  decoder, the same domain logic, the same view-model assembly.
- Mocking happens at the network boundary — the most stable surface in your
  stack.

**Cons:**

- You author canned `(Data, HTTPURLResponse)` blobs, which is more verbose
  than canned `Result` values.
- Authoring the canned responses requires understanding the wire format your
  service uses.

**Decision criteria:**

- Pick **Option B** if you already have an HTTP-client seam and you want
  end-to-end production code path coverage in your UI tests. This is the
  Rehearsal-recommended default.
- Pick **Option A** if your service has complex internal logic that's
  expensive to drive end-to-end, OR if you don't have a thin HTTP-client
  seam yet and don't want to introduce one.

## 4. Worked example: a `MockHTTPClient`

Take a hypothetical `MyApp` that uses **Option B**. The seam lives at
`MyApp/Services/APIClient.swift`:

```swift
// APIClient.swift (production)

static var httpClient: HTTPClient = {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--use-mock-api") {
        return MockHTTPClient()
    }
    #endif
    return URLSession.shared.asHTTPClient()
}()
```

The mock at `MyApp/UITestSupport/MockHTTPClient.swift` is whole-file
`#if DEBUG`-wrapped. It looks up canned `(Data, HTTPURLResponse)` blobs by a
deterministic key derived from the request (e.g., the SHA-256 of a payload in
the request body, or a hash of the request path + JSON body).

Above the seam, the entire production pipeline runs unchanged:

```
HTTP response → APIClient.parse → ResponseContract.decode →
DomainModelBuilder.build → ViewModel.update → UI redraw
```

UI tests assert on the UI state at the end of that pipeline, which is the
behavior real users see in production.

## 5. Anti-pattern: do NOT put the mock in the UI test target

A common mistake: implement `MockHTTPClient` in `<YourApp>UITests/` and
expect it to take over at runtime.

This **does not work** because:

- The mock class is in the test bundle (a separate Mach-O image), not the app
  bundle.
- The app target's `APIClient.httpClient` static reads a symbol that
  doesn't exist in the app bundle, so it can't return the mock.
- Even if you tried to inject the mock by reflection, the test process and
  app process are separate — there's no shared memory.

The mock MUST live in the **app target** (whole-file `#if DEBUG`-wrapped) and
be selected by the app at startup based on the launch argument.

## See also

- `CONVENTIONS.md` §Launch-arg mock pattern — naming convention reference
- `Examples/ReferenceMockService.swift` — both Option A + Option B code skeletons
- `Examples/ReferenceUITestMethod.swift` — end-to-end test method using the pattern
