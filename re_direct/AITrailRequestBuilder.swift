import Foundation

/// Pure builder that turns a root `CuriosityEngagement` (+ contextual
/// signals) into an `AITrailRequest` for the proxy `/v1/trail`
/// endpoint. Lifted out of the sheet view so:
///
/// 1. The request shape can be unit-tested without mounting any UI.
/// 2. The privacy boundary is enforced at the type level — this builder
///    reads ONLY the fields documented in
///    `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §5`. There is no path here
///    that touches `engagement.note`, `engagement.reflection`, the
///    engagement's `id`, or sends a raw `engagedAt` timestamp on the
///    wire (only the coarse three-state recency bucket goes out).
///
/// A future slice that wants to widen the request (e.g. include the
/// last few unrelated engagements as context) must add explicit
/// parameters here, in plain sight.
enum AITrailRequestBuilder {

    /// Default cap on AI-proposed step count. 4 keeps the suggested
    /// trail comfortable to scan in the sheet and stays inside the
    /// proxy's 3–5 clamp range.
    static let defaultMaxSteps: Int = 4

    // ─────────────────────────────────────────
    // MARK: - Primitive form (fully explicit)
    // ─────────────────────────────────────────

    /// Build an `AITrailRequest` from primitive inputs. This is the
    /// canonical form — every field the proxy can see is named here.
    static func build(
        rootTitle: String,
        rootMethodSlug: String,
        rootRecencyBucket: String,
        interestSeeds: [String],
        seededTopicSlugs: [String]? = nil,
        locale: String = Locale.current.identifier,
        maxSteps: Int = AITrailRequestBuilder.defaultMaxSteps
    ) -> AITrailRequest {
        AITrailRequest(
            locale: locale,
            rootTitle: rootTitle,
            rootMethodSlug: rootMethodSlug,
            rootRecencyBucket: rootRecencyBucket,
            interestSeeds: interestSeeds,
            seededTopicSlugs: seededTopicSlugs,
            maxSteps: maxSteps,
            providerPreference: .auto
        )
    }

    // ─────────────────────────────────────────
    // MARK: - Convenience: build from engagement
    // ─────────────────────────────────────────

    /// Build an `AITrailRequest` from a root `CuriosityEngagement`.
    ///
    /// **Privacy:** extracts only the allowlisted fields:
    /// - `engagement.contentTitle`  → `rootTitle`
    /// - `engagement.methodSlug`    → `rootMethodSlug`
    /// - `engagement.engagedAt`     → derived into a coarse
    ///   `rootRecencyBucket` (one of `today` / `this_week` / `older`);
    ///   the raw timestamp never leaves the device.
    ///
    /// Deliberately NOT read here: `engagement.note`, `engagement.id`,
    /// `engagement.reflection` (or its `body`), `engagement.sourceURL`,
    /// `engagement.topic`, `engagement.prompt`, `engagement.thread`.
    /// Adding any of those to the outbound payload would require an
    /// explicit parameter on this builder, not a silent read.
    static func build(
        fromRoot engagement: CuriosityEngagement,
        interestSeeds: [String],
        seededTopicSlugs: [String]? = nil,
        now: Date = .now,
        locale: String = Locale.current.identifier,
        maxSteps: Int = AITrailRequestBuilder.defaultMaxSteps
    ) -> AITrailRequest {
        build(
            rootTitle: engagement.contentTitle,
            rootMethodSlug: engagement.methodSlug,
            rootRecencyBucket: recencyBucket(forEngagedAt: engagement.engagedAt, now: now),
            interestSeeds: interestSeeds,
            seededTopicSlugs: seededTopicSlugs,
            locale: locale,
            maxSteps: maxSteps
        )
    }

    // ─────────────────────────────────────────
    // MARK: - Coarse recency bucket (pure)
    // ─────────────────────────────────────────

    /// Maps a `Date` to one of the three canonical recency buckets the
    /// proxy accepts: `today`, `this_week`, `older`. The mapping is
    /// deliberately coarse — exact timestamps are forbidden on the wire
    /// per `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §5`.
    ///
    /// Rules:
    /// - same calendar day as `now`           → `today`
    /// - 1…7 calendar days before `now`       → `this_week`
    /// - 8+ calendar days before `now`        → `older`
    /// - future dates (clock drift safety)    → `today`
    static func recencyBucket(
        forEngagedAt date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }

        let daysAgo = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        if daysAgo <= 0 { return "today" }       // future drift safety
        if daysAgo <= 7 { return "this_week" }
        return "older"
    }

    // ─────────────────────────────────────────
    // MARK: - Cache key derivation (in-memory, local-only)
    // ─────────────────────────────────────────

    /// Derives an `AITrailCacheKey` for the same inputs that would
    /// produce a request via `build(fromRoot:…)`. Co-located here so a
    /// future change to the request shape automatically updates the
    /// cache-key shape too.
    ///
    /// Normalization rules (must match the wire shape's idempotency):
    /// - `normalizedRootTitle` — trimmed + lowercased
    /// - `methodSlug` — lowercased (canonical slugs are already lowercase)
    /// - `recencyBucket` — derived via `recencyBucket(forEngagedAt:…)`
    /// - `seedsFingerprint` — each seed trimmed + lowercased, sorted,
    ///   joined with `"|"` so seed order doesn't shift the key
    ///
    /// The `engagementID` is included for collision avoidance — two
    /// engagements with identical-looking titles still get distinct
    /// cache entries. The ID is local-only and never reaches the wire.
    static func cacheKey(
        forRoot engagement: CuriosityEngagement,
        interestSeeds: [String],
        now: Date = .now,
        locale: String = Locale.current.identifier,
        maxSteps: Int = AITrailRequestBuilder.defaultMaxSteps
    ) -> AITrailCacheKey {
        AITrailCacheKey(
            engagementID: engagement.id,
            normalizedRootTitle: engagement.contentTitle
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
            methodSlug: engagement.methodSlug.lowercased(),
            recencyBucket: recencyBucket(forEngagedAt: engagement.engagedAt, now: now),
            seedsFingerprint: interestSeeds
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .sorted()
                .joined(separator: "|"),
            locale: locale,
            maxSteps: maxSteps
        )
    }
}
