import Foundation
import Observation

/// Single source of truth for the currently active redirect method.
///
/// Write paths (two, as of RH2-A/B):
/// 1. **Timer** — `MethodSelector` sets the slug when the user toggles a
///    method ON. The most recently toggled-on method is "active". Toggling
///    OFF the currently active method clears the slug to `nil`; other
///    selected methods do not auto-promote.
/// 2. **re:tuals active-method selection panel** — the panel CTA below the
///    card deck sets the slug to the currently visible lane's slug. This
///    is an intentional write path added in RH2-A/B; it replaces the old
///    prototype "choose this" card CTA. re:tuals cards and back-face rows
///    remain **read-only**; only the panel CTA may write.
///
/// Read-only consumers: `WhenTimerEndsCard`, `DeckPagination` (accent dot).
///
/// Storage:
/// - In-memory only for v1. The slug resets on cold launch. Persistence is
///   intentionally deferred until there's a real driver (e.g. resume-session
///   continuity); revisit when Timer gains a tick / completion loop.
@Observable
final class ActiveMethodStore {
    var activeRedirectMethodSlug: String? = nil

    init(activeRedirectMethodSlug: String? = nil) {
        self.activeRedirectMethodSlug = activeRedirectMethodSlug
    }
}
