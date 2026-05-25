import Foundation
import SwiftData

/// A rabbit hole thread groups a sequence of `CuriosityEngagement` rows the user
/// (or AI) treats as one continuous curiosity arc. See `docs/RABBIT_HOLE_THREADS.md`.
///
/// Key invariants from RH0 (load-bearing):
/// - Topic-centric, not method-centric. A thread can contain engagements across
///   any of the five `RedirectMethod` slugs. No `methodSlug` field lives here.
/// - Threading is optional. Engagements may have `thread == nil` and remain valid.
/// - Boundary-agnostic. Threads carry no link to `TimerSession`.
/// - Reflection bodies never live on a thread. Reflections are reached only via
///   an engagement's `reflection` link.
/// - Local-only. No thread metadata is included in any outbound AI payload.
///
/// RH1 is the conservative storage shape. Ordering of engagements inside a thread,
/// a user-facing creation surface, and the Phase 6E → thread bridge land in
/// later slices (RH2, RH3) per `docs/RABBIT_HOLE_THREADS.md §11`.
@Model
final class RabbitHoleThread {
    @Attribute(.unique) var id: UUID = UUID()

    /// Short editorial title. User- or AI-supplied. Non-empty enforced by the
    /// future creation surface; default empty so SwiftData defaulting works.
    var title: String = ""

    /// Optional one-paragraph "what this thread is about." Stays local.
    var summary: String? = nil

    /// Raw status string. See `ThreadStatus` for the canonical set
    /// (`open` / `resting` / `closed`). Stored as raw string for forward
    /// compatibility — unknown values surface as `.unknown` rather than crash,
    /// matching the permissive style of `CuriosityEngagement.methodSlug`.
    var statusRaw: String = ThreadStatus.open.rawValue

    /// Raw source-kind string. See `ThreadSourceKind`
    /// (`manual` / `ai-deepened` / `auto-grouped`).
    var sourceRaw: String = ThreadSourceKind.manual.rawValue

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Mirrors the max `engagedAt` across the thread's engagements. Cached on
    /// the thread so sort/queries don't have to traverse the relationship.
    /// Nil when the thread has no engagements yet.
    var lastEngagedAt: Date? = nil

    /// Soft delete, consistent with the rest of the user-owned schema. Deleting
    /// a thread does not delete its engagements (RH0 §4); they become unthreaded.
    var deletedAt: Date? = nil

    /// Engagements that belong to this thread, in no enforced order at the
    /// storage layer. Ordering UX (and any `orderIndex` field) lands in RH2.
    /// Until then, callers should sort by `engagedAt` for display.
    @Relationship(deleteRule: .nullify, inverse: \CuriosityEngagement.thread)
    var engagements: [CuriosityEngagement] = []

    init() {}
}

/// Canonical thread lifecycle states. Wrappers are permissive: unknown raw
/// values from a future schema version decode as `.unknown` rather than crash.
enum ThreadStatus: String, CaseIterable, Sendable {
    case open
    case resting
    case closed

    /// Sentinel for forward-compatible decoding of raw strings.
    case unknown

    static func from(raw: String) -> ThreadStatus {
        ThreadStatus(rawValue: raw) ?? .unknown
    }
}

/// How the thread came into existence. RH1 only writes `.manual` from tests;
/// `.aiDeepened` arrives with the Phase 6E ↔ thread bridge (RH3);
/// `.autoGrouped` is reserved for an explicitly approved later slice (RH6).
enum ThreadSourceKind: String, CaseIterable, Sendable {
    case manual
    case aiDeepened = "ai-deepened"
    case autoGrouped = "auto-grouped"

    case unknown

    static func from(raw: String) -> ThreadSourceKind {
        ThreadSourceKind(rawValue: raw) ?? .unknown
    }
}

extension RabbitHoleThread {
    /// Permissive accessor — never crashes on an unknown raw value.
    var status: ThreadStatus { ThreadStatus.from(raw: statusRaw) }

    /// Permissive accessor — never crashes on an unknown raw value.
    var source: ThreadSourceKind { ThreadSourceKind.from(raw: sourceRaw) }
}
