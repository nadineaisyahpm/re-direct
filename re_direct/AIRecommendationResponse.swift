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
        // The proxy emits toISOString() which includes fractional seconds
        // (e.g. "2026-05-29T17:14:23.901Z"). Swift's built-in .iso8601
        // strategy omits .withFractionalSeconds, so dates fail to decode.
        // Use a custom strategy that tries fractional first, then plain.
        let withFrac: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        let plain = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let d = withFrac.date(from: s) { return d }
            if let d = plain.date(from: s) { return d }
            throw DecodingError.dataCorrupted(
                .init(codingPath: dec.codingPath, debugDescription: "Cannot parse date: \(s)")
            )
        }
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
