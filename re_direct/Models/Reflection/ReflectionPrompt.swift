import Foundation
import SwiftData

/// A seeded or AI-generated reflection question shown to the user inside the
/// reflection writing surfaces. See `docs/REFLECTION_ARCHITECTURE.md` §4 for
/// the field rationale and §7 for the slice sequence that consumes these rows.
///
/// `ReflectionPrompt` is the *question*. `ReflectionEntry` is the user's
/// *answer*. Prompts are content; entries are sensitive user data and never
/// leave the device.
@Model
final class ReflectionPrompt {
    @Attribute(.unique) var id: UUID = UUID()

    /// Stable identifier. Seed prompts use slugs like "noticed-something-small";
    /// AI-runtime prompts use uuid-based slugs so they don't collide.
    @Attribute(.unique) var slug: String = ""

    /// The reflection question, shown verbatim to the user.
    var body: String = ""

    /// Optional editorial tone tag ("gentle", "curious", "honest", "tender").
    /// Permissive at the model layer; UI surfaces may filter by tone later.
    var tone: String? = nil

    /// Rough time budget in minutes — typically 1 to 5.
    var estimatedMinutes: Int = 2

    /// Provenance. "seed" for bundled prompts; "ai-runtime" for prompts
    /// generated via the AI proxy in REF5. Anything else is permissive at
    /// the model layer; the importer enforces the canonical set on insert.
    var source: String = "seed"

    /// Optional mood tags this prompt fits ("restless", "tired", "curious"...).
    var moodAffinity: [String] = []

    /// Which flow this prompt is meant for:
    ///   "reflect-method"  — used when the user picks Reflect as the ritual
    ///   "post-ritual"     — used after Watch/Read/Mini-Game/Deep-Dive ends
    ///   nil               — usable in either flow
    /// The writing surfaces filter by context but fall back to untagged
    /// prompts if a context-specific pool is empty.
    var context: String? = nil

    /// Soft delete. Consistent with the rest of the user-owned schema and
    /// gives users the ability to dismiss a prompt forever without losing
    /// engagement history.
    var deletedAt: Date? = nil

    /// When this row first entered the local store.
    var createdAt: Date = Date()

    init() {}
}
