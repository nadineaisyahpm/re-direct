import Foundation

/// Single source of truth for AI proxy endpoint configuration on iOS.
/// Dashboard / Daily Direct call sites read from here so the dev Worker
/// URL string lives in **exactly one place** — never duplicated into UI
/// files, never inlined as a literal.
///
/// What lives here:
/// - The deployed dev Worker URL.
/// - `dailyDirect`: an `AIProxyConfig` factory ready for the HTTP client.
///
/// What does NOT live here:
/// - Provider API keys (they're a Worker secret in Cloudflare; iOS never
///   holds one — see `docs/AI_INTEGRATION_PLAN.md` §4).
/// - A user-facing setting. The URL is internal config; switching it to
///   a build-time injection or a Settings field is a later slice.
enum AIEnvironment {

    /// Cloudflare Worker dev URL — currently the only deployed environment.
    /// Phase 6B.3 deployed this; pre-push secret scans treat this hostname
    /// as expected (not a leaked secret).
    static let dailyDirectProxyURL: URL = URL(
        string: "https://re-direct-ai-proxy-dev.nadineaisyah170806.workers.dev"
    )!

    /// `AIProxyConfig` preset for the Daily Direct call site. A future
    /// slice can branch on a build flag or Settings field here without
    /// touching any call site that already reads `AIEnvironment.dailyDirect`.
    static var dailyDirect: AIProxyConfig {
        AIProxyConfig(baseURL: dailyDirectProxyURL)
    }
}
