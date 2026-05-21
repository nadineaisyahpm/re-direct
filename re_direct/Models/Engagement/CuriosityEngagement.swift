import Foundation
import SwiftData

/// A curiosity engagement is a "rabbit hole" — a moment when the user actually
/// engaged with content (read, watched, completed a prompt, walked a trail step).
/// It is distinct from `TimerSession` (boundary commitment) and `ReflectionEntry`
/// (post-session reflection). See docs/SLICE_E1_ENGAGEMENT.md for the full rationale.
@Model
final class CuriosityEngagement {
    @Attribute(.unique) var id: UUID = UUID()

    /// Joins to `RedirectMethod.slug` — canonical taxonomy ("watch", "read",
    /// "mini-game", "reflect", "deep-dive"). Permissive at the model layer;
    /// the creation surface (future Slice E3) enforces the canonical set.
    var methodSlug: String = ""

    /// What the user engaged with. Free-form so user-supplied content (an
    /// article they found themselves) can be logged without a seeded link.
    /// The creation surface enforces non-empty before insert; the model
    /// default is intentionally empty so SwiftData defaulting works.
    var contentTitle: String = ""

    /// Optional pointer to the source. Stored as String (not URL) so a
    /// user-typed value that may be malformed doesn't crash decode. Local-only.
    var sourceURL: String? = nil

    /// When the engagement happened. Almost always `.now` at creation;
    /// settable so future backfill ("I read this yesterday") is possible.
    var engagedAt: Date = Date()

    /// Optional self-reported duration. Nullable on purpose — most engagements
    /// won't have measured duration, and defaulting to 0 would pollute analytics.
    var durationSeconds: Int? = nil

    /// Optional one-line user note. Stays local. Not a reflection.
    var note: String? = nil

    /// Soft delete, consistent with the rest of the user-owned schema.
    var deletedAt: Date? = nil

    /// Optional link to a seeded curiosity topic.
    var topic: CuriosityTopic? = nil

    /// Optional link to a seeded curiosity prompt.
    var prompt: CuriosityPrompt? = nil

    /// Optional link to the timer session this engagement occurred during.
    /// Not required — engagement can happen without a timer running.
    var session: TimerSession? = nil

    /// Optional link to a `ReflectionEntry` written about this engagement.
    /// For the Reflect-method ritual, this is set on the same save that
    /// creates the engagement (the writing *is* the engagement). For post-
    /// ritual reflection (REF3), it will be set on an existing engagement
    /// after the fact. See docs/REFLECTION_ARCHITECTURE.md §3.
    var reflection: ReflectionEntry? = nil

    init() {}
}
