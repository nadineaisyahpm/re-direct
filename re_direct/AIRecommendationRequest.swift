import Foundation

struct AIRecommendationRequest: Codable, Equatable, Sendable {
    var interests: [String]
    var mood: String?
    var timeAvailableMinutes: Int
    var excludePromptHashes: [String]
    var providerPreference: AIProviderPreference
    var locale: String

    enum CodingKeys: String, CodingKey {
        case interests
        case mood
        case timeAvailableMinutes = "time_available_minutes"
        case excludePromptHashes = "exclude_prompt_hashes"
        case providerPreference = "provider_preference"
        case locale
    }

    init(
        interests: [String],
        mood: String? = nil,
        timeAvailableMinutes: Int,
        excludePromptHashes: [String] = [],
        providerPreference: AIProviderPreference = .auto,
        locale: String = Locale.current.identifier
    ) {
        self.interests = interests
        self.mood = mood
        self.timeAvailableMinutes = timeAvailableMinutes
        self.excludePromptHashes = excludePromptHashes
        self.providerPreference = providerPreference
        self.locale = locale
    }
}
