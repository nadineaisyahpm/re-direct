import Foundation
import Observation

/// Single source of truth for the currently active redirect method.
///
/// Single-active-method rule:
/// - Timer is the **sole writer**. When the user toggles a method ON in
///   `MethodSelector`, the store's `activeRedirectMethodSlug` is set to that
///   method's slug. The most recently toggled-on method is "active".
/// - When the user toggles OFF the method that is currently active, the slug
///   is cleared to `nil`. Other methods that remain selected do not promote
///   to active automatically — the user must toggle one ON to re-anchor.
/// - re:tuals and `WhenTimerEndsCard` are **read-only** consumers. re:tuals
///   may use the slug to highlight or scroll-to the active lane; it must not
///   write back to this store.
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
