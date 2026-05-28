import Foundation

/// AI rabbit-hole trail request (Phase 6E-C).
///
/// **Reference type, not a struct.** Matches the `AIRecommendationRequest`
/// pattern: a `final class` with all-`let` properties has stable
/// heap-allocated storage and survives the `@Sendable` async hops on
/// ARM64e physical-device codegen. The struct version of this type would
/// re-introduce the EXC_BAD_ACCESS crash class that
/// `AIRecommendationRequest` was converted out of in `4efd53b`.
///
/// Wire contract: snake_case JSON, sent as the body of `POST /v1/trail`
/// to the Cloudflare Worker proxy. The proxy validates strictly; iOS
/// does not re-validate the same constraints, but the caller is
/// responsible for passing canonical values (method slug from the 5,
/// recency bucket from the 3, etc.).
///
/// Privacy contract (`docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §5`): only the
/// fields below may leave the device for a trail request. Reflection
/// bodies, engagement notes, full engagement history, identifiers, and
/// precise timestamps are forbidden and tested.
final class AITrailRequest: Codable, Equatable, @unchecked Sendable {
    let locale: String
    let rootTitle: String
    let rootMethodSlug: String
    let rootRecencyBucket: String
    let interestSeeds: [String]
    let seededTopicSlugs: [String]?
    let maxSteps: Int?
    let providerPreference: AIProviderPreference

    enum CodingKeys: String, CodingKey {
        case locale
        case rootTitle         = "root_title"
        case rootMethodSlug    = "root_method_slug"
        case rootRecencyBucket = "root_recency_bucket"
        case interestSeeds     = "interest_seeds"
        case seededTopicSlugs  = "seeded_topic_slugs"
        case maxSteps          = "max_steps"
        case providerPreference = "provider_preference"
    }

    init(
        locale: String = Locale.current.identifier,
        rootTitle: String,
        rootMethodSlug: String,
        rootRecencyBucket: String,
        interestSeeds: [String] = [],
        seededTopicSlugs: [String]? = nil,
        maxSteps: Int? = nil,
        providerPreference: AIProviderPreference = .auto
    ) {
        self.locale = locale
        self.rootTitle = rootTitle
        self.rootMethodSlug = rootMethodSlug
        self.rootRecencyBucket = rootRecencyBucket
        self.interestSeeds = interestSeeds
        self.seededTopicSlugs = seededTopicSlugs
        self.maxSteps = maxSteps
        self.providerPreference = providerPreference
    }

    // Equatable — manual since classes don't synthesize.
    static func == (lhs: AITrailRequest, rhs: AITrailRequest) -> Bool {
        lhs.locale == rhs.locale
            && lhs.rootTitle == rhs.rootTitle
            && lhs.rootMethodSlug == rhs.rootMethodSlug
            && lhs.rootRecencyBucket == rhs.rootRecencyBucket
            && lhs.interestSeeds == rhs.interestSeeds
            && lhs.seededTopicSlugs == rhs.seededTopicSlugs
            && lhs.maxSteps == rhs.maxSteps
            && lhs.providerPreference == rhs.providerPreference
    }
}
