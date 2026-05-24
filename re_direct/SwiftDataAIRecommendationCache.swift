import Foundation
import SwiftData

@MainActor
struct SwiftDataAIRecommendationCache: AIRecommendationCache {

    /// Default freshness window for cached Daily Direct recommendations.
    /// 24 h matches the proxy plan's recommended TTL — see
    /// `docs/AI_INTEGRATION_PLAN.md` §5 and §9 (open question 3).
    ///
    /// Rule, plain English: "use cached AI content while it is fresh; only
    /// allow a new proxy call after the freshness window expires." Stored
    /// rows aren't deleted when they age out; they're just hidden from
    /// `lookup(_:)` so the resolver proceeds to its proxy step. If the
    /// proxy then succeeds, write-back (Phase 6D-D) replaces them with a
    /// fresh row via dedup-by-`promptInputHash`.
    static let defaultCacheTTL: TimeInterval = 24 * 60 * 60

    let context: ModelContext
    let cacheTTL: TimeInterval
    let now: @Sendable () -> Date

    init(
        context: ModelContext,
        cacheTTL: TimeInterval = SwiftDataAIRecommendationCache.defaultCacheTTL,
        now: @Sendable @escaping () -> Date = { Date() }
    ) {
        self.context = context
        self.cacheTTL = cacheTTL
        self.now = now
    }

    func lookup(_ key: AICacheKey) async -> AICacheHit? {
        let fingerprint = key.localFingerprint
        var descriptor = FetchDescriptor<AIRecommendation>(
            predicate: #Predicate { row in
                row.localInputFingerprint == fingerprint && row.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let row = (try? context.fetch(descriptor))?.first else { return nil }

        // Freshness gate. Rows older than the TTL aren't surfaced — the
        // resolver treats this as a cache miss and proceeds to the proxy
        // step. The row stays in storage for diagnostic/audit purposes,
        // and a successful proxy response will replace it via dedup-by-
        // `promptInputHash` in the writer.
        let age = now().timeIntervalSince(row.createdAt)
        if age >= cacheTTL { return nil }

        return AICacheHit(
            promptInputHash: row.promptInputHash,
            topicSlug: row.topicSlugSnapshot,
            topicTitle: row.topicTitleSnapshot,
            promptBody: row.body,
            suggestedMinutes: row.suggestedMinutes,
            provider: row.provider,
            modelVersion: row.modelVersion,
            createdAt: row.createdAt
        )
    }

    func recentPromptInputHashes(limit: Int) async -> [String] {
        var descriptor = FetchDescriptor<AIRecommendation>(
            predicate: #Predicate { row in
                row.deletedAt == nil && row.promptInputHash != ""
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(0, limit) * 2

        guard let rows = try? context.fetch(descriptor) else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for row in rows {
            if seen.insert(row.promptInputHash).inserted {
                result.append(row.promptInputHash)
                if result.count >= limit { break }
            }
        }
        return result
    }

    /// Stores a fresh proxy response into the cache. Not part of the protocol —
    /// the resolver writes through here directly after a successful proxy call.
    func store(
        response: AIRecommendationResponse,
        for key: AICacheKey,
        linkingTo topic: CuriosityTopic? = nil
    ) {
        let row = AIRecommendation()
        row.promptInputHash = response.promptInputHash
        row.localInputFingerprint = key.localFingerprint
        row.topicTitleSnapshot = response.topicTitle
        row.topicSlugSnapshot = response.topicSlug
        row.body = response.promptBody
        row.suggestedMinutes = response.suggestedMinutes
        row.provider = response.provider
        row.modelVersion = response.modelVersion
        row.createdAt = response.createdAt
        row.topic = topic
        context.insert(row)
        try? context.save()
    }

    /// `AIRecommendationCache` protocol entry point — what the resolver
    /// calls after a successful proxy response. Skips the insert if a
    /// non-deleted row with the same `promptInputHash` already exists,
    /// preventing duplicate accumulation across cache-miss-then-hit
    /// sequences in the same session.
    func store(_ response: AIRecommendationResponse, for key: AICacheKey) async {
        if hasExistingRow(matching: response.promptInputHash) { return }
        store(response: response, for: key, linkingTo: nil)
    }

    private func hasExistingRow(matching promptInputHash: String) -> Bool {
        let hash = promptInputHash
        var descriptor = FetchDescriptor<AIRecommendation>(
            predicate: #Predicate { row in
                row.promptInputHash == hash && row.deletedAt == nil
            }
        )
        descriptor.fetchLimit = 1
        let rows = (try? context.fetch(descriptor)) ?? []
        return !rows.isEmpty
    }
}
