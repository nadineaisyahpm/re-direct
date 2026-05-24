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
}
