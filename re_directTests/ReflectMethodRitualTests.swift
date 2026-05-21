import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("ReflectMethodRitual")
struct ReflectMethodRitualTests {

    // MARK: helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makePrompt(slug: String,
                            body: String = "b",
                            context: String?,
                            deletedAt: Date? = nil) -> ReflectionPrompt {
        let p = ReflectionPrompt()
        p.slug = slug
        p.body = body
        p.context = context
        p.deletedAt = deletedAt
        return p
    }

    private func fetchEngagements(_ context: ModelContext) throws -> [CuriosityEngagement] {
        try context.fetch(FetchDescriptor<CuriosityEngagement>())
    }

    private func fetchReflections(_ context: ModelContext) throws -> [ReflectionEntry] {
        try context.fetch(FetchDescriptor<ReflectionEntry>())
    }

    // MARK: prompt selection priority

    @Test func prefersReflectMethodContext() throws {
        let prompts = [
            makePrompt(slug: "r1", context: "reflect-method"),
            makePrompt(slug: "u1", context: nil),
            makePrompt(slug: "p1", context: "post-ritual")
        ]
        let selection = ReflectMethodRitualHelpers.choosePrompt(
            from: prompts,
            pickIndex: { _ in 0 }
        )
        if case .seeded(let p) = selection {
            #expect(p.slug == "r1")
        } else {
            Issue.record("Expected .seeded but got \(selection)")
        }
    }

    @Test func fallsBackToUntaggedWhenNoReflectMethod() throws {
        let prompts = [
            makePrompt(slug: "u1", context: nil),
            makePrompt(slug: "p1", context: "post-ritual")
        ]
        let selection = ReflectMethodRitualHelpers.choosePrompt(
            from: prompts,
            pickIndex: { _ in 0 }
        )
        if case .seeded(let p) = selection {
            #expect(p.slug == "u1")
        } else {
            Issue.record("Expected .seeded(u1) but got \(selection)")
        }
    }

    @Test func fallsBackToHardcodedWhenPoolIsEmpty() throws {
        let selection = ReflectMethodRitualHelpers.choosePrompt(
            from: [],
            pickIndex: { _ in 0 }
        )
        if case .fallback(let body) = selection {
            #expect(body == ReflectMethodRitualHelpers.fallbackBody)
        } else {
            Issue.record("Expected .fallback but got \(selection)")
        }
    }

    @Test func ignoresSoftDeletedPrompts() throws {
        let prompts = [
            makePrompt(slug: "r1", context: "reflect-method", deletedAt: Date()),
            makePrompt(slug: "u1", context: nil)
        ]
        let selection = ReflectMethodRitualHelpers.choosePrompt(
            from: prompts,
            pickIndex: { _ in 0 }
        )
        if case .seeded(let p) = selection {
            #expect(p.slug == "u1")
        } else {
            Issue.record("Expected untagged after filtering soft-deleted; got \(selection)")
        }
    }

    @Test func ignoresPostRitualOnlyPool() throws {
        let prompts = [
            makePrompt(slug: "p1", context: "post-ritual"),
            makePrompt(slug: "p2", context: "post-ritual")
        ]
        let selection = ReflectMethodRitualHelpers.choosePrompt(
            from: prompts,
            pickIndex: { _ in 0 }
        )
        // No reflect-method, no untagged → fallback.
        if case .fallback = selection {} else {
            Issue.record("Expected .fallback when only post-ritual is available; got \(selection)")
        }
    }

    // MARK: save semantics

    @Test func emptyBodyDoesNotWrite() throws {
        let context = try makeContext()
        let result = ReflectMethodRitualHelpers.performSave(
            body: "   \n  ",
            prompt: .fallback("p"),
            session: nil,
            in: context
        )
        #expect(result == nil)
        #expect(try fetchEngagements(context).isEmpty)
        #expect(try fetchReflections(context).isEmpty)
    }

    @Test func nonEmptySaveDualWritesLinkedRows() throws {
        let context = try makeContext()
        let prompt = makePrompt(slug: "r1", body: "what stayed with you?", context: "reflect-method")
        context.insert(prompt)
        try context.save()

        let result = ReflectMethodRitualHelpers.performSave(
            body: "  it was the cold air on the way home.  ",
            prompt: .seeded(prompt),
            session: nil,
            in: context
        )

        let written = try #require(result)
        #expect(written.entry.body == "it was the cold air on the way home.")
        #expect(written.engagement.methodSlug == "reflect")
        #expect(written.engagement.contentTitle == "what stayed with you?")
        #expect(written.engagement.reflection?.id == written.entry.id)

        let engagements = try fetchEngagements(context)
        let reflections = try fetchReflections(context)
        #expect(engagements.count == 1)
        #expect(reflections.count == 1)
        #expect(engagements.first?.reflection?.body == "it was the cold air on the way home.")
    }

    @Test func sessionLinkPropagatesToBothRows() throws {
        let context = try makeContext()
        let session = TimerSession()
        session.startedAt = .now
        session.plannedMinutes = 25
        context.insert(session)
        try context.save()

        let result = ReflectMethodRitualHelpers.performSave(
            body: "five things i noticed today.",
            prompt: .fallback("take a minute."),
            session: session,
            in: context
        )

        let written = try #require(result)
        #expect(written.entry.session?.id == session.id)
        #expect(written.engagement.session?.id == session.id)
    }

    @Test func fallbackPromptIsUsedAsContentTitle() throws {
        let context = try makeContext()
        let result = ReflectMethodRitualHelpers.performSave(
            body: "ok.",
            prompt: .fallback("custom fallback prompt"),
            session: nil,
            in: context
        )
        let written = try #require(result)
        #expect(written.engagement.contentTitle == "custom fallback prompt")
    }
}
