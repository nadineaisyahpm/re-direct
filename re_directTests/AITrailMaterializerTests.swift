import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("AITrailMaterializer (Phase 6E-D1)")
struct AITrailMaterializerTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeStep(
        type: String,
        title: String = "step title",
        rationale: String = "step rationale",
        url: String? = "https://example.com/step",
        estimatedMinutes: Int? = 5
    ) -> AITrailStep {
        AITrailStep(
            type: type,
            title: title,
            rationale: rationale,
            url: url,
            estimatedMinutes: estimatedMinutes
        )
    }

    private func makeResponse(
        title: String = "What the deep sea remembers",
        summary: String? = "A short trail.",
        steps: [AITrailStep],
        rootTitle: String = "bioluminescence"
    ) -> AITrailResponse {
        AITrailResponse(
            id: "01HZX",
            title: title,
            summary: summary,
            rootTitle: rootTitle,
            steps: steps,
            provider: "deepseek",
            modelVersion: "deepseek-v4-flash",
            promptInputHash: "f3a1",
            cached: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private let now = Date(timeIntervalSince1970: 1_701_000_000)

    // MARK: - Type → slug mapping (pure)

    @Test("methodSlug maps each canonical step type to the right slug")
    func methodSlugAllValidTypes() {
        #expect(AITrailMaterializer.methodSlug(forStepType: "article")    == "read")
        #expect(AITrailMaterializer.methodSlug(forStepType: "video")      == "watch")
        #expect(AITrailMaterializer.methodSlug(forStepType: "question")   == "reflect")
        #expect(AITrailMaterializer.methodSlug(forStepType: "reflection") == "reflect")
        #expect(AITrailMaterializer.methodSlug(forStepType: "topic")      == "deep-dive")
    }

    @Test("methodSlug returns nil for unmapped types")
    func methodSlugReturnsNilForUnknown() {
        #expect(AITrailMaterializer.methodSlug(forStepType: "podcast") == nil)
        #expect(AITrailMaterializer.methodSlug(forStepType: "") == nil)
        #expect(AITrailMaterializer.methodSlug(forStepType: "garbage") == nil)
    }

    @Test("methodSlug is case-insensitive on input")
    func methodSlugCaseInsensitive() {
        #expect(AITrailMaterializer.methodSlug(forStepType: "ARTICLE") == "read")
        #expect(AITrailMaterializer.methodSlug(forStepType: "Video")   == "watch")
        #expect(AITrailMaterializer.methodSlug(forStepType: "TOPIC")   == "deep-dive")
    }

    // MARK: - Title sanitization (pure)

    @Test("sanitizedTitle uses trimmed AI title when present")
    func sanitizedTitleUsesAITitle() {
        #expect(AITrailMaterializer.sanitizedTitle("  Trail title  ", fallback: "Root") == "Trail title")
    }

    @Test("sanitizedTitle falls back to root engagement title when AI title is empty")
    func sanitizedTitleFallsBackToRoot() {
        #expect(AITrailMaterializer.sanitizedTitle("   ", fallback: "Root title") == "Root title")
        #expect(AITrailMaterializer.sanitizedTitle("", fallback: "Root title") == "Root title")
    }

    @Test("sanitizedTitle uses default when both AI title and fallback are empty")
    func sanitizedTitleFinalDefault() {
        #expect(AITrailMaterializer.sanitizedTitle("", fallback: nil) == "untitled trail")
        #expect(AITrailMaterializer.sanitizedTitle("  ", fallback: "  ") == "untitled trail")
    }

    // MARK: - Materialize: thread shape

    @Test("Materialize creates exactly one .aiDeepened thread with status .open")
    func materializeCreatesOneAiDeepenedThread() throws {
        let context = try makeContext()

        let response = makeResponse(steps: [
            makeStep(type: "article", title: "step 1"),
            makeStep(type: "video", title: "step 2"),
            makeStep(type: "question", title: "step 3", url: nil),
        ])

        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )

        let threadCount = try context.fetchCount(FetchDescriptor<RabbitHoleThread>())
        #expect(threadCount == 1)
        #expect(thread.source == .aiDeepened)
        #expect(thread.sourceRaw == "ai-deepened")
        #expect(thread.status == .open)
        #expect(thread.statusRaw == "open")
    }

    @Test("Materialize sets all timestamps deterministically to `now`")
    func materializeTimestampsAreDeterministic() throws {
        let context = try makeContext()

        let response = makeResponse(steps: [
            makeStep(type: "article", title: "step 1"),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )

        #expect(thread.createdAt == now)
        #expect(thread.updatedAt == now)
        #expect(thread.lastEngagedAt == now)
        #expect(thread.deletedAt == nil)
    }

    @Test("Materialize uses the response title")
    func materializeUsesResponseTitle() throws {
        let context = try makeContext()
        let response = makeResponse(
            title: "My specific title",
            steps: [makeStep(type: "article", title: "x")]
        )
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context
            )
        )
        #expect(thread.title == "My specific title")
    }

    @Test("Materialize falls back to root title when AI title is empty")
    func materializeFallsBackToRootTitle() throws {
        let context = try makeContext()

        let root = CuriosityEngagement()
        root.methodSlug = "read"
        root.contentTitle = "the original curiosity"
        context.insert(root)
        try context.save()

        let response = makeResponse(
            title: "   ",
            steps: [makeStep(type: "article", title: "x")]
        )
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: root,
                into: context
            )
        )
        #expect(thread.title == "the original curiosity")
    }

    @Test("Materialize stores summary when present and non-empty")
    func materializeStoresSummary() throws {
        let context = try makeContext()
        let response = makeResponse(
            summary: "  a short summary  ",
            steps: [makeStep(type: "article", title: "x")]
        )
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context
            )
        )
        #expect(thread.summary == "a short summary")
    }

    @Test("Materialize stores nil summary when response summary is empty/whitespace/nil")
    func materializeOmitsSummary() throws {
        let context = try makeContext()

        for raw in [nil, "", "   ", "\n\n"] as [String?] {
            let response = makeResponse(
                summary: raw,
                steps: [makeStep(type: "article", title: "x")]
            )
            let ctx = try makeContext()
            let thread = try #require(
                AITrailMaterializer.materialize(
                    response: response,
                    root: nil,
                    into: ctx
                )
            )
            #expect(thread.summary == nil, "Expected nil summary for raw=\(String(describing: raw))")
        }
        _ = context
    }

    // MARK: - Materialize: engagement creation

    @Test("Materialize creates exactly one engagement per valid step (3 steps)")
    func materializeThreeSteps() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article",  title: "a"),
            makeStep(type: "video",    title: "b"),
            makeStep(type: "question", title: "c", url: nil),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        #expect(thread.engagements.count == 3)
    }

    @Test("Materialize creates exactly one engagement per valid step (5 steps)")
    func materializeFiveSteps() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article", title: "a"),
            makeStep(type: "video", title: "b"),
            makeStep(type: "question", title: "c", url: nil),
            makeStep(type: "reflection", title: "d", url: nil),
            makeStep(type: "topic", title: "e", url: nil),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        #expect(thread.engagements.count == 5)
    }

    @Test("Materialize attaches every created engagement to the new thread")
    func materializeAttachesEngagementsToThread() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article",  title: "a"),
            makeStep(type: "video",    title: "b"),
            makeStep(type: "question", title: "c", url: nil),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        for engagement in thread.engagements {
            #expect(engagement.thread === thread)
        }
    }

    @Test("Materialize skips steps with invalid types")
    func materializeSkipsInvalidStepTypes() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article",  title: "valid 1"),
            makeStep(type: "podcast",  title: "invalid"),     // unmapped → dropped
            makeStep(type: "video",    title: "valid 2"),
            makeStep(type: "garbage",  title: "invalid"),     // unmapped → dropped
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )

        #expect(thread.engagements.count == 2)
        let titles = Set(thread.engagements.map(\.contentTitle))
        #expect(titles == Set(["valid 1", "valid 2"]))
    }

    @Test("Materialize returns nil and writes nothing when no valid steps remain")
    func materializeReturnsNilWhenNoValidSteps() throws {
        let context = try makeContext()

        let response = makeResponse(steps: [
            makeStep(type: "podcast",  title: "x"),
            makeStep(type: "garbage",  title: "y"),
        ])
        let result = AITrailMaterializer.materialize(
            response: response,
            root: nil,
            into: context,
            now: now
        )

        #expect(result == nil)
        let threadCount = try context.fetchCount(FetchDescriptor<RabbitHoleThread>())
        let engagementCount = try context.fetchCount(FetchDescriptor<CuriosityEngagement>())
        #expect(threadCount == 0)
        #expect(engagementCount == 0)
    }

    @Test("Materialize returns nil for an empty step list")
    func materializeReturnsNilForEmptySteps() throws {
        let context = try makeContext()

        let response = makeResponse(steps: [])
        let result = AITrailMaterializer.materialize(
            response: response,
            root: nil,
            into: context,
            now: now
        )

        #expect(result == nil)
    }

    @Test("Materialize stores step rationale as engagement.note (editorial AI text, not reflection body)")
    func materializeStoresRationaleAsNote() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article",
                     title: "a",
                     rationale: "this step bridges into the chemistry"),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        let engagement = try #require(thread.engagements.first)
        #expect(engagement.note == "this step bridges into the chemistry")
    }

    @Test("Materialize stores step URL on engagement.sourceURL when present")
    func materializeStoresStepURL() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article",
                     title: "a",
                     url: "https://example.com/article-1"),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        let engagement = try #require(thread.engagements.first)
        #expect(engagement.sourceURL == "https://example.com/article-1")
    }

    @Test("Materialize leaves engagement.sourceURL nil when step URL is nil")
    func materializeLeavesSourceURLNilWhenStepURLNil() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "question",
                     title: "q",
                     url: nil),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        let engagement = try #require(thread.engagements.first)
        #expect(engagement.sourceURL == nil)
    }

    @Test("Materialize stamps every step engagement with engagedAt = now")
    func materializeStepsAreEngagedAtNow() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article",  title: "a"),
            makeStep(type: "video",    title: "b"),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        for engagement in thread.engagements {
            #expect(engagement.engagedAt == now)
        }
    }

    @Test("Materialize leaves step engagement topic and prompt nil")
    func materializeStepEngagementsHaveNoSeedLinks() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article", title: "a"),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        let engagement = try #require(thread.engagements.first)
        #expect(engagement.topic == nil)
        #expect(engagement.prompt == nil)
    }

    // MARK: - Materialize: root engagement handling (Branch A / B)

    @Test("Branch A: root engagement is unthreaded → attached as part of the new thread")
    func materializeBranchARootUnthreaded() throws {
        let context = try makeContext()

        let root = CuriosityEngagement()
        root.methodSlug = "read"
        root.contentTitle = "the original root"
        root.engagedAt = Date(timeIntervalSince1970: 1_700_500_000) // earlier than `now`
        context.insert(root)
        try context.save()

        let response = makeResponse(steps: [
            makeStep(type: "article", title: "step 1"),
            makeStep(type: "video",   title: "step 2"),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: root,
                into: context,
                now: now
            )
        )

        #expect(root.thread === thread)
        // Root + 2 step engagements = 3 total.
        #expect(thread.engagements.count == 3)
        // Branch A does not populate seed metadata.
        #expect(thread.seedTopic == nil)
        #expect(thread.seedPrompt == nil)
        // Root's own engagedAt is preserved, not overwritten.
        #expect(root.engagedAt == Date(timeIntervalSince1970: 1_700_500_000))
    }

    @Test("Branch B: root is already threaded → root stays put, new thread carries seedTopic/seedPrompt")
    func materializeBranchBRootThreaded() throws {
        let context = try makeContext()

        let topic = CuriosityTopic()
        topic.slug = "bioluminescence-test"
        topic.title = "Bioluminescence"
        context.insert(topic)

        let prompt = CuriosityPrompt()
        prompt.slug = "blue-glow"
        prompt.body = "Why is the deep blue?"
        prompt.topic = topic
        context.insert(prompt)

        let preexistingThread = RabbitHoleThread()
        preexistingThread.title = "preexisting"
        preexistingThread.statusRaw = ThreadStatus.open.rawValue
        context.insert(preexistingThread)

        let root = CuriosityEngagement()
        root.methodSlug = "read"
        root.contentTitle = "root with topic + prompt"
        root.topic = topic
        root.prompt = prompt
        root.thread = preexistingThread  // race: root already attached
        context.insert(root)
        try context.save()

        let response = makeResponse(steps: [
            makeStep(type: "article", title: "step 1"),
            makeStep(type: "video",   title: "step 2"),
        ])
        let newThread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: root,
                into: context,
                now: now
            )
        )

        // Root stays on the pre-existing thread.
        #expect(root.thread === preexistingThread)
        // New thread is separate and carries the seed metadata.
        #expect(newThread !== preexistingThread)
        #expect(newThread.seedTopic === topic)
        #expect(newThread.seedPrompt === prompt)
        // Only the step engagements, not the root.
        #expect(newThread.engagements.count == 2)
        let titles = Set(newThread.engagements.map(\.contentTitle))
        #expect(titles == Set(["step 1", "step 2"]))
    }

    @Test("Nil root: materializes cleanly without any root engagement")
    func materializeWithNilRoot() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article", title: "a"),
            makeStep(type: "video",   title: "b"),
        ])
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: nil,
                into: context,
                now: now
            )
        )
        #expect(thread.engagements.count == 2)
        #expect(thread.seedTopic == nil)
        #expect(thread.seedPrompt == nil)
    }

    // MARK: - Privacy invariant

    @Test("Materialize never copies ReflectionEntry.body anywhere")
    func materializeReflectionBodyNotCopied() throws {
        let context = try makeContext()

        let reflection = ReflectionEntry()
        reflection.mood = "curious"
        reflection.body = "PRIVATE-TRAIL-SENTINEL-XYZ"
        context.insert(reflection)

        let root = CuriosityEngagement()
        root.methodSlug = "reflect"
        root.contentTitle = "Quiet five minutes about whales"
        root.reflection = reflection
        context.insert(root)
        try context.save()

        let response = makeResponse(
            title: "Trail title",
            summary: "Trail summary",
            steps: [
                makeStep(type: "article",  title: "step 1", rationale: "step 1 rationale"),
                makeStep(type: "question", title: "step 2", rationale: "step 2 rationale", url: nil),
            ]
        )
        let thread = try #require(
            AITrailMaterializer.materialize(
                response: response,
                root: root,
                into: context,
                now: now
            )
        )

        // Title and summary never contain the sentinel.
        #expect(!thread.title.contains("PRIVATE-TRAIL-SENTINEL"))
        if let summary = thread.summary {
            #expect(!summary.contains("PRIVATE-TRAIL-SENTINEL"))
        }
        // No engagement's title or note contains the sentinel.
        for engagement in thread.engagements {
            #expect(!engagement.contentTitle.contains("PRIVATE-TRAIL-SENTINEL"))
            if let note = engagement.note {
                #expect(!note.contains("PRIVATE-TRAIL-SENTINEL"))
            }
        }
        // The root's own reflection link is preserved (correct — reflection
        // is the engagement's, not the thread's). The body lives on
        // ReflectionEntry, which the Rabbit Hole surface does not render.
        #expect(root.reflection?.body == "PRIVATE-TRAIL-SENTINEL-XYZ")
    }

    // MARK: - Single transaction

    @Test("Materialize persists everything in a single context save")
    func materializeSingleTransactionPersists() throws {
        let context = try makeContext()
        let response = makeResponse(steps: [
            makeStep(type: "article", title: "a"),
            makeStep(type: "video",   title: "b"),
        ])
        _ = AITrailMaterializer.materialize(
            response: response,
            root: nil,
            into: context,
            now: now
        )

        // No explicit context.save() in the test; the materializer
        // committed. A fresh fetch sees the row counts.
        let threadCount = try context.fetchCount(FetchDescriptor<RabbitHoleThread>())
        let engagementCount = try context.fetchCount(FetchDescriptor<CuriosityEngagement>())
        #expect(threadCount == 1)
        #expect(engagementCount == 2)
    }

    // MARK: - Schema additions (seedTopic, seedPrompt)

    @Test("RabbitHoleThread.seedTopic and seedPrompt default to nil")
    func schemaSeedFieldsDefaultNil() {
        let thread = RabbitHoleThread()
        #expect(thread.seedTopic == nil)
        #expect(thread.seedPrompt == nil)
    }

    @Test("RabbitHoleThread seed relationships round-trip via SwiftData")
    func schemaSeedFieldsRoundTrip() throws {
        let context = try makeContext()

        let topic = CuriosityTopic()
        topic.slug = "rt-topic"
        topic.title = "Round Trip Topic"
        context.insert(topic)

        let prompt = CuriosityPrompt()
        prompt.slug = "rt-prompt"
        prompt.body = "round trip prompt body"
        prompt.topic = topic
        context.insert(prompt)

        let thread = RabbitHoleThread()
        thread.title = "rt-thread"
        thread.statusRaw = ThreadStatus.open.rawValue
        thread.seedTopic = topic
        thread.seedPrompt = prompt
        context.insert(thread)
        try context.save()

        let fetched = try #require(
            try context.fetch(FetchDescriptor<RabbitHoleThread>()).first
        )
        #expect(fetched.seedTopic?.slug == "rt-topic")
        #expect(fetched.seedPrompt?.slug == "rt-prompt")
    }
}
