import Testing
import Foundation
import SwiftData
@testable import re_direct

// ─────────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────────

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema(ReDirectSchema.allModels)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

private func sampleRequest(minutes: Int = 15, locale: String = "en-US") -> AIRecommendationRequest {
    AIRecommendationRequest(
        interests: ["bioluminescence"],
        mood: nil,
        timeAvailableMinutes: minutes,
        excludePromptHashes: [],
        providerPreference: .auto,
        locale: locale
    )
}

private func sampleResponse(hash: String = "abc-resolver") -> AIRecommendationResponse {
    AIRecommendationResponse(
        id: "01TEST",
        topicSlug: "bioluminescence",
        topicTitle: "Bioluminescence",
        promptBody: "Why blue?",
        suggestedMinutes: 12,
        provider: "deepseek",
        modelVersion: "deepseek-v4-flash",
        promptInputHash: hash,
        cached: false,
        createdAt: Date()
    )
}

/// Always-nil seed; the resolver's hardcoded last-resort default takes over
/// when this returns nil and the proxy errors.
private struct EmptySeed: SeededPromptProvider {
    func pickPrompt(matching interests: [String], excluding shownSlugs: Set<String>) async -> SeededCuriosityPrompt? { nil }
    func anyPrompt() async -> SeededCuriosityPrompt? { nil }
}

@MainActor
private func countAIRecommendationRows(_ context: ModelContext) throws -> Int {
    let descriptor = FetchDescriptor<AIRecommendation>(
        predicate: #Predicate { row in row.deletedAt == nil }
    )
    return try context.fetch(descriptor).count
}

// ─────────────────────────────────────────────
// MARK: - Tests
// ─────────────────────────────────────────────

@MainActor
@Suite("AIRecommendationResolver write-back")
struct AIRecommendationResolverTests {

    // MARK: successful proxy persists

    @Test func successfulProxyWritesToCache() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())
        let request = sampleRequest()
        let response = sampleResponse(hash: "wb-success")

        // Empty cache at start.
        #expect(try countAIRecommendationRows(context) == 0)

        let result = await resolver.resolve(request: request) { _ in response }

        if case .proxy(let r) = result {
            #expect(r.promptInputHash == "wb-success")
        } else {
            Issue.record("Expected .proxy outcome but got \(result)")
        }

        // Exactly one row written.
        #expect(try countAIRecommendationRows(context) == 1)
    }

    // MARK: cache hit avoids proxy call

    @Test func subsequentResolveReturnsCacheHitWithoutCallingProxy() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())
        let request = sampleRequest()

        // First resolve: proxy succeeds, write-back persists.
        var proxyCallCount = 0
        let firstResult = await resolver.resolve(request: request) { _ in
            proxyCallCount += 1
            return sampleResponse(hash: "wb-cache-hit")
        }
        if case .proxy = firstResult {} else {
            Issue.record("First resolve should have been .proxy, got \(firstResult)")
        }
        #expect(proxyCallCount == 1)

        // Second resolve with the SAME request: must hit cache, no proxy.
        let secondResult = await resolver.resolve(request: request) { _ in
            proxyCallCount += 1
            return sampleResponse(hash: "should-not-happen")
        }
        if case .localCache(let hit) = secondResult {
            #expect(hit.promptInputHash == "wb-cache-hit")
            #expect(hit.provider == "deepseek")
            #expect(hit.modelVersion == "deepseek-v4-flash")
        } else {
            Issue.record("Second resolve should have been .localCache, got \(secondResult)")
        }
        #expect(proxyCallCount == 1, "Cache hit must avoid the proxy call")
    }

    // MARK: seed fallback does NOT persist

    @Test func seedFallbackDoesNotWriteToCache() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())

        let result = await resolver.resolve(request: sampleRequest()) { _ in
            throw AIProxyError.upstreamFailed
        }

        if case .seedFallback = result {
            // Expected: proxy failed, seed provider returned nil, resolver
            // used its hardcoded "Take a breath" default.
        } else {
            Issue.record("Expected .seedFallback but got \(result)")
        }

        // Zero rows persisted. Seed fallback must not pollute the cache.
        #expect(try countAIRecommendationRows(context) == 0)
    }

    @Test func proxyTimeoutDoesNotWriteToCache() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())

        _ = await resolver.resolve(request: sampleRequest()) { _ in
            throw AIProxyError.upstreamTimeout
        }

        #expect(try countAIRecommendationRows(context) == 0)
    }

    @Test func proxyNetworkErrorDoesNotWriteToCache() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())

        _ = await resolver.resolve(request: sampleRequest()) { _ in
            throw AIProxyError.network(message: "offline")
        }

        #expect(try countAIRecommendationRows(context) == 0)
    }

    // MARK: dedup across resolves

    @Test func repeatedSuccessfulResolvesDoNotDuplicateRows() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())
        let request = sampleRequest()

        // First resolve writes a row.
        _ = await resolver.resolve(request: request) { _ in sampleResponse(hash: "wb-dedup") }
        #expect(try countAIRecommendationRows(context) == 1)

        // Second resolve hits cache → no second write.
        _ = await resolver.resolve(request: request) { _ in sampleResponse(hash: "wb-dedup") }
        #expect(try countAIRecommendationRows(context) == 1)

        // Third resolve with a DIFFERENT request key but the proxy returns
        // the same hash → dedup on prompt_input_hash kicks in even though
        // the local fingerprint differs.
        let differentRequest = sampleRequest(minutes: 30)
        _ = await resolver.resolve(request: differentRequest) { _ in
            sampleResponse(hash: "wb-dedup")
        }
        #expect(try countAIRecommendationRows(context) == 1, "Dedup on promptInputHash should prevent duplicate active rows")
    }

    // MARK: provider/model fields preserved

    @Test func writeBackPreservesProviderAndModelFields() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())
        let request = sampleRequest()

        let response = AIRecommendationResponse(
            id: "rec-fields",
            topicSlug: "self-sabotage",
            topicTitle: "Self Sabotage",
            promptBody: "Notice avoidance.",
            suggestedMinutes: 8,
            provider: "deepseek",
            modelVersion: "deepseek-v4-flash",
            promptInputHash: "wb-fields",
            cached: false,
            createdAt: Date()
        )
        _ = await resolver.resolve(request: request) { _ in response }

        // Read back via the cache's read API and assert the fields landed.
        let hit = try #require(await cache.lookup(AICacheKey(request: request)))
        #expect(hit.promptInputHash == "wb-fields")
        #expect(hit.topicSlug == "self-sabotage")
        #expect(hit.topicTitle == "Self Sabotage")
        #expect(hit.promptBody == "Notice avoidance.")
        #expect(hit.suggestedMinutes == 8)
        #expect(hit.provider == "deepseek")
        #expect(hit.modelVersion == "deepseek-v4-flash")
    }

    // MARK: - Freshness policy (Phase 6D-E)

    @Test func freshCacheAvoidsProxyCall() async throws {
        let context = try makeContext()
        let nowAnchor = Date(timeIntervalSince1970: 2_000_000_000)
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            cacheTTL: 24 * 60 * 60,
            now: { nowAnchor }
        )
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())
        let request = sampleRequest()

        // Seed a row whose createdAt is contemporaneous with the injected
        // clock — well within the 24h freshness window.
        let freshResponse = AIRecommendationResponse(
            id: "rec-fresh",
            topicSlug: "bioluminescence",
            topicTitle: "Bioluminescence",
            promptBody: "Fresh body.",
            suggestedMinutes: 12,
            provider: "deepseek",
            modelVersion: "deepseek-v4-flash",
            promptInputHash: "fresh",
            cached: false,
            createdAt: nowAnchor
        )
        cache.store(response: freshResponse, for: AICacheKey(request: request))

        var proxyCallCount = 0
        let result = await resolver.resolve(request: request) { _ in
            proxyCallCount += 1
            return sampleResponse(hash: "should-not-be-called")
        }
        if case .localCache(let hit) = result {
            #expect(hit.promptInputHash == "fresh")
        } else {
            Issue.record("Expected .localCache for a fresh hit but got \(result)")
        }
        #expect(proxyCallCount == 0, "Fresh cache must avoid the proxy")
    }

    @Test func staleCacheAllowsProxyCall() async throws {
        // Inject a "now" that's 25 hours after the cached row's createdAt
        // so the cache marks the row stale.
        let context = try makeContext()
        let writtenAt = Date(timeIntervalSince1970: 2_000_000_000)
        let staleNow = writtenAt.addingTimeInterval(25 * 60 * 60)
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            cacheTTL: 24 * 60 * 60,
            now: { staleNow }
        )
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())
        let request = sampleRequest()

        // Seed a stale row (createdAt is 25h before staleNow).
        let staleResponse = AIRecommendationResponse(
            id: "rec-stale",
            topicSlug: "bioluminescence",
            topicTitle: "Bioluminescence",
            promptBody: "Old body.",
            suggestedMinutes: 12,
            provider: "deepseek",
            modelVersion: "deepseek-v4-flash",
            promptInputHash: "stale-hash",
            cached: false,
            createdAt: writtenAt
        )
        cache.store(response: staleResponse, for: AICacheKey(request: request))

        var proxyCallCount = 0
        let freshResponse = AIRecommendationResponse(
            id: "rec-fresh",
            topicSlug: "bioluminescence",
            topicTitle: "Bioluminescence",
            promptBody: "Fresh body.",
            suggestedMinutes: 10,
            provider: "deepseek",
            modelVersion: "deepseek-v4-flash",
            promptInputHash: "fresh-hash",
            cached: false,
            createdAt: staleNow
        )
        let result = await resolver.resolve(request: request) { _ in
            proxyCallCount += 1
            return freshResponse
        }

        if case .proxy(let r) = result {
            #expect(r.promptInputHash == "fresh-hash")
        } else {
            Issue.record("Expected .proxy outcome after stale cache, got \(result)")
        }
        #expect(proxyCallCount == 1, "Stale cache must allow the proxy call")

        // And the cache now contains both the stale + fresh row (writer
        // dedupes on prompt_input_hash, not on staleness, so both stay).
        let descriptor = FetchDescriptor<AIRecommendation>(
            predicate: #Predicate { row in row.deletedAt == nil }
        )
        let rows = try context.fetch(descriptor)
        let hashes = Set(rows.map { $0.promptInputHash })
        #expect(hashes == ["stale-hash", "fresh-hash"])
    }

    @Test func staleCacheThenProxyFailureFallsBackGracefully() async throws {
        // Even after a stale cache row, a proxy failure should not crash;
        // the resolver falls back via its existing seed/last-resort path.
        let context = try makeContext()
        let writtenAt = Date(timeIntervalSince1970: 2_000_000_000)
        let staleNow = writtenAt.addingTimeInterval(48 * 60 * 60) // 2 days later
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            cacheTTL: 24 * 60 * 60,
            now: { staleNow }
        )
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())
        let request = sampleRequest()

        cache.store(
            response: AIRecommendationResponse(
                id: "rec-stale2",
                topicSlug: nil,
                topicTitle: "Old",
                promptBody: "Old.",
                suggestedMinutes: 5,
                provider: "deepseek",
                modelVersion: "deepseek-v4-flash",
                promptInputHash: "older-hash",
                cached: false,
                createdAt: writtenAt
            ),
            for: AICacheKey(request: request)
        )

        let result = await resolver.resolve(request: request) { _ in
            throw AIProxyError.upstreamFailed
        }

        // Stale was bypassed → proxy was tried → proxy failed →
        // seed fallback (EmptySeed returns nil → resolver's hardcoded
        // last-resort kicks in).
        if case .seedFallback(let seed, _) = result {
            // The hardcoded last-resort uses topicSlug "default".
            #expect(seed.topicSlug == "default")
        } else {
            Issue.record("Expected .seedFallback but got \(result)")
        }
    }

    @Test func freshCacheUnaffectedByDefaultClock() async throws {
        // Sanity: with the default (real-clock) initializer, a row stored
        // a moment ago is still fresh and surfaces.
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let resolver = AIRecommendationResolver(cache: cache, seed: EmptySeed())
        let request = sampleRequest()

        cache.store(
            response: sampleResponse(hash: "now-hash"),
            for: AICacheKey(request: request)
        )

        var proxyCallCount = 0
        let result = await resolver.resolve(request: request) { _ in
            proxyCallCount += 1
            return sampleResponse(hash: "x")
        }
        if case .localCache(let hit) = result {
            #expect(hit.promptInputHash == "now-hash")
        } else {
            Issue.record("Expected .localCache, got \(result)")
        }
        #expect(proxyCallCount == 0)
    }
}
