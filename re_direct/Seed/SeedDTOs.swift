import Foundation

struct CuriositySeedDTO: Decodable, Sendable {
    let seedVersion: Int
    let generatedAt: Date
    let locale: String
    let topics: [TopicDTO]
    let trails: [TrailDTO]?
    let reminderThemes: [ReminderThemeDTO]
    let redirectMethods: [RedirectMethodDTO]

    enum CodingKeys: String, CodingKey {
        case seedVersion = "seed_version"
        case generatedAt = "generated_at"
        case locale
        case topics
        case trails
        case reminderThemes = "reminder_themes"
        case redirectMethods = "redirect_methods"
    }
}

struct TopicDTO: Decodable, Sendable {
    let slug: String
    let title: String
    let summary: String
    let coverAssetName: String
    let accentColorHex: String
    let prompts: [PromptDTO]

    enum CodingKeys: String, CodingKey {
        case slug
        case title
        case summary
        case coverAssetName = "cover_asset_name"
        case accentColorHex = "accent_color_hex"
        case prompts
    }
}

struct PromptDTO: Decodable, Sendable {
    let slug: String
    let body: String
    let source: String
    let tier: String?
    let estimatedMinutes: Int

    enum CodingKeys: String, CodingKey {
        case slug
        case body
        case source
        case tier
        case estimatedMinutes = "estimated_minutes"
    }
}

struct TrailDTO: Decodable, Sendable {
    let slug: String
    let topicSlug: String
    let title: String
    let summary: String
    let steps: [TrailStepDTO]

    enum CodingKeys: String, CodingKey {
        case slug
        case topicSlug = "topic_slug"
        case title
        case summary
        case steps
    }
}

struct TrailStepDTO: Decodable, Sendable {
    let stepOrder: Int
    let promptSlug: String
    let estimatedMinutes: Int

    enum CodingKeys: String, CodingKey {
        case stepOrder = "step_order"
        case promptSlug = "prompt_slug"
        case estimatedMinutes = "estimated_minutes"
    }
}

struct ReminderThemeDTO: Decodable, Sendable {
    let slug: String
    let displayName: String
    let assetName: String

    enum CodingKeys: String, CodingKey {
        case slug
        case displayName = "display_name"
        case assetName = "asset_name"
    }
}

struct RedirectMethodDTO: Decodable, Sendable {
    let slug: String
    let displayName: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case slug
        case displayName = "display_name"
        case summary
    }
}
