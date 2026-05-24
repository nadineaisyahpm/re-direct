import Foundation

/// A no-op `SeededPromptProvider` for the production Dashboard wiring.
///
/// `AIRecommendationResolver` requires a seed provider so it can fall back
/// when the proxy fails. The Dashboard, however, owns its own seeded
/// `DailyCard` list (via `@Query<CuriosityTopic>`) and treats a
/// `.seedFallback` from the resolver as "no AI override" — so the
/// resolver's seed result is unused at this surface.
///
/// Returning nil from both methods is safe: the resolver's hardcoded
/// last-resort default catches the empty case and emits a `.seedFallback`
/// the Dashboard then ignores. A later slice can swap this for a real
/// SwiftData-backed seed provider when other surfaces need one.
struct NoopSeededPromptProvider: SeededPromptProvider {
    func pickPrompt(matching interests: [String], excluding shownSlugs: Set<String>) async -> SeededCuriosityPrompt? {
        nil
    }
    func anyPrompt() async -> SeededCuriosityPrompt? {
        nil
    }
}
