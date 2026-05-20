import Foundation
import SwiftData

@MainActor
struct SwiftDataAIRecommendationCache: AIRecommendationCache {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
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
}
