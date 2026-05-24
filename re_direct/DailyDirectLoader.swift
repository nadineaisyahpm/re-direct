import Foundation

/// Builds an `AIRecommendationRequest` from local personalization seeds and
/// asks `AIRecommendationResolver` for a Daily Direct recommendation. The
/// resolver itself owns the fallback ladder (cache → proxy → seed); this
/// loader is the thin layer that decides *what to ask for*.
///
/// Phase 6D-A scope: the loader is fully testable but is **not** wired into
/// `DashboardView` in this slice. A future slice flips the call site.
///
/// Design notes:
/// - One `load()` call → exactly one `resolver.resolve(...)` invocation →
///   at most one proxy network call. No retries, no automatic loops.
/// - The proxy call is injected as a closure so tests can mock it without
///   touching `AIProxyHTTPClient`'s URLSession.
/// - Interest seeds default to the personal v1 list documented in
///   `docs/AI_INTEGRATION_PLAN.md` §12.2. Future onboarding/Settings work
///   will replace this default with user-declared seeds.
struct DailyDirectLoader: Sendable {

    // ─────────────────────────────────────────
    // MARK: Personal v1 defaults
    // ─────────────────────────────────────────

    /// Personal v1 interest seeds — per `AI_INTEGRATION_PLAN.md §12.2`.
    /// Replace with `UserProfile.interestSeeds` once the storage slice
    /// lands. **Do not hardcode this list as a universal product default
    /// in any future generalization slice.**
    static let defaultPersonalInterestSeeds: [String] = [
        "Apple",
        "Machine Learning",
        "AI",
        "Neuroscience",
        "Software Engineering",
    ]

    static let defaultTimeBudgetMinutes: Int = 15
    static let defaultLocale: String = "en-US"

    // ─────────────────────────────────────────
    // MARK: Dependencies
    // ─────────────────────────────────────────

    let resolver: AIRecommendationResolver
    let callProxy: @Sendable (AIRecommendationRequest) async throws -> AIRecommendationResponse
    let interestSeeds: [String]

    init(
        resolver: AIRecommendationResolver,
        callProxy: @escaping @Sendable (AIRecommendationRequest) async throws -> AIRecommendationResponse,
        interestSeeds: [String] = DailyDirectLoader.defaultPersonalInterestSeeds
    ) {
        self.resolver = resolver
        self.callProxy = callProxy
        self.interestSeeds = interestSeeds
    }

    // ─────────────────────────────────────────
    // MARK: Load
    // ─────────────────────────────────────────

    /// Run the full fallback ladder once: cache → proxy → seed.
    /// Returns whatever the resolver returns — never throws; the resolver's
    /// hardcoded last-resort fallback covers the case where even the seed
    /// provider is empty.
    func load(
        timeBudgetMinutes: Int = DailyDirectLoader.defaultTimeBudgetMinutes,
        locale: String? = nil
    ) async -> AIRecommendationSource {
        let request = makeRequest(timeBudgetMinutes: timeBudgetMinutes, locale: locale)
        return await resolver.resolve(request: request, callProxy: callProxy)
    }

    // ─────────────────────────────────────────
    // MARK: Pure builder (testable in isolation)
    // ─────────────────────────────────────────

    /// Construct the request that will be handed to the resolver. Lifted
    /// out so tests can assert the payload shape without calling `load()`.
    ///
    /// Privacy contract — fields included here are the only signals that
    /// can ever cross the network boundary via this loader:
    /// - `interests` from the personal v1 seeds (or the injected override)
    /// - `time_available_minutes` from the caller
    /// - `provider_preference` fixed to `.auto`
    /// - `locale` normalized to BCP-47 short form
    ///
    /// **Not included anywhere:** reflection bodies, Apple identity,
    /// DeviceActivity tokens, precise timestamps, screenshots, notes.
    /// See `docs/AI_INTEGRATION_PLAN.md` §4 and §12.4.
    func makeRequest(
        timeBudgetMinutes: Int = DailyDirectLoader.defaultTimeBudgetMinutes,
        locale: String? = nil
    ) -> AIRecommendationRequest {
        let normalized = Self.normalizeLocale(locale ?? Locale.current.identifier)
        return AIRecommendationRequest(
            interests: interestSeeds,
            mood: nil,
            timeAvailableMinutes: timeBudgetMinutes,
            excludePromptHashes: [],
            providerPreference: .auto,
            locale: normalized
        )
    }

    /// `Locale.current.identifier` on iOS often returns `en_US` (underscore)
    /// while `AIRequestValidator` expects BCP-47 short form `en-US`. Convert
    /// and fall back to `en-US` if the value can't be salvaged so the
    /// proxy doesn't reject the request as `invalid_input`.
    static func normalizeLocale(_ raw: String) -> String {
        let hyphenated = raw.replacingOccurrences(of: "_", with: "-")
        // Trim Unicode locale extensions (e.g. `en-US@calendar=gregorian`).
        let trimmed = hyphenated.split(separator: "@").first.map(String.init) ?? hyphenated
        // Accept either `xx` or `xx-XX`; anything else falls back to default.
        let pattern = #"^[a-z]{2}(-[A-Z]{2})?$"#
        if trimmed.range(of: pattern, options: .regularExpression) != nil {
            return trimmed
        }
        // Common fixable case: lowercase region (e.g. `en-us`).
        if let dashIndex = trimmed.firstIndex(of: "-"),
           trimmed.distance(from: trimmed.startIndex, to: dashIndex) == 2,
           trimmed.count == 5 {
            let lang = trimmed[..<dashIndex]
            let region = trimmed[trimmed.index(after: dashIndex)...]
            let candidate = "\(lang.lowercased())-\(region.uppercased())"
            if candidate.range(of: pattern, options: .regularExpression) != nil {
                return candidate
            }
        }
        return DailyDirectLoader.defaultLocale
    }
}
