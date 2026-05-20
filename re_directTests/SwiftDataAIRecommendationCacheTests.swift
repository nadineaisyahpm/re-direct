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
        let context = try makeContext()
        let cache = SwiftDataAIRecommendationCache(context: context)
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
}
