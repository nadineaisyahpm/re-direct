import Testing
@testable import re_direct

@Suite("AICacheKey.localFingerprint")
struct AICacheKeyFingerprintTests {

    @Test func sameInputsProduceSameFingerprint() {
        let request = AIRecommendationRequest(
            interests: ["bioluminescence", "cartography"],
            mood: "restless",
            timeAvailableMinutes: 15,
            providerPreference: .auto,
            locale: "en-US"
        )
        let a = AICacheKey(request: request).localFingerprint
        let b = AICacheKey(request: request).localFingerprint
        #expect(a == b)
        #expect(a.count == 64)
    }

    @Test func interestOrderDoesNotChangeFingerprint() {
        let r1 = AIRecommendationRequest(interests: ["alpha", "beta"], timeAvailableMinutes: 10, locale: "en-US")
        let r2 = AIRecommendationRequest(interests: ["beta", "alpha"], timeAvailableMinutes: 10, locale: "en-US")
        #expect(AICacheKey(request: r1).localFingerprint == AICacheKey(request: r2).localFingerprint)
    }

    @Test func interestCaseDoesNotChangeFingerprint() {
        let r1 = AIRecommendationRequest(interests: ["BioLuminescence"], timeAvailableMinutes: 10, locale: "en-US")
        let r2 = AIRecommendationRequest(interests: ["bioluminescence"], timeAvailableMinutes: 10, locale: "en-US")
        #expect(AICacheKey(request: r1).localFingerprint == AICacheKey(request: r2).localFingerprint)
    }

    @Test func moodChangesFingerprint() {
        let r1 = AIRecommendationRequest(interests: ["alpha"], mood: nil, timeAvailableMinutes: 10, locale: "en-US")
        let r2 = AIRecommendationRequest(interests: ["alpha"], mood: "restless", timeAvailableMinutes: 10, locale: "en-US")
        #expect(AICacheKey(request: r1).localFingerprint != AICacheKey(request: r2).localFingerprint)
    }

    @Test func timeChangesFingerprint() {
        let r1 = AIRecommendationRequest(interests: ["alpha"], timeAvailableMinutes: 10, locale: "en-US")
        let r2 = AIRecommendationRequest(interests: ["alpha"], timeAvailableMinutes: 30, locale: "en-US")
        #expect(AICacheKey(request: r1).localFingerprint != AICacheKey(request: r2).localFingerprint)
    }

    @Test func localeChangesFingerprint() {
        let r1 = AIRecommendationRequest(interests: ["alpha"], timeAvailableMinutes: 10, locale: "en-US")
        let r2 = AIRecommendationRequest(interests: ["alpha"], timeAvailableMinutes: 10, locale: "ja-JP")
        #expect(AICacheKey(request: r1).localFingerprint != AICacheKey(request: r2).localFingerprint)
    }
}
