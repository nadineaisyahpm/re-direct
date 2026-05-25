import Testing
import Foundation
@testable import re_direct

// ─────────────────────────────────────────────
// MARK: - URLProtocol mock
// ─────────────────────────────────────────────
//
// Minimal in-test mock so we never hit the network. The handler closure
// returns the (response, body) for each request. The `captured` static
// records the inbound request for assertion in tests. URLProtocol-based
// stubbing is the standard SwiftUI-era pattern for URLSession testing.

final class AIProxyURLProtocolMock: URLProtocol {

    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var captured: [URLRequest] = []

    static func reset() {
        handler = nil
        captured = []
    }

    static func makeSession(timeout: TimeInterval = 5) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.protocolClasses = [AIProxyURLProtocolMock.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.captured.append(request)
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        do {
            let (response, body) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch let error as URLError {
            client?.urlProtocol(self, didFailWithError: error)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// Read body from either `httpBody` or `httpBodyStream` — URLSession often
// converts `httpBody` to a stream by the time URLProtocol sees the request.
private func readBody(of request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

// ─────────────────────────────────────────────
// MARK: - Fixtures
// ─────────────────────────────────────────────

private let testProxyURL = URL(string: "https://proxy.test.invalid")!
private let testConfig = AIProxyConfig(baseURL: testProxyURL, timeoutSeconds: 5)

private func makeValidRequest() -> AIRecommendationRequest {
    AIRecommendationRequest(
        interests: ["Machine Learning", "AI"],
        mood: "curious",
        timeAvailableMinutes: 15,
        excludePromptHashes: [],
        providerPreference: .auto,
        locale: "en-US"
    )
}

private func makeHTTPResponse(status: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: testProxyURL.appendingPathComponent("v1/recommendation"),
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["content-type": "application/json"]
    )!
}

// ─────────────────────────────────────────────
// MARK: - Tests
// ─────────────────────────────────────────────

// `.serialized` because the URLProtocol mock above keeps its handler and
// captured-request list in static storage. Swift Testing's default
// parallelism would race those statics across tests in this suite and
// produce flaky empty-`captured` / wrong-handler failures.
@Suite("AIProxyHTTPClient", .serialized)
struct AIProxyHTTPClientTests {

    // MARK: encoding / privacy guard

    @Test func encodedBodyContainsAllowlistedSnakeCaseKeys() throws {
        let body = try AIProxyHTTPClient.encodeBody(makeValidRequest())
        let json = try #require(String(data: body, encoding: .utf8))

        // Existing iOS DTO uses snake_case Codable keys.
        #expect(json.contains("\"interests\""))
        #expect(json.contains("\"time_available_minutes\""))
        #expect(json.contains("\"provider_preference\""))
        #expect(json.contains("\"locale\""))
    }

    @Test func encodedBodyHasExactExpectedKeySet() throws {
        // Tighter contract than the substring check above: parse the JSON
        // and assert the top-level keys are *exactly* the allowlisted set.
        let body = try AIProxyHTTPClient.encodeBody(makeValidRequest())
        let object = try #require(
            try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
        )

        // With mood non-nil, all six keys are present.
        let expected: Set<String> = [
            "interests",
            "mood",
            "time_available_minutes",
            "exclude_prompt_hashes",
            "provider_preference",
            "locale",
        ]
        #expect(Set(object.keys) == expected)
    }

    @Test func encodedBodyOmitsMoodWhenNil() throws {
        let request = AIRecommendationRequest(
            interests: ["AI"],
            mood: nil,
            timeAvailableMinutes: 15,
            excludePromptHashes: [],
            providerPreference: .auto,
            locale: "en-US"
        )
        let body = try AIProxyHTTPClient.encodeBody(request)
        let object = try #require(
            try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
        )
        #expect(object["mood"] == nil, "mood key must be omitted when nil")
        // Other keys must still be present.
        #expect(object["interests"] != nil)
        #expect(object["time_available_minutes"] != nil)
        #expect(object["exclude_prompt_hashes"] != nil)
        #expect(object["provider_preference"] != nil)
        #expect(object["locale"] != nil)
    }

    @Test func encodedBodyIncludesMoodWhenSet() throws {
        let body = try AIProxyHTTPClient.encodeBody(makeValidRequest())
        let object = try #require(
            try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
        )
        let mood = try #require(object["mood"] as? String)
        #expect(mood == "curious")
    }

    @Test func encodedBodyProviderPreferenceEncodesAsStringAuto() throws {
        let body = try AIProxyHTTPClient.encodeBody(makeValidRequest())
        let object = try #require(
            try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
        )
        let pref = try #require(object["provider_preference"] as? String)
        #expect(pref == "auto")
    }

    @Test func encodedBodyValueTypesArePrimitiveJSON() throws {
        // JSONSerialization round-trips to native types. Confirm we're not
        // accidentally emitting nested objects for what should be primitives.
        let body = try AIProxyHTTPClient.encodeBody(makeValidRequest())
        let object = try #require(
            try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
        )
        #expect(object["interests"] is [String])
        #expect(object["exclude_prompt_hashes"] is [String])
        #expect(object["time_available_minutes"] is NSNumber)
        #expect(object["provider_preference"] is String)
        #expect(object["locale"] is String)
    }

    @Test func encodedBodyDoesNotIncludeForbiddenFields() throws {
        let body = try AIProxyHTTPClient.encodeBody(makeValidRequest())
        let json = try #require(String(data: body, encoding: .utf8))

        // The privacy contract from AI_INTEGRATION_PLAN.md §4.2: none of
        // these should ever appear on the wire. The DTO has no such fields,
        // but this test fails loudly if a future change adds one.
        for forbidden in [
            "reflection_body", "reflectionBody",
            "engagement_body", "body",
            "apple_user_id", "appleUserId", "user_id",
            "device_activity_token", "deviceActivityToken",
            "family_activity_token",
            "engaged_at", "started_at", "precise_timestamp",
            "screenshot", "proof_image",
        ] {
            #expect(!json.contains("\"\(forbidden)\""), "encoded JSON unexpectedly contains \(forbidden)")
        }
    }

    @Test func requestURLAndMethod() throws {
        let client = AIProxyHTTPClient(config: testConfig)
        let urlRequest = try client.makeURLRequest(for: makeValidRequest())

        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.url?.absoluteString == "https://proxy.test.invalid/v1/recommendation")
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(urlRequest.timeoutInterval == 5)
        // No Authorization header — the iOS app never carries the provider key.
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // MARK: happy path

    @Test func decodesSuccessfulResponse() async throws {
        AIProxyURLProtocolMock.reset()
        let session = AIProxyURLProtocolMock.makeSession()
        defer { AIProxyURLProtocolMock.reset() }

        let now = ISO8601DateFormatter().string(from: Date())
        let payload = """
        {
          "id": "01HZX1...",
          "topic_slug": "bioluminescence",
          "topic_title": "Bioluminescence",
          "prompt_body": "Find one short documentary about the species you almost forgot existed.",
          "suggested_minutes": 12,
          "provider": "deepseek",
          "model_version": "deepseek-v4-flash",
          "prompt_input_hash": "f3a1abc",
          "cached": false,
          "created_at": "\(now)"
        }
        """.data(using: .utf8)!

        AIProxyURLProtocolMock.handler = { _ in (makeHTTPResponse(status: 200), payload) }

        let client = AIProxyHTTPClient(config: testConfig, session: session)
        let response = try await client.call(makeValidRequest())

        #expect(response.provider == "deepseek")
        #expect(response.modelVersion == "deepseek-v4-flash")
        #expect(response.topicSlug == "bioluminescence")
        #expect(response.suggestedMinutes == 12)
        #expect(response.cached == false)
        #expect(response.promptInputHash == "f3a1abc")
    }

    @Test func mockSeesRequestBodyWithoutForbiddenFields() async throws {
        AIProxyURLProtocolMock.reset()
        let session = AIProxyURLProtocolMock.makeSession()
        defer { AIProxyURLProtocolMock.reset() }

        AIProxyURLProtocolMock.handler = { request in
            let body = readBody(of: request)
            let json = String(data: body, encoding: .utf8) ?? ""
            // Encode a tiny round-trip stub; assertion logic lives in the
            // post-call expect.
            _ = json
            let resp = makeHTTPResponse(status: 200)
            let payload = """
            {"id":"x","topic_title":"t","prompt_body":"b","suggested_minutes":5,
            "provider":"deepseek","model_version":"deepseek-v4-flash",
            "prompt_input_hash":"h","cached":false,
            "created_at":"\(ISO8601DateFormatter().string(from: Date()))"}
            """.data(using: .utf8)!
            return (resp, payload)
        }

        let client = AIProxyHTTPClient(config: testConfig, session: session)
        _ = try await client.call(makeValidRequest())

        let captured = try #require(AIProxyURLProtocolMock.captured.first)
        let bodyData = readBody(of: captured)
        let bodyJSON = try #require(String(data: bodyData, encoding: .utf8))
        #expect(bodyJSON.contains("\"interests\""))
        #expect(!bodyJSON.contains("reflection_body"))
        #expect(!bodyJSON.contains("apple_user_id"))
        #expect(!bodyJSON.contains("device_activity_token"))
    }

    // MARK: error mapping

    @Test func mapsInvalidInputWireError() async throws {
        AIProxyURLProtocolMock.reset()
        let session = AIProxyURLProtocolMock.makeSession()
        defer { AIProxyURLProtocolMock.reset() }

        let body = """
        {"error":{"code":"invalid_input","message":"forbidden field(s): reflection_body"}}
        """.data(using: .utf8)!
        AIProxyURLProtocolMock.handler = { _ in (makeHTTPResponse(status: 400), body) }

        let client = AIProxyHTTPClient(config: testConfig, session: session)
        await #expect(throws: AIProxyError.invalidInput(message: "forbidden field(s): reflection_body")) {
            try await client.call(makeValidRequest())
        }
    }

    @Test func mapsRateLimitedWithRetryAfter() async throws {
        AIProxyURLProtocolMock.reset()
        let session = AIProxyURLProtocolMock.makeSession()
        defer { AIProxyURLProtocolMock.reset() }

        let body = """
        {"error":{"code":"rate_limited","message":"throttled","retry_after_seconds":30}}
        """.data(using: .utf8)!
        AIProxyURLProtocolMock.handler = { _ in (makeHTTPResponse(status: 429), body) }

        let client = AIProxyHTTPClient(config: testConfig, session: session)
        do {
            _ = try await client.call(makeValidRequest())
            Issue.record("Expected throw")
        } catch let error as AIProxyError {
            if case .rateLimited(let retry) = error {
                #expect(retry == 30)
            } else {
                Issue.record("Expected .rateLimited but got \(error)")
            }
        }
    }

    @Test func mapsProxyUnavailable() async throws {
        AIProxyURLProtocolMock.reset()
        let session = AIProxyURLProtocolMock.makeSession()
        defer { AIProxyURLProtocolMock.reset() }

        let body = """
        {"error":{"code":"proxy_unavailable","message":"No provider configured"}}
        """.data(using: .utf8)!
        AIProxyURLProtocolMock.handler = { _ in (makeHTTPResponse(status: 503), body) }

        let client = AIProxyHTTPClient(config: testConfig, session: session)
        await #expect(throws: AIProxyError.proxyUnavailable) {
            try await client.call(makeValidRequest())
        }
    }

    @Test func mapsUpstreamFailedTriggersSeededFallback() async throws {
        // Existing AIProxyError contract: certain codes trigger the
        // resolver's seeded fallback. The HTTP client just needs to emit
        // the right case; this is the resolver-side assertion.
        AIProxyURLProtocolMock.reset()
        let session = AIProxyURLProtocolMock.makeSession()
        defer { AIProxyURLProtocolMock.reset() }

        let body = """
        {"error":{"code":"upstream_failed","message":"boom"}}
        """.data(using: .utf8)!
        AIProxyURLProtocolMock.handler = { _ in (makeHTTPResponse(status: 502), body) }

        let client = AIProxyHTTPClient(config: testConfig, session: session)
        do {
            _ = try await client.call(makeValidRequest())
            Issue.record("Expected throw")
        } catch let error as AIProxyError {
            #expect(error == .upstreamFailed)
            #expect(error.triggersSeededFallback)
        }
    }

    // MARK: URL-error mapping (pure)

    @Test func urlErrorTimeoutMapsToUpstreamTimeout() {
        let mapped = AIProxyHTTPClient.mapURLError(URLError(.timedOut))
        #expect(mapped == .upstreamTimeout)
    }

    @Test func urlErrorOfflineMapsToNetwork() {
        let mapped = AIProxyHTTPClient.mapURLError(URLError(.notConnectedToInternet))
        if case .network = mapped {
            // ok
        } else {
            Issue.record("Expected .network but got \(mapped)")
        }
    }

    @Test func transportFailureFromMockMapsToNetwork() async throws {
        // No handler set → URLProtocol fails the request with
        // .notConnectedToInternet. The client should surface .network(...).
        AIProxyURLProtocolMock.reset()
        let session = AIProxyURLProtocolMock.makeSession()
        defer { AIProxyURLProtocolMock.reset() }

        let client = AIProxyHTTPClient(config: testConfig, session: session)
        do {
            _ = try await client.call(makeValidRequest())
            Issue.record("Expected throw")
        } catch let error as AIProxyError {
            if case .network = error {
                // ok
            } else {
                Issue.record("Expected .network but got \(error)")
            }
        }
    }
}
