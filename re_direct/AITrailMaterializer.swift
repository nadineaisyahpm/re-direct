import Foundation
import SwiftData

/// Pure side-effect helper for Phase 6E-D1. Materializes an accepted
/// `AITrailResponse` + root `CuriosityEngagement` into a new
/// `RabbitHoleThread` + N step `CuriosityEngagement` rows, per
/// `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §6`.
///
/// Lifted out of the future TrailSheet view so:
/// 1. Tests can verify the exact write shape without mounting any UI.
/// 2. The accept flow stays a one-liner in 6E-D2 (UI slice).
/// 3. The persistence bridge (`RABBIT_HOLE_THREADS.md §6` + the trails
///    plan §6) lives in one auditable place.
///
/// Invariants enforced here:
/// - **One thread per accept**, `sourceKind = .aiDeepened`, `status = .open`.
/// - **Steps whose `type` doesn't map** to a canonical method slug are
///   dropped, never coerced (per `RABBIT_HOLE_THREADS.md §6` step 4 and
///   the trails-plan §2 mapping table).
/// - **If no steps survive filtering**, no thread is created and `nil`
///   is returned — defensive guard against malformed AI responses.
/// - **Root engagement handling**: Branch A when unthreaded (attach as
///   first engagement), Branch B when already threaded (carry the
///   root's `topic`/`prompt` onto `seedTopic`/`seedPrompt` of the new
///   thread; root stays where it is).
/// - **Reflection bodies are never referenced** in this helper. The
///   trail step's `rationale` is editorial AI text (it never came from
///   the user's reflection storage) and is safe to persist as the
///   engagement's `note`. Tests assert that even when a root engagement
///   has a linked `ReflectionEntry` with body, the body never appears
///   anywhere in the materialized thread or its engagements.
///
/// Caller context: this helper performs SwiftData writes and assumes a
/// MainActor `ModelContext` (matching the existing `NewThreadInserter`
/// and `EngagementThreadAttacher` pattern). It is not annotated
/// `@MainActor` itself — callers are responsible for the isolation.
enum AITrailMaterializer {

    /// Materializes the trail. Returns the new thread on success, `nil`
    /// when the response yields zero valid steps after type filtering.
    @discardableResult
    static func materialize(
        response: AITrailResponse,
        root rootEngagement: CuriosityEngagement?,
        into context: ModelContext,
        now: Date = Date()
    ) -> RabbitHoleThread? {
        // 1. Filter steps to those whose type maps to a canonical
        //    method slug. Dropped, not coerced.
        let validSteps: [(step: AITrailStep, methodSlug: String)] =
            response.steps.compactMap { step in
                guard let slug = methodSlug(forStepType: step.type) else { return nil }
                return (step, slug)
            }

        // 2. Defensive guard: no valid steps → no thread.
        //    Caller (the sheet) treats nil as "nothing to materialize."
        guard !validSteps.isEmpty else { return nil }

        // 3. Build the thread.
        let thread = RabbitHoleThread()
        thread.title = sanitizedTitle(
            response.title,
            fallback: rootEngagement?.contentTitle
        )
        thread.summary = NewThreadInputValidator.sanitizedSummary(response.summary ?? "")
        thread.statusRaw = ThreadStatus.open.rawValue
        thread.sourceRaw = ThreadSourceKind.aiDeepened.rawValue
        thread.createdAt = now
        thread.updatedAt = now
        thread.lastEngagedAt = now
        thread.deletedAt = nil

        // 4. Root-engagement handling — Branch A vs Branch B from
        //    AI_RABBIT_HOLE_TRAILS_PLAN.md §6.
        if let rootEngagement {
            if rootEngagement.thread == nil {
                // Branch A: attach root as the first engagement of the
                // new thread. Trail step engagements become 2..N+1.
                // The root's existing engagedAt is preserved; we do
                // not overwrite it with `now`.
                rootEngagement.thread = thread
            } else {
                // Branch B: race protection — root was attached to
                // another thread between trigger and accept. Don't
                // move it. Carry its seed metadata onto the new thread
                // so the trail keeps a discoverable link back.
                thread.seedTopic = rootEngagement.topic
                thread.seedPrompt = rootEngagement.prompt
            }
        }

        // 5. Insert the thread before its engagements so the inverse
        //    relationship resolves cleanly.
        context.insert(thread)

        // 6. Create N engagement rows in trail order, one per valid step.
        for (step, slug) in validSteps {
            let engagement = CuriosityEngagement()
            engagement.methodSlug = slug
            engagement.contentTitle = step.title
            engagement.sourceURL = step.url
            engagement.note = step.rationale     // editorial AI text — NOT a reflection body
            engagement.engagedAt = now
            engagement.thread = thread
            // topic / prompt deliberately nil — these engagements
            // are AI-generated, not links to seeded content.
            context.insert(engagement)
        }

        // 7. Single transaction.
        try? context.save()
        return thread
    }

    // ─────────────────────────────────────────
    // MARK: - Pure helpers (testable in isolation)
    // ─────────────────────────────────────────

    /// Type → canonical method slug. Returns nil for unmapped types,
    /// which the materializer treats as a signal to drop the step.
    /// Mapping defined in `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §2`.
    ///
    /// Case-insensitive on input for resilience against AI capitalization
    /// drift; the output slug is always the canonical lowercase form.
    static func methodSlug(forStepType type: String) -> String? {
        switch type.lowercased() {
        case "article":    return "read"
        case "video":      return "watch"
        case "question":   return "reflect"
        case "reflection": return "reflect"
        case "topic":      return "deep-dive"
        default:           return nil
        }
    }

    /// Returns the trail title to use for the new thread. Trims the
    /// AI-supplied title; falls back to the root engagement's
    /// `contentTitle`; if both are empty, uses a deterministic default.
    static func sanitizedTitle(_ raw: String, fallback: String?) -> String {
        if let trimmed = NewThreadInputValidator.sanitizedTitle(raw) {
            return trimmed
        }
        if let fallback,
           let trimmedFallback = NewThreadInputValidator.sanitizedTitle(fallback) {
            return trimmedFallback
        }
        return "untitled trail"
    }
}
