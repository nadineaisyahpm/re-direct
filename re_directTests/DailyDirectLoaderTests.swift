import Testing
import Foundation
@testable import re_direct

// ─────────────────────────────────────────────
// MARK: - Test doubles
// ─────────────────────────────────────────────

/// `AIRecommendationCache` stub that returns whatever the test wires up.
/// Defaults to a cache miss so the resolver always proceeds to the proxy
/// closure under test.
struct FakeAICache: AIRecommendationCache {
    let hit: AICacheHit?
    init(hit: AICacheHit? = nil) { self.hit = hit }
    func lookup(_ key: AICacheKey) async -> AICacheHit? { hit }
    func recentPromptInputHashes(limit: Int) async -> [String] { [] }
}

/// `SeededPromptProvider` stub. Pick / any return a fixed prompt so we can
/// assert seed-fallback paths returned the expected value.
struct FakeSeed: SeededPromptProvider {
    let prompt: SeededCuriosityPrompt?
    init(
        prompt: SeededCuriosityPrompt? = SeededCuriosityPrompt(
            topicSlug: "fake-topic",
            topicTitle: "Fake Topic",
            promptBody: "A safe seeded fallback.",
            suggestedMinutes: 7
        )
    ) { self.prompt = prompt }
    func pickPrompt(matching interests: [String], excluding shownSlugs: Set<String>) async -> SeededCuriosityPrompt? { prompt }
    func anyPrompt() async -> SeededCuriosityPrompt? { prompt }
}

private func makeResolver(cacheHit: AICacheHit? = nil, seed: SeededCuriosityPrompt? = nil) -> AIRecommendationResolver {
    AIRecommendationResolver(
        cache: FakeAICache(hit: cacheHit),
        seed: seed.map { FakeSeed(prompt: $0) } ?? FakeSeed()
    )
}

/// Counts proxy invocations so tests can assert at-most-once semantics.
actor InvocationCounter {
    private(set) var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
}

private func makeResponse(provider: String = "deepseek") -> AIRecommendationResponse {
    AIRecommendationResponse(
        id: "01TEST",
        topicSlug: "ai-edge",
        topicTitle: "AI on the Edge",
        promptBody: "Find one short paper on small-model inference.",
        suggestedMinutes: 12,
        provider: provider,
        modelVersion: "deepseek-v4-flash",
        promptInputHash: "abc",
        cached: false,
        createdAt: Date()
    )
}

// ─────────────────────────────────────────────
// MARK: - Tests
// ─────────────────────────────────────────────

@Suite("DailyDirectLoader")
struct DailyDirectLoaderTests {

    // MARK: defaults

    @Test func defaultInterestSeedsAreThePersonalV1List() {
        // Per AI_INTEGRATION_PLAN.md §12.2.
        #expect(DailyDirectLoader.defaultPersonalInterestSeeds == [
            "Apple",
            "Machine Learning",
            "AI",
            "Neuroscience",
            "Software Engineering",
        ])
    }

    @Test func defaultSeedsFitWithinValidatorBounds() {
        // AIRequestValidator caps interests at 8 with regex
        // `^[A-Za-z][A-Za-z \-]{0,39}$`. Confirm the personal v1 list
        // passes — otherwise every load() falls straight through to seed.
        let request = AIRecommendationRequest(
            interests: DailyDirectLoader.defaultPersonalInterestSeeds,
            mood: nil,
            timeAvailableMinutes: 15,
            excludePromptHashes: [],
            providerPreference: .auto,
            locale: "en-US"
        )
        #expect(AIRequestValidator.validate(request) == nil)
    }

    // MARK: makeRequest — pure builder

    @Test func makeRequestIncludesAllInterestSeeds() {
        let loader = DailyDirectLoader(
            resolver: makeResolver(),
            callProxy: { _ in makeResponse() }
        )
        let request = loader.makeRequest()
        #expect(request.interests == DailyDirectLoader.defaultPersonalInterestSeeds)
    }

    @Test func makeRequestRespectsInjectedSeeds() {
        let custom = ["Cartography", "Bioluminescence"]
        let loader = DailyDirectLoader(
            resolver: makeResolver(),
            callProxy: { _ in makeResponse() },
            interestSeeds: custom
        )
        #expect(loader.makeRequest().interests == custom)
    }

    @Test func makeRequestDefaultsAreSafe() {
        let loader = DailyDirectLoader(
            resolver: makeResolver(),
            callProxy: { _ in makeResponse() }
        )
        let request = loader.makeRequest()
        #expect(request.mood == nil)
        #expect(request.timeAvailableMinutes == 15)
        #expect(request.excludePromptHashes.isEmpty)
        #expect(request.providerPreference == .auto)
        // The default locale should pass the validator.
        #expect(AIRequestValidator.validate(request) == nil)
    }

    @Test func makeRequestEncodesWithoutForbiddenFields() throws {
        // Round-trip the constructed request through the same encoder the
        // HTTP client uses, then assert the payload has no leaked keys
        // from AI_INTEGRATION_PLAN.md §4.2.
        let loader = DailyDirectLoader(
            resolver: makeResolver(),
            callProxy: { _ in makeResponse() }
        )
        let request = loader.makeRequest()
        let body = try AIProxyHTTPClient.encodeBody(request)
        let json = try #require(String(data: body, encoding: .utf8))
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
        // Sanity: interests ARE included.
        #expect(json.contains("\"interests\""))
    }

    // MARK: locale normalization

    @Test func normalizeLocaleHandlesUnderscoreVariant() {
        #expect(DailyDirectLoader.normalizeLocale("en_US") == "en-US")
    }

    @Test func normalizeLocalePassesThroughBCP47() {
        #expect(DailyDirectLoader.normalizeLocale("en-US") == "en-US")
        #expect(DailyDirectLoader.normalizeLocale("en") == "en")
    }

    @Test func normalizeLocaleUppercasesLowercasedRegion() {
        #expect(DailyDirectLoader.normalizeLocale("en-us") == "en-US")
    }

    @Test func normalizeLocaleFallsBackOnUnparseable() {
        #expect(DailyDirectLoader.normalizeLocale("garbage") == "en-US")
        #expect(DailyDirectLoader.normalizeLocale("zh_Hant_TW") == "en-US")
    }

    @Test func normalizeLocaleStripsExtensions() {
        #expect(DailyDirectLoader.normalizeLocale("en_US@calendar=gregorian") == "en-US")
    }

    // MARK: load — happy path

    @Test func loadReturnsProxyResponseOnSuccess() async throws {
        let response = makeResponse()
        let counter = InvocationCounter()
        let loader = DailyDirectLoader(
            resolver: makeResolver(),
            callProxy: { _ in
                await counter.increment()
                return response
            }
        )
        let result = await loader.load()
        if case .proxy(let received) = result {
            #expect(received.id == response.id)
            #expect(received.provider == "deepseek")
        } else {
            Issue.record("Expected .proxy(...) but got \(result)")
        }
        #expect(await counter.value() == 1)
    }

    // MARK: load — fallback

    @Test func loadFallsBackToSeededWhenProxyFailsTransiently() async {
        let counter = InvocationCounter()
        let loader = DailyDirectLoader(
            resolver: makeResolver(),
            callProxy: { _ in
                await counter.increment()
                throw AIProxyError.upstreamFailed
            }
        )
        let result = await loader.load()
        if case .seedFallback(let seed, let reason) = result {
            #expect(seed.topicSlug == "fake-topic")
            #expect(reason == .proxyError)
        } else {
            Issue.record("Expected .seedFallback but got \(result)")
        }
        // Resolver tried the proxy exactly once before falling back.
        #expect(await counter.value() == 1)
    }

    @Test func loadFallsBackToSeededOnTimeout() async {
        let loader = DailyDirectLoader(
            resolver: makeResolver(),
            callProxy: { _ in throw AIProxyError.upstreamTimeout }
        )
        let result = await loader.load()
        guard case .seedFallback(_, let reason) = result else {
            Issue.record("Expected .seedFallback but got \(result)")
            return
        }
        #expect(reason == .proxyError)
    }

    @Test func loadReturnsCacheHitWithoutCallingProxy() async {
        let cachedHit = AICacheHit(
            promptInputHash: "h",
            topicSlug: "cached-topic",
            topicTitle: "Cached",
            promptBody: "From cache.",
            suggestedMinutes: 8,
            provider: "deepseek",
            modelVersion: "deepseek-v4-flash",
            createdAt: Date()
        )
        let counter = InvocationCounter()
        let loader = DailyDirectLoader(
            resolver: makeResolver(cacheHit: cachedHit),
            callProxy: { _ in
                await counter.increment()
                return makeResponse()
            }
        )
        let result = await loader.load()
        if case .localCache(let hit) = result {
            #expect(hit.topicSlug == "cached-topic")
        } else {
            Issue.record("Expected .localCache but got \(result)")
        }
        // Cache hit → proxy never called.
        #expect(await counter.value() == 0)
    }

    // MARK: cost control — at most one proxy call per load()

    @Test func eachExplicitLoadInvokesProxyAtMostOnce() async {
        let counter = InvocationCounter()
        let loader = DailyDirectLoader(
            resolver: makeResolver(),
            callProxy: { _ in
                await counter.increment()
                return makeResponse()
            }
        )
        _ = await loader.load()
        #expect(await counter.value() == 1)
        // Re-invoking is the caller's choice; one .load() == one .resolve()
        // == at most one proxy call.
        _ = await loader.load()
        #expect(await counter.value() == 2)
    }
}
