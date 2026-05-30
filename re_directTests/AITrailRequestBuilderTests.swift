import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("AITrailRequestBuilder (Phase 6E-D2)")
struct AITrailRequestBuilderTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Recency bucket (pure)

    /// UTC-pinned calendar for deterministic day-boundary tests across
    /// any test-runner timezone. The helper itself uses the caller's
    /// calendar in production; tests pin to UTC so the boundary math
    /// produces the same result on every machine.
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test("Same calendar day → today")
    func recencyBucketToday() {
        let cal = utcCalendar()
        // 1_700_000_000 UTC = 2023-11-14 21:13:20Z. Choose `now` and an
        // earlier time both safely in the same UTC day (UTC noon, UTC 6 AM).
        let now = Date(timeIntervalSince1970: 1_700_000_000 - 21_600 - 1_000) // ~14:00Z
        let earlierToday = now.addingTimeInterval(-3600 * 6)                  // ~08:00Z same day
        #expect(AITrailRequestBuilder.recencyBucket(forEngagedAt: earlierToday, now: now, calendar: cal) == "today")
        #expect(AITrailRequestBuilder.recencyBucket(forEngagedAt: now, now: now, calendar: cal) == "today")
    }

    @Test("1 day ago → this_week")
    func recencyBucketOneDayAgo() {
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        #expect(AITrailRequestBuilder.recencyBucket(forEngagedAt: yesterday, now: now, calendar: cal) == "this_week")
    }

    @Test("6 days ago → this_week")
    func recencyBucketSixDaysAgo() {
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sixDaysAgo = cal.date(byAdding: .day, value: -6, to: now)!
        #expect(AITrailRequestBuilder.recencyBucket(forEngagedAt: sixDaysAgo, now: now, calendar: cal) == "this_week")
    }

    @Test("7 days ago → this_week (boundary)")
    func recencyBucketSevenDaysAgo() {
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now)!
        #expect(AITrailRequestBuilder.recencyBucket(forEngagedAt: sevenDaysAgo, now: now, calendar: cal) == "this_week")
    }

    @Test("8 days ago → older (just past the boundary)")
    func recencyBucketEightDaysAgo() {
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let eightDaysAgo = cal.date(byAdding: .day, value: -8, to: now)!
        #expect(AITrailRequestBuilder.recencyBucket(forEngagedAt: eightDaysAgo, now: now, calendar: cal) == "older")
    }

    @Test("100 days ago → older")
    func recencyBucketHundredDaysAgo() {
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let oldDate = cal.date(byAdding: .day, value: -100, to: now)!
        #expect(AITrailRequestBuilder.recencyBucket(forEngagedAt: oldDate, now: now, calendar: cal) == "older")
    }

    @Test("Future date drift → today (clock-skew safety)")
    func recencyBucketFutureDateDriftsToToday() {
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let future = cal.date(byAdding: .day, value: 3, to: now)!
        // Not same calendar day, daysAgo is negative → falls into the
        // "future drift safety" branch → today.
        #expect(AITrailRequestBuilder.recencyBucket(forEngagedAt: future, now: now, calendar: cal) == "today")
    }

    // MARK: - Build (primitive form)

    @Test("Build (primitives) populates all expected fields")
    func buildPrimitivesPopulatesAllFields() {
        let request = AITrailRequestBuilder.build(
            rootTitle: "bioluminescence",
            rootMethodSlug: "read",
            rootRecencyBucket: "today",
            interestSeeds: ["Apple", "ML"],
            seededTopicSlugs: ["bioluminescence"],
            locale: "en-US",
            maxSteps: 5
        )
        #expect(request.locale == "en-US")
        #expect(request.rootTitle == "bioluminescence")
        #expect(request.rootMethodSlug == "read")
        #expect(request.rootRecencyBucket == "today")
        #expect(request.interestSeeds == ["Apple", "ML"])
        #expect(request.seededTopicSlugs == ["bioluminescence"])
        #expect(request.maxSteps == 5)
        #expect(request.providerPreference == .auto)
    }

    @Test("Build (primitives) default maxSteps is 4")
    func buildPrimitivesDefaultMaxStepsFour() {
        let request = AITrailRequestBuilder.build(
            rootTitle: "x",
            rootMethodSlug: "read",
            rootRecencyBucket: "today",
            interestSeeds: ["AI"]
        )
        #expect(request.maxSteps == 4)
    }

    @Test("Build (primitives) always uses providerPreference = .auto")
    func buildPrimitivesProviderPreferenceAuto() {
        let request = AITrailRequestBuilder.build(
            rootTitle: "x",
            rootMethodSlug: "read",
            rootRecencyBucket: "today",
            interestSeeds: ["AI"]
        )
        #expect(request.providerPreference == .auto)
    }

    @Test("Build (primitives) omits seededTopicSlugs by default")
    func buildPrimitivesOmitsSeededTopicSlugsByDefault() {
        let request = AITrailRequestBuilder.build(
            rootTitle: "x",
            rootMethodSlug: "read",
            rootRecencyBucket: "today",
            interestSeeds: ["AI"]
        )
        #expect(request.seededTopicSlugs == nil)
    }

    // MARK: - Build (engagement form)

    @Test("Build (engagement) copies contentTitle and methodSlug")
    func buildFromEngagementCopiesTitleAndSlug() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "watch"
        engagement.contentTitle = "Living light: a 6-minute tour"
        engagement.engagedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(engagement)
        try context.save()

        let request = AITrailRequestBuilder.build(
            fromRoot: engagement,
            interestSeeds: ["Neuroscience"],
            now: engagement.engagedAt
        )

        #expect(request.rootTitle == "Living light: a 6-minute tour")
        #expect(request.rootMethodSlug == "watch")
        #expect(request.rootRecencyBucket == "today")
        #expect(request.interestSeeds == ["Neuroscience"])
    }

    @Test("Build (engagement) derives recency bucket from engagedAt")
    func buildFromEngagementDerivesRecencyFromEngagedAt() throws {
        let context = try makeContext()
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fiveDaysAgo = cal.date(byAdding: .day, value: -5, to: now)!

        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "old article"
        engagement.engagedAt = fiveDaysAgo
        context.insert(engagement)
        try context.save()

        let request = AITrailRequestBuilder.build(
            fromRoot: engagement,
            interestSeeds: ["AI"],
            now: now
        )
        #expect(request.rootRecencyBucket == "this_week")
    }

    @Test("Build (engagement) default maxSteps is 4")
    func buildFromEngagementDefaultMaxStepsFour() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "x"
        context.insert(engagement)
        try context.save()

        let request = AITrailRequestBuilder.build(
            fromRoot: engagement,
            interestSeeds: ["AI"]
        )
        #expect(request.maxSteps == 4)
    }

    // MARK: - Privacy invariant

    @Test("Build (engagement) does NOT pull engagement.note onto the request")
    func buildFromEngagementDoesNotReadNote() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "the title"
        engagement.note = "PRIVATE-NOTE-SENTINEL"
        context.insert(engagement)
        try context.save()

        let request = AITrailRequestBuilder.build(
            fromRoot: engagement,
            interestSeeds: ["AI"]
        )

        // The note must not appear anywhere on the request's stored fields.
        #expect(!request.rootTitle.contains("PRIVATE-NOTE-SENTINEL"))
        for seed in request.interestSeeds {
            #expect(!seed.contains("PRIVATE-NOTE-SENTINEL"))
        }
    }

    @Test("Build (engagement) does NOT pull engagement.reflection.body onto the request")
    func buildFromEngagementDoesNotReadReflectionBody() throws {
        let context = try makeContext()

        let reflection = ReflectionEntry()
        reflection.mood = "curious"
        reflection.body = "PRIVATE-REFLECTION-BUILDER-SENTINEL"
        context.insert(reflection)

        let engagement = CuriosityEngagement()
        engagement.methodSlug = "reflect"
        engagement.contentTitle = "the title"
        engagement.reflection = reflection
        context.insert(engagement)
        try context.save()

        let request = AITrailRequestBuilder.build(
            fromRoot: engagement,
            interestSeeds: ["AI"]
        )

        // Walk every String-valued field on the request via Mirror —
        // none should contain the sentinel.
        let mirror = Mirror(reflecting: request)
        var stringValues: [String] = []
        for child in mirror.children {
            if let s = child.value as? String { stringValues.append(s) }
            if let arr = child.value as? [String] { stringValues.append(contentsOf: arr) }
        }
        for value in stringValues {
            #expect(!value.contains("PRIVATE-REFLECTION-BUILDER-SENTINEL"),
                    "Sentinel leaked into request field: \(value)")
        }

        // The reflection link is preserved on the engagement (correct —
        // local-only). The body still lives on ReflectionEntry, not
        // anywhere the builder reads.
        #expect(engagement.reflection?.body == "PRIVATE-REFLECTION-BUILDER-SENTINEL")
    }

    @Test("Build (engagement) does NOT include any timestamp in the wire-bound fields")
    func buildFromEngagementDoesNotIncludeRawTimestamp() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "title"
        engagement.engagedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(engagement)
        try context.save()

        let request = AITrailRequestBuilder.build(
            fromRoot: engagement,
            interestSeeds: ["AI"]
        )

        // The wire-encoded request body must not contain anything that
        // looks like an ISO-8601 or epoch timestamp.
        let body = try AIProxyHTTPClient.encodeTrailBody(request)
        let json = try #require(String(data: body, encoding: .utf8))

        // Specifically not the engagedAt epoch as a string:
        #expect(!json.contains("1700000000"))
        // And no ISO-8601 markers that would suggest a raw timestamp
        // crept in (the bucket value is "today" / "this_week" / "older").
        #expect(!json.contains("T00:") && !json.contains("Z\""))
        // Allowlist sanity: the bucket value IS present.
        #expect(json.contains("\"root_recency_bucket\""))
        let bucketValue = request.rootRecencyBucket
        #expect(["today", "this_week", "older"].contains(bucketValue))
    }

    // MARK: - Cache key derivation (QA0 Slice B)

    @Test("cacheKey derivation is deterministic for the same inputs")
    func cacheKeyDeterministic() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "Bioluminescence"
        engagement.engagedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(engagement)
        try context.save()

        let key1 = AITrailRequestBuilder.cacheKey(
            forRoot: engagement,
            interestSeeds: ["AI", "Neuroscience"],
            now: engagement.engagedAt
        )
        let key2 = AITrailRequestBuilder.cacheKey(
            forRoot: engagement,
            interestSeeds: ["AI", "Neuroscience"],
            now: engagement.engagedAt
        )
        #expect(key1 == key2)
    }

    @Test("cacheKey normalizes title: trim + lowercase")
    func cacheKeyTitleNormalization() throws {
        let context = try makeContext()
        let a = CuriosityEngagement()
        a.methodSlug = "read"
        a.contentTitle = "  Bioluminescence  "
        context.insert(a)

        let b = CuriosityEngagement()
        b.methodSlug = "read"
        b.contentTitle = "bioluminescence"
        context.insert(b)
        try context.save()

        let keyA = AITrailRequestBuilder.cacheKey(forRoot: a, interestSeeds: ["AI"])
        let keyB = AITrailRequestBuilder.cacheKey(forRoot: b, interestSeeds: ["AI"])
        #expect(keyA.normalizedRootTitle == "bioluminescence")
        #expect(keyB.normalizedRootTitle == "bioluminescence")
        // Different engagements still get distinct keys because of engagementID.
        #expect(keyA != keyB)
    }

    @Test("cacheKey changes when methodSlug changes")
    func cacheKeyChangesOnMethodSlug() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "x"
        context.insert(engagement)
        try context.save()

        let keyA = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"])
        engagement.methodSlug = "watch"
        let keyB = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"])

        #expect(keyA != keyB)
        #expect(keyA.methodSlug == "read")
        #expect(keyB.methodSlug == "watch")
    }

    @Test("cacheKey changes when content title changes")
    func cacheKeyChangesOnTitle() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "First"
        context.insert(engagement)
        try context.save()

        let keyA = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"])
        engagement.contentTitle = "Second"
        let keyB = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"])

        #expect(keyA != keyB)
    }

    @Test("cacheKey changes when maxSteps changes")
    func cacheKeyChangesOnMaxSteps() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "x"
        context.insert(engagement)
        try context.save()

        let keyA = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"], maxSteps: 3)
        let keyB = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"], maxSteps: 5)

        #expect(keyA != keyB)
        #expect(keyA.maxSteps == 3)
        #expect(keyB.maxSteps == 5)
    }

    @Test("cacheKey changes when locale changes")
    func cacheKeyChangesOnLocale() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "x"
        context.insert(engagement)
        try context.save()

        let keyA = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"], locale: "en-US")
        let keyB = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"], locale: "fr-FR")

        #expect(keyA != keyB)
    }

    @Test("cacheKey is invariant to interest-seed order")
    func cacheKeyInvariantToSeedOrder() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "x"
        context.insert(engagement)
        try context.save()

        let keyA = AITrailRequestBuilder.cacheKey(
            forRoot: engagement,
            interestSeeds: ["Neuroscience", "AI", "Machine Learning"]
        )
        let keyB = AITrailRequestBuilder.cacheKey(
            forRoot: engagement,
            interestSeeds: ["AI", "Machine Learning", "Neuroscience"]
        )

        #expect(keyA == keyB)
    }

    @Test("cacheKey changes when interest seeds change set")
    func cacheKeyChangesOnSeedsSet() throws {
        let context = try makeContext()
        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "x"
        context.insert(engagement)
        try context.save()

        let keyA = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["AI"])
        let keyB = AITrailRequestBuilder.cacheKey(forRoot: engagement, interestSeeds: ["Biology"])

        #expect(keyA != keyB)
    }

    @Test("cacheKey changes when recency bucket changes (engagedAt drift across the boundary)")
    func cacheKeyChangesOnRecencyBucket() throws {
        let context = try makeContext()
        var calUTC = Calendar(identifier: .gregorian)
        calUTC.timeZone = TimeZone(identifier: "UTC")!

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = now
        let twoWeeksAgo = calUTC.date(byAdding: .day, value: -14, to: now)!

        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "x"
        engagement.engagedAt = today
        context.insert(engagement)
        try context.save()

        let keyToday = AITrailRequestBuilder.cacheKey(
            forRoot: engagement,
            interestSeeds: ["AI"],
            now: now
        )
        engagement.engagedAt = twoWeeksAgo
        let keyOlder = AITrailRequestBuilder.cacheKey(
            forRoot: engagement,
            interestSeeds: ["AI"],
            now: now
        )

        #expect(keyToday != keyOlder)
        #expect(keyToday.recencyBucket == "today")
        #expect(keyOlder.recencyBucket == "older")
    }

    // MARK: - Pre-existing privacy invariants (unchanged)

    @Test("Build (engagement) does NOT include id, sourceURL, topic, or prompt fields")
    func buildFromEngagementOmitsIdentifiersAndLinks() throws {
        let context = try makeContext()

        let topic = CuriosityTopic()
        topic.slug = "leak-test"
        topic.title = "Leak test topic"
        context.insert(topic)

        let prompt = CuriosityPrompt()
        prompt.slug = "leak-test-prompt"
        prompt.body = "leak test"
        prompt.topic = topic
        context.insert(prompt)

        let engagement = CuriosityEngagement()
        engagement.methodSlug = "read"
        engagement.contentTitle = "title"
        engagement.sourceURL = "https://private.example.com/path?id=LEAK-SENTINEL"
        engagement.topic = topic
        engagement.prompt = prompt
        context.insert(engagement)
        try context.save()

        let request = AITrailRequestBuilder.build(
            fromRoot: engagement,
            interestSeeds: ["AI"]
        )
        let body = try AIProxyHTTPClient.encodeTrailBody(request)
        let json = try #require(String(data: body, encoding: .utf8))

        // sourceURL never reaches the wire.
        #expect(!json.contains("LEAK-SENTINEL"))
        #expect(!json.contains("private.example.com"))
        // Topic and prompt slugs aren't sent in the outbound request
        // unless explicitly passed as seededTopicSlugs by the caller.
        #expect(!json.contains("leak-test"))
        // Engagement id is not in the body.
        #expect(!json.contains(engagement.id.uuidString))
    }

    // ─────────────────────────────────────────
    // MARK: - Wire format / contract tests
    // ─────────────────────────────────────────
    //
    // These tests pin the EXACT JSON the proxy will receive. They are the
    // primary guard against the class of bug where a small iOS/proxy mismatch
    // causes silent 400s — e.g. locale "en_US" (Apple format) vs "en-US"
    // (BCP-47, what the proxy schema requires).
    //
    // If a test here fails, update BOTH the iOS code AND the proxy contract
    // fixture at re_direct_ai_proxy/test/contract/ios-trail-request.fixture.json.

    @Test("Locale is BCP-47 hyphen format, not Apple underscore format")
    func localeIsBCP47() {
        let locale = AITrailRequestBuilder.bcp47Locale()
        // Must match the proxy regex: ^[a-z]{2}(-[A-Z]{2})?$
        #expect(!locale.contains("_"),
                "bcp47Locale() returned '\(locale)' — underscores fail the proxy regex")
        let range = locale.range(of: #"^[a-z]{2}(-[A-Z]{2})?$"#, options: .regularExpression)
        #expect(range != nil,
                "bcp47Locale() returned '\(locale)' — doesn't match ^[a-z]{2}(-[A-Z]{2})?$")
    }

    @Test("bcp47Locale strips script subtags from complex locales")
    func localeStripsScriptSubtag() {
        // zh_Hans_CN should become zh-CN, not zh-Hans (which fails the 2-char region check)
        let mock = Locale(identifier: "zh_Hans_CN")
        let result = AITrailRequestBuilder.bcp47Locale(from: mock)
        #expect(result == "zh-CN", "Expected zh-CN, got \(result)")
    }

    @Test("bcp47Locale handles simple en_US format")
    func localeConvertsEnUS() {
        let mock = Locale(identifier: "en_US")
        let result = AITrailRequestBuilder.bcp47Locale(from: mock)
        #expect(result == "en-US", "Expected en-US, got \(result)")
    }

    @Test("Encoded JSON contains all required proxy keys")
    func wireKeysComplete() throws {
        let request = AITrailRequestBuilder.build(
            rootTitle: "bioluminescence",
            rootMethodSlug: "read",
            rootRecencyBucket: "today",
            interestSeeds: ["Neuroscience"],
            locale: "en-US"
        )
        let data = try AIProxyHTTPClient.encodeTrailBody(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let required = ["locale", "root_title", "root_method_slug",
                        "root_recency_bucket", "interest_seeds", "provider_preference"]
        for key in required {
            #expect(json[key] != nil, "Missing required wire key: \(key)")
        }
    }

    @Test("Encoded JSON contains no keys the proxy strict schema rejects")
    func wireKeysNoExtras() throws {
        let request = AITrailRequestBuilder.build(
            rootTitle: "test",
            rootMethodSlug: "read",
            rootRecencyBucket: "today",
            interestSeeds: [],
            locale: "en-US"
        )
        let data = try AIProxyHTTPClient.encodeTrailBody(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let allowed: Set<String> = [
            "locale", "root_title", "root_method_slug", "root_recency_bucket",
            "interest_seeds", "seeded_topic_slugs", "max_steps", "provider_preference"
        ]
        for key in json.keys {
            #expect(allowed.contains(key),
                    "Unexpected wire key '\(key)' — proxy strict mode will return 400")
        }
    }

    @Test("provider_preference always encodes as 'auto' by default")
    func providerPreferenceDefault() throws {
        let request = AITrailRequestBuilder.build(
            rootTitle: "test",
            rootMethodSlug: "read",
            rootRecencyBucket: "today",
            interestSeeds: [],
            locale: "en-US"
        )
        let data = try AIProxyHTTPClient.encodeTrailBody(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["provider_preference"] as? String == "auto")
    }
}
