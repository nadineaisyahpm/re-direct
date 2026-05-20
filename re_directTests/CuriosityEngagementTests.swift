import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("CuriosityEngagement")
struct CuriosityEngagementTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func registeredInSchema() throws {
        let context = try makeContext()
        let row = CuriosityEngagement()
        row.methodSlug = "read"
        row.contentTitle = "Smoke"
        context.insert(row)
        try context.save()

        let count = try context.fetchCount(FetchDescriptor<CuriosityEngagement>())
        #expect(count == 1)
    }

    @Test func roundTripPersistsAllFields() throws {
        let context = try makeContext()
        let engagedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let row = CuriosityEngagement()
        row.methodSlug = "watch"
        row.contentTitle = "Why blue glow?"
        row.sourceURL = "https://example.com/glow"
        row.engagedAt = engagedAt
        row.durationSeconds = 540
        row.note = "loved the part about whales"
        context.insert(row)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CuriosityEngagement>())
        #expect(fetched.count == 1)
        let r = try #require(fetched.first)
        #expect(r.methodSlug == "watch")
        #expect(r.contentTitle == "Why blue glow?")
        #expect(r.sourceURL == "https://example.com/glow")
        #expect(r.engagedAt == engagedAt)
        #expect(r.durationSeconds == 540)
        #expect(r.note == "loved the part about whales")
        #expect(r.deletedAt == nil)
        #expect(r.topic == nil)
        #expect(r.prompt == nil)
        #expect(r.session == nil)
    }

    @Test func filterByMethodSlugReturnsOnlyMatching() throws {
        let context = try makeContext()
        for slug in ["watch", "read", "watch", "reflect"] {
            let row = CuriosityEngagement()
            row.methodSlug = slug
            row.contentTitle = "row-\(slug)"
            context.insert(row)
        }
        try context.save()

        let target = "watch"
        let descriptor = FetchDescriptor<CuriosityEngagement>(
            predicate: #Predicate { $0.methodSlug == target }
        )
        let rows = try context.fetch(descriptor)
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.methodSlug == "watch" })
    }

    @Test func softDeleteExcludesRowsFromDefaultQueries() throws {
        let context = try makeContext()
        let live = CuriosityEngagement()
        live.methodSlug = "read"
        live.contentTitle = "still here"
        context.insert(live)

        let gone = CuriosityEngagement()
        gone.methodSlug = "read"
        gone.contentTitle = "tombstone"
        gone.deletedAt = Date()
        context.insert(gone)

        try context.save()

        let visible = try context.fetch(
            FetchDescriptor<CuriosityEngagement>(
                predicate: #Predicate { $0.deletedAt == nil }
            )
        )
        #expect(visible.count == 1)
        #expect(visible.first?.contentTitle == "still here")
    }

    @Test func optionalRelationshipsCanBeNilOrSet() throws {
        let context = try makeContext()

        let topic = CuriosityTopic()
        topic.slug = "bioluminescence-test"
        topic.title = "Bioluminescence"
        context.insert(topic)

        let prompt = CuriosityPrompt()
        prompt.slug = "deep-sea-glow-test"
        prompt.body = "Why blue?"
        prompt.topic = topic
        context.insert(prompt)

        let session = TimerSession()
        session.startedAt = Date()
        session.plannedMinutes = 25
        context.insert(session)

        let withLinks = CuriosityEngagement()
        withLinks.methodSlug = "read"
        withLinks.contentTitle = "linked"
        withLinks.topic = topic
        withLinks.prompt = prompt
        withLinks.session = session
        context.insert(withLinks)

        let bare = CuriosityEngagement()
        bare.methodSlug = "read"
        bare.contentTitle = "bare"
        context.insert(bare)

        try context.save()

        let fetched = try context.fetch(
            FetchDescriptor<CuriosityEngagement>(
                sortBy: [SortDescriptor(\.contentTitle)]
            )
        )
        #expect(fetched.count == 2)
        let bareFetched = try #require(fetched.first { $0.contentTitle == "bare" })
        #expect(bareFetched.topic == nil)
        #expect(bareFetched.prompt == nil)
        #expect(bareFetched.session == nil)

        let linkedFetched = try #require(fetched.first { $0.contentTitle == "linked" })
        #expect(linkedFetched.topic?.slug == "bioluminescence-test")
        #expect(linkedFetched.prompt?.slug == "deep-sea-glow-test")
        #expect(linkedFetched.session?.plannedMinutes == 25)
    }
}
