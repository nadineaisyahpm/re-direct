import Foundation

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

protocol AIRecommendationCache: Sendable {
    func lookup(_ key: AICacheKey) async -> AICacheHit?
    func recentPromptInputHashes(limit: Int) async -> [String]
}
