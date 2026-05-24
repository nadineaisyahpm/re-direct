import Foundation

struct SeededCuriosityPrompt: Equatable, Sendable {
    let topicSlug: String
    let topicTitle: String
    let promptBody: String
    let suggestedMinutes: Int
}

protocol SeededPromptProvider: Sendable {
    func pickPrompt(matching interests: [String], excluding shownSlugs: Set<String>) async -> SeededCuriosityPrompt?
    func anyPrompt() async -> SeededCuriosityPrompt?
}

enum AIRecommendationSource: Equatable, Sendable {
    case localCache(AICacheHit)
    case proxy(AIRecommendationResponse)
    case seedFallback(SeededCuriosityPrompt, reason: FallbackReason)

    enum FallbackReason: String, Sendable {
        case offline
        case proxyError
        case rateLimited
        case validationFailedLocally
    }
}

struct AIRecommendationResolver: Sendable {
    let cache: AIRecommendationCache
    let seed: SeededPromptProvider

    func resolve(
        request: AIRecommendationRequest,
        callProxy: @Sendable (AIRecommendationRequest) async throws -> AIRecommendationResponse
    ) async -> AIRecommendationSource {

        if let hit = await cache.lookup(AICacheKey(request: request)) {
            return .localCache(hit)
        }

        if let validationError = AIRequestValidator.validate(request) {
            _ = validationError
            if let seeded = await seed.pickPrompt(matching: request.interests, excluding: []) {
                return .seedFallback(seeded, reason: .validationFailedLocally)
            }
            if let any = await seed.anyPrompt() {
                return .seedFallback(any, reason: .validationFailedLocally)
            }
        }

        do {
            let response = try await callProxy(request)
            // Write-back: persist the fresh response so the next resolve()
            // (this session or a future cold launch, depending on the
            // cache's durability) can hit cache without calling the proxy.
            // Read-only cache stubs get the default no-op from the
            // `AIRecommendationCache` protocol extension and skip this.
            await cache.store(response, for: AICacheKey(request: request))
            return .proxy(response)
        } catch let error as AIProxyError where error.triggersSeededFallback {
            let reason: AIRecommendationSource.FallbackReason
            switch error {
            case .rateLimited: reason = .rateLimited
            case .network: reason = .offline
            default: reason = .proxyError
            }
            if let seeded = await seed.pickPrompt(matching: request.interests, excluding: []) {
                return .seedFallback(seeded, reason: reason)
            }
            if let any = await seed.anyPrompt() {
                return .seedFallback(any, reason: reason)
            }
            return .seedFallback(
                SeededCuriosityPrompt(
                    topicSlug: "default",
                    topicTitle: "Take a breath",
                    promptBody: "Step away from the screen for a few minutes. Notice one thing around you.",
                    suggestedMinutes: 5
                ),
                reason: reason
            )
        } catch {
            if let any = await seed.anyPrompt() {
                return .seedFallback(any, reason: .proxyError)
            }
            return .seedFallback(
                SeededCuriosityPrompt(
                    topicSlug: "default",
                    topicTitle: "Take a breath",
                    promptBody: "Step away from the screen for a few minutes. Notice one thing around you.",
                    suggestedMinutes: 5
                ),
                reason: .proxyError
            )
        }
    }
}
