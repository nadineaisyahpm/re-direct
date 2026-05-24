import Foundation

/// Pure mapping helpers that turn AI proxy / cache results into the
/// existing `ReDirectTopic` shape used by the Dashboard's `DailyCard`.
/// Lifted out of `DashboardView` so the conversion can be unit-tested
/// without instantiating SwiftUI views.
///
/// Phase 6D-B does not change the proxy contract or the card visual. The
/// helper just fills the same fields the existing seed-→-topic adapter
/// fills, using the AI response's `topic_title` / `prompt_body` /
/// `topic_slug`. When the AI returns a slug that matches a seeded topic
/// on-device, the seed's cover and accent are reused; otherwise a neutral
/// default from `ReDirectTopicData` keeps the card visually consistent.
enum DailyDirectMapping {

    /// Display caps. Bodies past `maxSubtitleChars` are trimmed at the
    /// last whitespace and suffixed with an ellipsis — same approach as
    /// `DailyDirectSection.trimToWords(_:max:)` so the AI card matches
    /// the seeded layout exactly.
    static let maxSubtitleChars = 100

    /// Soft ceiling on cards in the carousel. Defensive — today's
    /// content sources stay well under this, but the cap protects the
    /// scroll-target geometry from a runaway upstream payload.
    static let maxCardsToDisplay = 10

    /// Hex pattern accepted by `DailyDirectSection`'s seed adapter.
    static let hexPattern = #"^#[0-9A-Fa-f]{6}$"#

    // ─────────────────────────────────────────
    // MARK: AI response → ReDirectTopic
    // ─────────────────────────────────────────

    /// Map a `AIRecommendationResponse` to the existing card shape.
    ///
    /// - parameter coverAssetByTopicSlug: closure that returns a bundled
    ///   asset name for a known seed slug, or nil. Dashboard supplies a
    ///   live lookup from `@Query`'d `CuriosityTopic` rows; tests pass a
    ///   fixed map.
    /// - parameter accentHexByTopicSlug: same idea for accent color.
    static func adapt(
        response: AIRecommendationResponse,
        coverAssetByTopicSlug: (String) -> String? = { _ in nil },
        accentHexByTopicSlug: (String) -> String? = { _ in nil }
    ) -> ReDirectTopic {
        adaptCommon(
            title: response.topicTitle,
            body: response.promptBody,
            topicSlug: response.topicSlug,
            coverAssetByTopicSlug: coverAssetByTopicSlug,
            accentHexByTopicSlug: accentHexByTopicSlug
        )
    }

    // ─────────────────────────────────────────
    // MARK: Cache hit → ReDirectTopic
    // ─────────────────────────────────────────

    /// `AICacheHit` is what the resolver returns when the local cache has
    /// a previously-stored proxy response. Same display shape as a fresh
    /// proxy response.
    static func adapt(
        cacheHit: AICacheHit,
        coverAssetByTopicSlug: (String) -> String? = { _ in nil },
        accentHexByTopicSlug: (String) -> String? = { _ in nil }
    ) -> ReDirectTopic {
        adaptCommon(
            title: cacheHit.topicTitle,
            body: cacheHit.promptBody,
            topicSlug: cacheHit.topicSlug,
            coverAssetByTopicSlug: coverAssetByTopicSlug,
            accentHexByTopicSlug: accentHexByTopicSlug
        )
    }

    // ─────────────────────────────────────────
    // MARK: Content source
    // ─────────────────────────────────────────

    /// Pick the displayed card list given the optional AI override and the
    /// existing seeded list. AI override wins; otherwise the seeded list is
    /// used. The result is capped at `maxCardsToDisplay`.
    ///
    /// Note: when an AI card is present the seeded list is replaced (one
    /// card), matching the 6D-B requirement that AI success renders 1 card
    /// while seeded fallback continues to render the seeded N.
    static func displayCards(
        aiOverride: ReDirectTopic?,
        seeded: [ReDirectTopic]
    ) -> [ReDirectTopic] {
        let chosen: [ReDirectTopic] = aiOverride.map { [$0] } ?? seeded
        if chosen.count <= maxCardsToDisplay { return chosen }
        return Array(chosen.prefix(maxCardsToDisplay))
    }

    // ─────────────────────────────────────────
    // MARK: Pure helpers
    // ─────────────────────────────────────────

    /// Word-boundary trim with ellipsis. Mirrors the existing seed adapter.
    static func trimToWords(_ s: String, max limit: Int) -> String {
        if s.count <= limit { return s }
        let prefix = String(s.prefix(limit))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "…"
        }
        return prefix + "…"
    }

    // ─────────────────────────────────────────
    // MARK: Private
    // ─────────────────────────────────────────

    private static func adaptCommon(
        title: String,
        body: String,
        topicSlug: String?,
        coverAssetByTopicSlug: (String) -> String?,
        accentHexByTopicSlug: (String) -> String?
    ) -> ReDirectTopic {
        let fallback = ReDirectTopicData.topFive[0]

        let cover: String = {
            if let slug = topicSlug, let asset = coverAssetByTopicSlug(slug), !asset.isEmpty {
                return asset
            }
            return fallback.imageURL
        }()

        let color: String = {
            if let slug = topicSlug,
               let hex = accentHexByTopicSlug(slug),
               hex.range(of: hexPattern, options: .regularExpression) != nil {
                return hex
            }
            return fallback.colorHex
        }()

        return ReDirectTopic(
            id: 0,
            title: title,
            subtitle: trimToWords(body, max: maxSubtitleChars),
            imageURL: cover,
            colorHex: color,
            barHeight: 0,
            barColorHex: "",
            articleCount: 0,
            videoCount: 0,
            totalTime: "",
            platformStats: []
        )
    }
}
