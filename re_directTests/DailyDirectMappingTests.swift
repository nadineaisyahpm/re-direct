import Testing
import Foundation
@testable import re_direct

// ─────────────────────────────────────────────
// MARK: - Fixtures
// ─────────────────────────────────────────────

private func makeResponse(
    topicSlug: String? = "bioluminescence",
    topicTitle: String = "Bioluminescence",
    promptBody: String = "Find one short documentary about the species you almost forgot existed.",
    suggestedMinutes: Int = 12
) -> AIRecommendationResponse {
    AIRecommendationResponse(
        id: "01TEST",
        topicSlug: topicSlug,
        topicTitle: topicTitle,
        promptBody: promptBody,
        suggestedMinutes: suggestedMinutes,
        provider: "deepseek",
        modelVersion: "deepseek-v4-flash",
        promptInputHash: "abc",
        cached: false,
        createdAt: Date()
    )
}

private func makeCacheHit(
    topicSlug: String? = "bioluminescence",
    topicTitle: String = "Bioluminescence",
    promptBody: String = "Cached body."
) -> AICacheHit {
    AICacheHit(
        promptInputHash: "h",
        topicSlug: topicSlug,
        topicTitle: topicTitle,
        promptBody: promptBody,
        suggestedMinutes: 8,
        provider: "deepseek",
        modelVersion: "deepseek-v4-flash",
        createdAt: Date()
    )
}

private func makeSeededTopic(id: Int = 1, title: String = "Seeded") -> ReDirectTopic {
    ReDirectTopic(
        id: id,
        title: title,
        subtitle: "Seeded subtitle",
        imageURL: "Seeded_Cover",
        colorHex: "#111111",
        barHeight: 0,
        barColorHex: "",
        articleCount: 0,
        videoCount: 0,
        totalTime: "",
        platformStats: []
    )
}

// ─────────────────────────────────────────────
// MARK: - Tests
// ─────────────────────────────────────────────

@Suite("DailyDirectMapping")
struct DailyDirectMappingTests {

    // MARK: AI response → ReDirectTopic

    @Test func adaptsResponseTitleAndBody() {
        let topic = DailyDirectMapping.adapt(response: makeResponse())
        #expect(topic.title == "Bioluminescence")
        // Short body passes through unchanged (under maxSubtitleChars).
        #expect(topic.subtitle == "Find one short documentary about the species you almost forgot existed.")
    }

    @Test func truncatesLongPromptBody() {
        let longBody = String(repeating: "abcde ", count: 30) // 180 chars
        let topic = DailyDirectMapping.adapt(response: makeResponse(promptBody: longBody))
        #expect(topic.subtitle.count <= DailyDirectMapping.maxSubtitleChars + 1) // +1 for ellipsis
        #expect(topic.subtitle.hasSuffix("…"))
    }

    @Test func usesMatchedSeedCoverAndAccentWhenSlugKnown() {
        let topic = DailyDirectMapping.adapt(
            response: makeResponse(topicSlug: "bioluminescence"),
            coverAssetByTopicSlug: { slug in
                slug == "bioluminescence" ? "TopicCover_Bioluminescence" : nil
            },
            accentHexByTopicSlug: { slug in
                slug == "bioluminescence" ? "#1B4D4A" : nil
            }
        )
        #expect(topic.imageURL == "TopicCover_Bioluminescence")
        #expect(topic.colorHex == "#1B4D4A")
    }

    @Test func fallsBackToNeutralWhenSlugMissing() {
        let topic = DailyDirectMapping.adapt(
            response: makeResponse(topicSlug: nil)
        )
        let neutral = ReDirectTopicData.topFive[0]
        #expect(topic.imageURL == neutral.imageURL)
        #expect(topic.colorHex == neutral.colorHex)
    }

    @Test func fallsBackToNeutralWhenSlugUnknown() {
        let topic = DailyDirectMapping.adapt(
            response: makeResponse(topicSlug: "unknown-slug"),
            coverAssetByTopicSlug: { _ in nil },
            accentHexByTopicSlug: { _ in nil }
        )
        let neutral = ReDirectTopicData.topFive[0]
        #expect(topic.imageURL == neutral.imageURL)
        #expect(topic.colorHex == neutral.colorHex)
    }

    @Test func rejectsMalformedAccentHex() {
        let topic = DailyDirectMapping.adapt(
            response: makeResponse(topicSlug: "x"),
            coverAssetByTopicSlug: { _ in "X_Cover" },
            accentHexByTopicSlug: { _ in "not-a-hex" }
        )
        // Cover accepted, hex rejected → neutral fallback for color.
        #expect(topic.imageURL == "X_Cover")
        #expect(topic.colorHex == ReDirectTopicData.topFive[0].colorHex)
    }

    @Test func adaptedResponseHasZeroedStatFields() {
        let topic = DailyDirectMapping.adapt(response: makeResponse())
        #expect(topic.barHeight == 0)
        #expect(topic.barColorHex == "")
        #expect(topic.articleCount == 0)
        #expect(topic.videoCount == 0)
        #expect(topic.totalTime == "")
        #expect(topic.platformStats.isEmpty)
    }

    // MARK: Cache hit → ReDirectTopic

    @Test func adaptsCacheHitSameAsResponse() {
        let topic = DailyDirectMapping.adapt(
            cacheHit: makeCacheHit(topicSlug: "bioluminescence", topicTitle: "Bioluminescence", promptBody: "Cached body."),
            coverAssetByTopicSlug: { _ in "TopicCover_Bioluminescence" },
            accentHexByTopicSlug: { _ in "#1B4D4A" }
        )
        #expect(topic.title == "Bioluminescence")
        #expect(topic.subtitle == "Cached body.")
        #expect(topic.imageURL == "TopicCover_Bioluminescence")
        #expect(topic.colorHex == "#1B4D4A")
    }

    // MARK: content source picker

    @Test func displayCardsPrefersAIOverride() {
        let ai = makeSeededTopic(id: 99, title: "AI")
        let seeded = [makeSeededTopic(id: 1), makeSeededTopic(id: 2)]
        let result = DailyDirectMapping.displayCards(aiOverride: ai, seeded: seeded)
        #expect(result.count == 1)
        #expect(result.first?.id == 99)
        #expect(result.first?.title == "AI")
    }

    @Test func displayCardsFallsBackToSeededWhenAINil() {
        let seeded = [makeSeededTopic(id: 1), makeSeededTopic(id: 2)]
        let result = DailyDirectMapping.displayCards(aiOverride: nil, seeded: seeded)
        #expect(result.count == 2)
        #expect(result.map(\.id) == [1, 2])
    }

    @Test func displayCardsKeepsSeededTwoCardLayout() {
        // The 6D-B acceptance criterion: seeded fallback must still show 2.
        let seeded = (1...2).map { makeSeededTopic(id: $0) }
        let result = DailyDirectMapping.displayCards(aiOverride: nil, seeded: seeded)
        #expect(result.count == 2)
    }

    @Test func displayCardsCapsAtMaxCardsToDisplay() {
        let seeded = (1...20).map { makeSeededTopic(id: $0) }
        let result = DailyDirectMapping.displayCards(aiOverride: nil, seeded: seeded)
        #expect(result.count == DailyDirectMapping.maxCardsToDisplay)
        // First N preserved.
        #expect(result.first?.id == 1)
        #expect(result.last?.id == DailyDirectMapping.maxCardsToDisplay)
    }

    @Test func displayCardsHandlesEmptySeeded() {
        let result = DailyDirectMapping.displayCards(aiOverride: nil, seeded: [])
        #expect(result.isEmpty)
    }

    // MARK: trimToWords

    @Test func trimToWordsLeavesShortStringAlone() {
        #expect(DailyDirectMapping.trimToWords("short", max: 100) == "short")
    }

    @Test func trimToWordsBreaksOnLastSpaceWithEllipsis() {
        // 11 chars, max 7 → "hello" + "…"
        let result = DailyDirectMapping.trimToWords("hello world wide web", max: 7)
        #expect(result.hasSuffix("…"))
        #expect(result.count <= 8)
    }

    @Test func trimToWordsHardCutsWhenNoSpace() {
        let result = DailyDirectMapping.trimToWords("supercalifragilistic", max: 5)
        #expect(result == "super…")
    }
}
