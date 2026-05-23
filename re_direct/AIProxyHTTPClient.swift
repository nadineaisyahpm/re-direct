import Foundation

/// Thin HTTP client for the re:direct AI recommendation proxy.
///
/// This is the missing piece that turns `AIRecommendationResolver`'s
/// `callProxy` closure into a real network call. The resolver's existing
/// fallback ladder (cache → proxy → seed) is unchanged — this client is
/// just one option for the closure parameter.
///
/// **Privacy contract** (mirrors `docs/AI_INTEGRATION_PLAN.md` §4):
/// - The client accepts only an `AIRecommendationRequest` value. There is
///   no API for adding extra fields, so a future iOS bug can't leak
///   reflection bodies, identity, DeviceActivity tokens, or precise
///   timestamps through this layer.
/// - No API key handling. The proxy holds the provider key; the iOS app
///   never does. The client sends no `Authorization` header.
/// - No retry loop in this slice — a single attempt, then the error path.
///   The resolver decides whether to fall back.
struct AIProxyHTTPClient: Sendable {

    let config: AIProxyConfig
    private let session: URLSession

    init(config: AIProxyConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Single-attempt call to `POST {baseURL}/v1/recommendation`.
    ///
    /// Returns the decoded `AIRecommendationResponse` on 2xx. On any other
    /// outcome — non-2xx HTTP, transport failure, decoding failure — throws
    /// an `AIProxyError` mapped via the existing `AIProxyError.from(...)`
    /// factory + URL-error heuristics. `AIRecommendationResolver` already
    /// knows how to interpret those.
    func call(_ request: AIRecommendationRequest) async throws -> AIRecommendationResponse {
        let urlRequest = try makeURLRequest(for: request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw Self.mapURLError(urlError)
        } catch {
            throw AIProxyError.network(message: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIProxyError.network(message: "Non-HTTP response from proxy")
        }

        if (200..<300).contains(http.statusCode) {
            do {
                return try JSONDecoder.aiProxy.decode(AIRecommendationResponse.self, from: data)
            } catch {
                throw AIProxyError.decoding
            }
        }

        throw AIProxyError.from(status: http.statusCode, data: data)
    }

    // MARK: helpers (internal for testability)

    /// Builds the outbound `URLRequest`. Extracted so tests can inspect the
    /// encoded body without spinning up `URLSession`.
    func makeURLRequest(for request: AIRecommendationRequest) throws -> URLRequest {
        let url = config.baseURL.appendingPathComponent("v1/recommendation")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = config.timeoutSeconds
        urlRequest.httpBody = try Self.encodeBody(request)
        return urlRequest
    }

    /// Pure JSON encoding. Lifted to a static so tests can assert the
    /// produced payload contains only allowlisted snake_case keys.
    static func encodeBody(_ request: AIRecommendationRequest) throws -> Data {
        do {
            return try JSONEncoder.aiProxy.encode(request)
        } catch {
            throw AIProxyError.decoding
        }
    }

    /// Pure URL-error → `AIProxyError` mapping. Lifted for unit testing.
    static func mapURLError(_ error: URLError) -> AIProxyError {
        switch error.code {
        case .timedOut:
            return .upstreamTimeout
        case .notConnectedToInternet, .networkConnectionLost,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return .network(message: error.localizedDescription)
        default:
            return .network(message: error.localizedDescription)
        }
    }
}
