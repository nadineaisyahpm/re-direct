import Foundation

/// Where the AI proxy lives and how to talk to it. Held as an immutable
/// value so the HTTP client is trivially `Sendable`.
///
/// The deployed dev URL (Cloudflare Worker) is documented here for
/// reference but **not** baked into a hardcoded default — the iOS app must
/// be able to ship without leaking a proxy URL into the binary string
/// table, and the resolver's `callProxy` seam stays unused until something
/// upstream constructs an `AIProxyHTTPClient` explicitly.
///
/// Reference dev URL:
///   https://re-direct-ai-proxy-dev.nadineaisyah170806.workers.dev
///
/// The proxy contract lives in `docs/AI_PROXY_IMPLEMENTATION_PLAN.md` and
/// the iOS-side DTOs (`AIRecommendationRequest`, `AIRecommendationResponse`,
/// `AIProxyError`) are the canonical wire shape.
struct AIProxyConfig: Sendable, Equatable {

    /// Base URL of the deployed proxy. The `/v1/recommendation` endpoint is
    /// appended by the client; do not include it here.
    let baseURL: URL

    /// Per-request timeout in seconds. Defaults to 20 — the proxy's own
    /// route timeout is 6 s, but the iOS-side budget allows for cold-start
    /// + TLS + small mobile-network jitter.
    let timeoutSeconds: TimeInterval

    init(baseURL: URL, timeoutSeconds: TimeInterval = 20) {
        self.baseURL = baseURL
        self.timeoutSeconds = timeoutSeconds
    }
}
