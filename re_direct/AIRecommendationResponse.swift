import Foundation

struct AIRecommendationResponse: Codable, Equatable, Sendable {
    let id: String
    let topicSlug: String?
    let topicTitle: String
    let promptBody: String
    let suggestedMinutes: Int
    let provider: String
    let modelVersion: String
    let promptInputHash: String
    let cached: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case topicSlug = "topic_slug"
        case topicTitle = "topic_title"
        case promptBody = "prompt_body"
        case suggestedMinutes = "suggested_minutes"
        case provider
        case modelVersion = "model_version"
        case promptInputHash = "prompt_input_hash"
        case cached
        case createdAt = "created_at"
    }
}

extension JSONDecoder {
    static var aiProxy: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var aiProxy: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
