import Foundation

/// Per-app-session memo for the Dashboard's Daily Direct AI call.
///
/// Why this exists: `DashboardView.DailyDirectSection`'s `.task` modifier
/// re-fires every time the view re-enters identity (e.g. tab switching
/// can tear down and re-create the section view, resetting its `@State`).
/// Without an out-of-view memo, that would mean a fresh network call
/// every time the user comes back to the Dashboard tab.
///
/// This store guarantees **one proxy attempt per app launch**:
/// - First Dashboard appearance: `aiCard == nil`, `hasAttempted == false`
///   → the section calls the loader, sets `hasAttempted = true`, and on
///   success stores the resulting card.
/// - Subsequent appearances:
///   - If `aiCard` is populated, the section reads it back (no network).
///   - If `aiCard` is nil but `hasAttempted == true`, the previous call
///     failed; the section does NOT retry, leaving the seeded display in
///     place. The next cold launch gets a fresh attempt.
///
/// Cache write-back on successful proxy responses is intentionally NOT
/// wired in this slice — `AIRecommendationResolver` reads the cache but
/// nothing persists proxy responses to it yet. That's a deferred follow-up
/// (see `docs/AI_INTEGRATION_PLAN.md` §3 — the existing
/// `SwiftDataAIRecommendationCache` covers the read side only).
@MainActor
final class DailyDirectSessionStore {

    /// Production singleton. Tests should instantiate a fresh
    /// `DailyDirectSessionStore()` for isolation rather than mutating
    /// `.shared`.
    static let shared = DailyDirectSessionStore()

    /// The AI-derived card if one was successfully loaded during this app
    /// session. `nil` means either "no successful attempt yet" or "we
    /// tried and got a fallback."
    var aiCard: ReDirectTopic?

    /// `true` once the Dashboard has issued one proxy attempt this app
    /// session (regardless of outcome). The session-scoped throttle gate.
    var hasAttempted: Bool = false

    /// Designated initializer is exposed (not `private`) so tests can
    /// instantiate fresh stores without colliding with `.shared`.
    init() {}
}
