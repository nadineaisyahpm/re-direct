import Foundation

/// In-memory cache key for an AI rabbit-hole trail response.
///
/// Local-only: the cache lives in iOS memory for the duration of an app
/// session. The `engagementID` is the local SwiftData UUID and never
/// leaves the device. The rest of the key mirrors the inputs that
/// shaped the outbound `AITrailRequest` — if any of those change, the
/// cached response is no longer valid for the new request.
///
/// Constructed via `AITrailRequestBuilder.cacheKey(forRoot:…)` so the
/// derivation lives next to the request builder it has to stay in sync
/// with.
struct AITrailCacheKey: Hashable, Sendable {
    let engagementID: UUID
    let normalizedRootTitle: String
    let methodSlug: String
    let recencyBucket: String
    let seedsFingerprint: String
    let locale: String
    let maxSteps: Int
}

/// Per-app-session in-memory cache for AI rabbit-hole trail responses
/// (Phase 6E QA0 Slice B).
///
/// **Why this exists**: the QA0 audit (F2) flagged that every tap on
/// `[deepen]` re-fires a proxy call, even when the user is just
/// re-opening the same loose-end's sheet. With this cache, repeated
/// taps within the TTL window return the previously-fetched response
/// without hitting the Cloudflare Worker.
///
/// **Why this is not SwiftData**: per `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §7`
/// the trail TTL is 1 hour (much shorter than Daily Direct's 24h).
/// In-memory is the right durability — cross-launch persistence would
/// risk presenting stale trails after the user's attention has shifted.
///
/// Mirrors the `DailyDirectSessionStore` pattern:
/// - `.shared` singleton for production usage from `TrailPreviewSheet`.
/// - Public `init` so tests can construct isolated stores with a
///   custom `now` closure and TTL.
/// - `@MainActor`-isolated because callers are `@MainActor` (views,
///   SwiftData contexts).
@MainActor
final class AITrailSessionStore {

    /// Production singleton.
    static let shared = AITrailSessionStore()

    /// Plan §7 freshness window for trails — 1 hour.
    static let defaultTTL: TimeInterval = 60 * 60

    private struct Entry {
        let response: AITrailResponse
        let storedAt: Date
    }

    private var entries: [AITrailCacheKey: Entry] = [:]

    /// Freshness window. Entries older than `ttl` are treated as misses
    /// (and proactively pruned on access).
    let ttl: TimeInterval

    /// Time source. Tests inject a controllable clock; production uses
    /// `Date()`.
    private let now: @Sendable () -> Date

    init(
        ttl: TimeInterval = AITrailSessionStore.defaultTTL,
        now: @Sendable @escaping () -> Date = { Date() }
    ) {
        self.ttl = ttl
        self.now = now
    }

    // MARK: - Read / write

    /// Returns the cached response if one exists and is fresh.
    /// Prunes the entry inline if it has expired.
    func lookup(_ key: AITrailCacheKey) -> AITrailResponse? {
        guard let entry = entries[key] else { return nil }
        let age = now().timeIntervalSince(entry.storedAt)
        if age >= ttl {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.response
    }

    /// Stores a fresh response under `key`. Overwrites any existing
    /// entry (re-fetch wins).
    func store(_ response: AITrailResponse, for key: AITrailCacheKey) {
        entries[key] = Entry(response: response, storedAt: now())
    }

    /// Removes a single key. Optional — only useful if a caller wants
    /// to invalidate after accept; `TrailPreviewSheet` doesn't do this
    /// in v1 because the underlying loose engagement disappears after
    /// materialization, so a re-tap is unlikely.
    func remove(_ key: AITrailCacheKey) {
        entries.removeValue(forKey: key)
    }

    /// Clears the entire cache. Useful for tests; not called by
    /// production code.
    func reset() {
        entries.removeAll()
    }

    // MARK: - Combined load helper

    /// Cache-aware loader: returns the cached response immediately if
    /// fresh; otherwise invokes `call`, stores the result on success,
    /// and returns it. **Failures (thrown errors) are not cached** —
    /// they propagate to the caller and leave the cache unchanged.
    ///
    /// Lifted out as a single function so the cache-then-call-then-store
    /// flow can be unit-tested without mounting `TrailPreviewSheet`.
    func loadingResponse(
        for key: AITrailCacheKey,
        call: () async throws -> AITrailResponse
    ) async throws -> AITrailResponse {
        if let cached = lookup(key) {
            return cached
        }
        let response = try await call()
        store(response, for: key)
        return response
    }
}
