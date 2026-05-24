import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("SwiftDataAIRecommendationCache")
struct SwiftDataAIRecommendationCacheTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func sampleRequest(interests: [String] = ["bioluminescence"], minutes: Int = 15) -> AIRecommendationRequest {
        AIRecommendationRequest(
            interests: interests,
            mood: nil,
            timeAvailableMinutes: minutes,
            providerPreference: .auto,
            locale: "en-US"
        )
    }

    private func sampleResponse(hash: String, title: String = "Bioluminescence", at date: Date = Date()) -> AIRecommendationResponse {
        AIRecommendationResponse(
            id: "rec_\(UUID().uuidString)",
            topicSlug: "bioluminescence",
            topicTitle: title,
            promptBody: "Why blue?",
            suggestedMinutes: 12,
            provider: "anthropic-haiku-4-5",
            modelVersion: "claude-haiku-4-5-20251001",
            promptInputHash: hash,
            cached: false,
            createdAt: date
        )
    }

    @Test func storeAndLookupRoundTrip() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let key = AICacheKey(request: sampleRequest())
        let response = sampleResponse(hash: "abc123")

        cache.store(response: response, for: key)
        let hit = await cache.lookup(key)
        #expect(hit?.promptInputHash == "abc123")
        #expect(hit?.topicTitle == "Bioluminescence")
        #expect(hit?.suggestedMinutes == 12)
        #expect(hit?.provider == "anthropic-haiku-4-5")
    }

    @Test func lookupReturnsNilForDifferentKey() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let storedKey = AICacheKey(request: sampleRequest(interests: ["alpha"]))
        let otherKey = AICacheKey(request: sampleRequest(interests: ["beta"]))

        cache.store(response: sampleResponse(hash: "h1"), for: storedKey)
        let miss = await cache.lookup(otherKey)
        #expect(miss == nil)
    }

    @Test func lookupReturnsMostRecentForSameKey() async throws {
        // Injected clock so the deliberately-old fixture rows are still
        // within the freshness window (added in Phase 6D-E). The test's
        // intent — assert lookup returns the most-recent row when multiple
        // rows share a key — is unchanged.
        let context = try makeContext()
        let injectedNow = Date(timeIntervalSince1970: 2_001)
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            now: { injectedNow }
        )
        let key = AICacheKey(request: sampleRequest())
        let older = sampleResponse(hash: "old", at: Date(timeIntervalSince1970: 1_000))
        let newer = sampleResponse(hash: "new", at: Date(timeIntervalSince1970: 2_000))
        cache.store(response: older, for: key)
        cache.store(response: newer, for: key)

        let hit = await cache.lookup(key)
        #expect(hit?.promptInputHash == "new")
    }

    @Test func recentPromptInputHashesIsOrderedNewestFirstAndDeduped() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let key = AICacheKey(request: sampleRequest())

        cache.store(response: sampleResponse(hash: "h1", at: Date(timeIntervalSince1970: 1_000)), for: key)
        cache.store(response: sampleResponse(hash: "h2", at: Date(timeIntervalSince1970: 2_000)), for: key)
        cache.store(response: sampleResponse(hash: "h2", at: Date(timeIntervalSince1970: 3_000)), for: key)
        cache.store(response: sampleResponse(hash: "h3", at: Date(timeIntervalSince1970: 4_000)), for: key)

        let hashes = await cache.recentPromptInputHashes(limit: 10)
        #expect(hashes == ["h3", "h2", "h1"])
    }

    @Test func recentPromptInputHashesRespectsLimit() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let key = AICacheKey(request: sampleRequest())
        for i in 1...5 {
            cache.store(
                response: sampleResponse(hash: "h\(i)", at: Date(timeIntervalSince1970: TimeInterval(i * 1_000))),
                for: key
            )
        }
        let hashes = await cache.recentPromptInputHashes(limit: 2)
        #expect(hashes == ["h5", "h4"])
    }

    // MARK: - Protocol-conforming write-back (Phase 6D-D)

    @Test func protocolStoreInsertsWhenAbsent() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let key = AICacheKey(request: sampleRequest())
        let response = sampleResponse(hash: "abc-protocol")

        await cache.store(response, for: key)

        // Round-trip via lookup confirms the row landed.
        let hit = await cache.lookup(key)
        #expect(hit?.promptInputHash == "abc-protocol")
        #expect(hit?.topicTitle == "Bioluminescence")
        #expect(hit?.provider == "anthropic-haiku-4-5")
        #expect(hit?.modelVersion == "claude-haiku-4-5-20251001")
    }

    @Test func protocolStoreDedupesOnPromptInputHash() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let key = AICacheKey(request: sampleRequest())
        let response = sampleResponse(hash: "abc-dedup")

        // Three consecutive write-backs with the same prompt_input_hash
        // should result in only one row in storage.
        await cache.store(response, for: key)
        await cache.store(response, for: key)
        await cache.store(response, for: key)

        let descriptor = FetchDescriptor<AIRecommendation>(
            predicate: #Predicate { row in
                row.promptInputHash == "abc-dedup" && row.deletedAt == nil
            }
        )
        let rows = try context.fetch(descriptor)
        #expect(rows.count == 1, "Dedup should prevent duplicate active rows for the same hash")
    }

    @Test func protocolStoreAllowsDistinctHashes() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let key = AICacheKey(request: sampleRequest())

        await cache.store(sampleResponse(hash: "h-one"), for: key)
        await cache.store(sampleResponse(hash: "h-two"), for: key)
        await cache.store(sampleResponse(hash: "h-three"), for: key)

        let descriptor = FetchDescriptor<AIRecommendation>(
            predicate: #Predicate { row in row.deletedAt == nil }
        )
        let rows = try context.fetch(descriptor)
        #expect(rows.count == 3)
        #expect(Set(rows.map { $0.promptInputHash }) == ["h-one", "h-two", "h-three"])
    }

    @Test func protocolStorePreservesProviderAndModelFields() async throws {
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
        let key = AICacheKey(request: sampleRequest())
        let response = AIRecommendationResponse(
            id: "rec-fields",
            topicSlug: "self-sabotage",
            topicTitle: "Self Sabotage",
            promptBody: "Notice what you reach for when avoidance kicks in.",
            suggestedMinutes: 8,
            provider: "deepseek",
            modelVersion: "deepseek-v4-flash",
            promptInputHash: "field-hash",
            cached: false,
            createdAt: Date()
        )

        await cache.store(response, for: key)
        let hit = try #require(await cache.lookup(key))
        #expect(hit.provider == "deepseek")
        #expect(hit.modelVersion == "deepseek-v4-flash")
        #expect(hit.promptInputHash == "field-hash")
        #expect(hit.topicSlug == "self-sabotage")
        #expect(hit.topicTitle == "Self Sabotage")
        #expect(hit.promptBody == "Notice what you reach for when avoidance kicks in.")
        #expect(hit.suggestedMinutes == 8)
    }

    // MARK: - Freshness policy (Phase 6D-E)

    @Test func defaultCacheTTLIs24Hours() {
        #expect(SwiftDataAIRecommendationCache.defaultCacheTTL == 24 * 60 * 60)
    }

    @Test func lookupReturnsFreshRow() async throws {
        // A row written "now" is freshly cached and must surface.
        let context = try makeContext()
        let nowAnchor = Date(timeIntervalSince1970: 2_000_000_000) // 2033 - some fixed point
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            cacheTTL: 24 * 60 * 60,
            now: { nowAnchor }
        )
        let key = AICacheKey(request: sampleRequest())
        let response = sampleResponse(hash: "fresh-row", at: nowAnchor)

        await cache.store(response, for: key)
        let hit = await cache.lookup(key)
        #expect(hit?.promptInputHash == "fresh-row")
    }

    @Test func lookupHidesStaleRow() async throws {
        // A row older than the TTL must be treated as a cache miss so the
        // resolver proceeds to the proxy step.
        let context = try makeContext()
        let writtenAt = Date(timeIntervalSince1970: 2_000_000_000)
        let staleNow = writtenAt.addingTimeInterval(25 * 60 * 60) // 25h later
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            cacheTTL: 24 * 60 * 60,
            now: { staleNow }
        )
        let key = AICacheKey(request: sampleRequest())
        let response = sampleResponse(hash: "stale-row", at: writtenAt)

        await cache.store(response, for: key)
        let hit = await cache.lookup(key)
        #expect(hit == nil, "Stale row must be hidden from lookup")
    }

    @Test func lookupBoundaryIsInclusiveAtExactlyTTL() async throws {
        // Exactly at TTL is considered stale (>=). The strictly-less-than
        // boundary keeps the rule deterministic: a hit must be strictly
        // newer than TTL ago.
        let context = try makeContext()
        let writtenAt = Date(timeIntervalSince1970: 2_000_000_000)
        let exactlyAtTTL = writtenAt.addingTimeInterval(24 * 60 * 60)
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            cacheTTL: 24 * 60 * 60,
            now: { exactlyAtTTL }
        )
        let key = AICacheKey(request: sampleRequest())
        let response = sampleResponse(hash: "boundary-row", at: writtenAt)

        await cache.store(response, for: key)
        let hit = await cache.lookup(key)
        #expect(hit == nil, "Row at exactly TTL must be considered stale")
    }

    @Test func lookupBoundaryStrictlyBeforeTTLIsFresh() async throws {
        // One second before TTL → still fresh.
        let context = try makeContext()
        let writtenAt = Date(timeIntervalSince1970: 2_000_000_000)
        let justBeforeTTL = writtenAt.addingTimeInterval(24 * 60 * 60 - 1)
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            cacheTTL: 24 * 60 * 60,
            now: { justBeforeTTL }
        )
        let key = AICacheKey(request: sampleRequest())
        let response = sampleResponse(hash: "almost-stale", at: writtenAt)

        await cache.store(response, for: key)
        let hit = await cache.lookup(key)
        #expect(hit?.promptInputHash == "almost-stale")
    }

    @Test func lookupRespectsCustomTTL() async throws {
        // Sanity: a 60-second TTL hides anything older than 60s.
        let context = try makeContext()
        let writtenAt = Date(timeIntervalSince1970: 2_000_000_000)
        let oneMinuteLater = writtenAt.addingTimeInterval(61)
        let cache = SwiftDataAIRecommendationCache(
            context: context,
            cacheTTL: 60,
            now: { oneMinuteLater }
        )
        let key = AICacheKey(request: sampleRequest())
        let response = sampleResponse(hash: "tiny-ttl", at: writtenAt)

        await cache.store(response, for: key)
        let hit = await cache.lookup(key)
        #expect(hit == nil, "Custom TTL of 60s must hide a 61s-old row")
    }
}
