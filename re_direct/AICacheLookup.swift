import Foundation
import CryptoKit

struct AICacheKey: Hashable, Sendable {
    let interests: [String]
    let mood: String?
    let timeAvailableMinutes: Int
    let locale: String

    init(request: AIRecommendationRequest) {
        self.interests = request.interests.map { $0.lowercased() }.sorted()
        self.mood = request.mood?.lowercased()
        self.timeAvailableMinutes = request.timeAvailableMinutes
        self.locale = request.locale
    }
}

struct AICacheHit: Equatable, Sendable {
    let promptInputHash: String
    let topicSlug: String?
    let topicTitle: String
    let promptBody: String
    let suggestedMinutes: Int
    let provider: String
    let modelVersion: String
    let createdAt: Date
}

extension AICacheKey {
    /// SHA-256 of canonical JSON of the normalized key. Local-only — never transmitted.
    var localFingerprint: String {
        struct Canonical: Encodable {
            let interests: [String]
            let mood: String?
            let timeAvailableMinutes: Int
            let locale: String
        }
        let canonical = Canonical(
            interests: interests,
            mood: mood,
            timeAvailableMinutes: timeAvailableMinutes,
            locale: locale
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(canonical)) ?? Data()
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

protocol AIRecommendationCache: Sendable {
    func lookup(_ key: AICacheKey) async -> AICacheHit?
    func recentPromptInputHashes(limit: Int) async -> [String]

    /// Persist a successful proxy response. Optional — read-only cache
    /// stubs and test fakes can omit this and inherit the no-op default
    /// from the protocol extension. The production
    /// `SwiftDataAIRecommendationCache` overrides with a real upsert that
    /// dedupes on `promptInputHash`.
    func store(_ response: AIRecommendationResponse, for key: AICacheKey) async
}

extension AIRecommendationCache {
    /// Default no-op. Lets existing in-memory stubs satisfy the protocol
    /// without inventing storage; the resolver's write-back step becomes
    /// a harmless await on those caches.
    func store(_ response: AIRecommendationResponse, for key: AICacheKey) async {}
}
