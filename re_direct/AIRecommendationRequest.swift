import Foundation

/// AI proxy recommendation request.
///
/// **Reference type, not a struct.** This used to be a struct + Sendable
/// value type. On physical devices the struct's bytes were being corrupted
/// when crossing the `try await callProxy(request)` boundary between
/// `AIRecommendationResolver` and the proxy client closure — the
/// stack-allocated struct's storage was being reused before the receiving
/// side finished reading from it, causing the `mood: nil` Optional's
/// discriminator bit to read as `.some` with a garbage payload, which
/// `swift_retain` then dereferenced through (EXC_BAD_ACCESS at 0x8 inside
/// `outlined init with copy of String?`).
///
/// A `final class` with all-`let` properties has stable heap-allocated
/// storage. Closures capture a pointer (retained); the bytes survive
/// however many async hops the call path takes. Value-like read-only
/// semantics are preserved by immutability (no setters).
///
/// All properties are immutable, so the class is safely `Sendable`
/// (Swift will accept `Sendable` for a final class whose stored properties
/// are all `let` and themselves `Sendable`; we use `@unchecked` here only
/// to avoid the compiler also requiring an explicit conformance dance
/// across Swift versions).
final class AIRecommendationRequest: Codable, Equatable, @unchecked Sendable {
    let interests: [String]
    let mood: String?
    let timeAvailableMinutes: Int
    let excludePromptHashes: [String]
    let providerPreference: AIProviderPreference
    let locale: String

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
        locale: String = AIRecommendationRequest.bcp47Locale()
    ) {
        self.interests = interests
        self.mood = mood
        self.timeAvailableMinutes = timeAvailableMinutes
        self.excludePromptHashes = excludePromptHashes
        self.providerPreference = providerPreference
        self.locale = locale
    }

    // Equatable — manual implementation since classes don't synthesize.
    // Compares by value (field-by-field), not by identity. Existing call
    // sites that relied on the struct's synthesized `==` keep working.
    /// Returns the current locale in BCP-47 hyphen format (`en-US`) required
    /// by the proxy schema (`^[a-z]{2}(-[A-Z]{2})?$`).
    /// `Locale.current.identifier` uses Apple's underscore format (`en_US`)
    /// which the proxy rejects with a 400. Strips script subtags so
    /// e.g. `zh_Hans_CN` → `zh-CN`.
    static func bcp47Locale(from locale: Locale = .current) -> String {
        let components = locale.identifier
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: "-")
        guard let language = components.first, language.count == 2 else {
            return components.first.map { String($0.prefix(2)).lowercased() } ?? "en"
        }
        if let region = components.dropFirst().first(where: { $0.count == 2 }) {
            return "\(language.lowercased())-\(region.uppercased())"
        }
        return language.lowercased()
    }

    static func == (lhs: AIRecommendationRequest, rhs: AIRecommendationRequest) -> Bool {
        lhs.interests == rhs.interests
            && lhs.mood == rhs.mood
            && lhs.timeAvailableMinutes == rhs.timeAvailableMinutes
            && lhs.excludePromptHashes == rhs.excludePromptHashes
            && lhs.providerPreference == rhs.providerPreference
            && lhs.locale == rhs.locale
    }
}
