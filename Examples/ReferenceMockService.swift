// ReferenceMockService.swift
// Rehearsal Example — launch-arg-driven mock pattern, BOTH seam options
//
// This file is NOT shipped as a runnable component; it's a documented reference
// showing how to apply the mock pattern at either of two seam layers.
//
// Adopt the layer that matches your existing service architecture:
//   - Option A (high-level service protocol): if you have a service-layer protocol
//     (e.g., `APIClient`), implement a mock conforming to it +
//     swap the concrete implementation behind a launch-arg lazy-static.
//   - Option B (low-level HTTP client): if you have an HTTP-client seam
//     (e.g., a `URLSession`-conforming protocol like `HTTPClient`),
//     implement a mock conforming to it + swap the static client behind a launch-arg
//     lazy-static. Option B is the recommended default.
//
// Both options follow the same activation pattern:
//   - Whole-file `#if DEBUG` wrap on the mock (Release builds cannot link it)
//   - Lazy-static at the consumer's existing seam declaration
//   - `ProcessInfo.processInfo.arguments.contains("--<flag>")` checks at first access
//   - Consumer-defined flag name (e.g., "--use-mock-api")

#if DEBUG
import Foundation

// ════════════════════════════════════════════════════════════════════════
// OPTION A — High-level service protocol seam
// ════════════════════════════════════════════════════════════════════════
// Use when your app has a service-layer protocol like:
//   protocol APIClient {
//       func fetch(_ request: Request) async -> Result
//   }
// and a static instance like:
//   static var client: APIClient = LiveAPIClient()

protocol APIClient_Example {
    func fetch(_ request: String) async -> Result<String, Error>
}

struct MockAPIClient_Example: APIClient_Example {
    func fetch(_ request: String) async -> Result<String, Error> {
        // Return canned responses based on input characteristics.
        // Real implementations look up by request signature (e.g., path, body hash).
        return .success("canned response for: \(request)")
    }
}

// In your service file (replace `LiveAPIClient()`):
//
//   static var client: APIClient_Example = {
//       #if DEBUG
//       if ProcessInfo.processInfo.arguments.contains("--use-mock-api") {
//           return MockAPIClient_Example()
//       }
//       #endif
//       return LiveAPIClient()
//   }()

// ════════════════════════════════════════════════════════════════════════
// OPTION B — Low-level HTTP client seam (recommended default)
// ════════════════════════════════════════════════════════════════════════
// Use when your app has an HTTP-transport protocol like:
//   protocol HTTPClient {
//       func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
//   }
//   extension URLSession: HTTPClient { ... }
// and a static instance like:
//   static var httpClient: HTTPClient = URLSession.shared
//
// Preferred when an HTTP-client seam already exists — no new protocol needed;
// mock at the network boundary; everything above the seam (parsing, validation,
// domain logic) runs through the SAME code path in tests as in production.

protocol HTTPClient_Example {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct MockHTTPClient_Example: HTTPClient_Example {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Extract a deterministic key from the request (e.g., SHA-256 of an
        // image payload, or hash of the JSON body), look up canned
        // (Data, HTTPURLResponse), return.
        let cannedData = Data("canned response".utf8)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        return (cannedData, response)
    }
}

// In your service file (replace `URLSession.shared`):
//
//   static var httpClient: HTTPClient_Example = {
//       #if DEBUG
//       if ProcessInfo.processInfo.arguments.contains("--use-mock-api") {
//           return MockHTTPClient_Example()
//       }
//       #endif
//       return URLSession.shared
//   }()
#endif
