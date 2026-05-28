import Foundation

/// AI rabbit-hole trail response (Phase 6E-C).
///
/// Decoded from the body of a successful `POST /v1/trail` response. The
/// proxy normalizes `steps.length` to 3–5, validates each step's `type`
/// and required `url`, and trims long strings server-side — iOS trusts
/// the contract and renders what comes back.
///
/// Value type (struct) for the response, because responses are
/// short-lived (decoded once, consumed in the sheet, discarded on
/// dismiss). They do not cross multi-hop async boundaries like the
/// request does, so the ARM64e class workaround is not needed.
struct AITrailResponse: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String?
    let rootTitle: String
    let steps: [AITrailStep]
    let provider: String
    let modelVersion: String
    let promptInputHash: String
    let cached: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case rootTitle        = "root_title"
        case steps
        case provider
        case modelVersion     = "model_version"
        case promptInputHash  = "prompt_input_hash"
        case cached
        case createdAt        = "created_at"
    }
}

/// One step in an AI-deepened trail. Five canonical `type` values map
/// to the five `RedirectMethod` slugs in `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §2`:
///
/// - `article`    → `read`
/// - `video`      → `watch`
/// - `question`   → `reflect`
/// - `reflection` → `reflect`
/// - `topic`      → `deep-dive`
///
/// Steps with a `type` outside this set are dropped by the proxy (not
/// coerced). `url` is required for `article` and `video`; nullable for
/// the others. `estimatedMinutes` is clamped 1–60 server-side or null.
struct AITrailStep: Codable, Equatable, Sendable {
    let type: String
    let title: String
    let rationale: String
    let url: String?
    let estimatedMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case rationale
        case url
        case estimatedMinutes = "estimated_minutes"
    }
}
