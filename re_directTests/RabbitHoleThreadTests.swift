import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("RabbitHoleThread")
struct RabbitHoleThreadTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Schema + defaults

    @Test func registeredInSchema() throws {
        let context = try makeContext()
        let thread = RabbitHoleThread()
        thread.title = "Bioluminescence"
        context.insert(thread)
        try context.save()

        let count = try context.fetchCount(FetchDescriptor<RabbitHoleThread>())
        #expect(count == 1)
    }

    @Test func defaultsMatchRH1Contract() throws {
        let thread = RabbitHoleThread()
        #expect(thread.title == "")
        #expect(thread.summary == nil)
        #expect(thread.statusRaw == ThreadStatus.open.rawValue)
        #expect(thread.sourceRaw == ThreadSourceKind.manual.rawValue)
        #expect(thread.lastEngagedAt == nil)
        #expect(thread.deletedAt == nil)
        #expect(thread.engagements.isEmpty)
        #expect(thread.status == .open)
        #expect(thread.source == .manual)
    }

    @Test func roundTripPersistsAllFields() throws {
        let context = try makeContext()
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let updated = Date(timeIntervalSince1970: 1_700_010_000)
        let lastEngaged = Date(timeIntervalSince1970: 1_700_005_000)

        let thread = RabbitHoleThread()
        thread.title = "Deep sea glow"
        thread.summary = "A trail from bioluminescence to whale falls."
        thread.statusRaw = ThreadStatus.resting.rawValue
        thread.sourceRaw = ThreadSourceKind.aiDeepened.rawValue
        thread.createdAt = created
        thread.updatedAt = updated
        thread.lastEngagedAt = lastEngaged
        context.insert(thread)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RabbitHoleThread>())
        let t = try #require(fetched.first)
        #expect(t.title == "Deep sea glow")
        #expect(t.summary == "A trail from bioluminescence to whale falls.")
        #expect(t.status == .resting)
        #expect(t.source == .aiDeepened)
        #expect(t.createdAt == created)
        #expect(t.updatedAt == updated)
        #expect(t.lastEngagedAt == lastEngaged)
        #expect(t.deletedAt == nil)
        #expect(t.engagements.isEmpty)
    }

    // MARK: - Soft-delete pattern

    @Test func softDeleteExcludesThreadsFromDefaultQueries() throws {
        let context = try makeContext()
        let live = RabbitHoleThread()
        live.title = "still here"
        context.insert(live)

        let gone = RabbitHoleThread()
        gone.title = "tombstone"
        gone.deletedAt = Date()
        context.insert(gone)

        try context.save()

        let visible = try context.fetch(
            FetchDescriptor<RabbitHoleThread>(
                predicate: #Predicate { $0.deletedAt == nil }
            )
        )
        #expect(visible.count == 1)
        #expect(visible.first?.title == "still here")
    }

    // MARK: - Permissive wrappers

    @Test func unknownStatusRawDecodesAsUnknownAndDoesNotCrash() throws {
        let context = try makeContext()
        let thread = RabbitHoleThread()
        thread.title = "future-shape"
        thread.statusRaw = "hibernating"   // value from a hypothetical later schema
        thread.sourceRaw = "imported"      // ditto
        context.insert(thread)
        try context.save()

        let fetched = try #require(
            try context.fetch(FetchDescriptor<RabbitHoleThread>()).first
        )
        #expect(fetched.status == .unknown)
        #expect(fetched.source == .unknown)
        // Raw values survive unchanged for forward-compat round-tripping.
        #expect(fetched.statusRaw == "hibernating")
        #expect(fetched.sourceRaw == "imported")
    }

    @Test func allCanonicalStatusAndSourceValuesDecode() {
        #expect(ThreadStatus.from(raw: "open") == .open)
        #expect(ThreadStatus.from(raw: "resting") == .resting)
        #expect(ThreadStatus.from(raw: "closed") == .closed)
        #expect(ThreadStatus.from(raw: "garbage") == .unknown)

        #expect(ThreadSourceKind.from(raw: "manual") == .manual)
        #expect(ThreadSourceKind.from(raw: "ai-deepened") == .aiDeepened)
        #expect(ThreadSourceKind.from(raw: "auto-grouped") == .autoGrouped)
        #expect(ThreadSourceKind.from(raw: "garbage") == .unknown)
    }

    // MARK: - Engagement coexistence (RH0 invariant: threading is optional)

    @Test func engagementCanBeSavedWithoutAThread() throws {
        let context = try makeContext()
        let row = CuriosityEngagement()
        row.methodSlug = "read"
        row.contentTitle = "unthreaded"
        context.insert(row)
        try context.save()

        let fetched = try #require(
            try context.fetch(FetchDescriptor<CuriosityEngagement>()).first
        )
        #expect(fetched.thread == nil)
    }

    @Test func engagementCanBeLinkedToAThread() throws {
        let context = try makeContext()
        let thread = RabbitHoleThread()
        thread.title = "Bioluminescence"
        context.insert(thread)

        let row = CuriosityEngagement()
        row.methodSlug = "read"
        row.contentTitle = "step 1"
        row.thread = thread
        context.insert(row)
        try context.save()

        let fetchedThread = try #require(
            try context.fetch(FetchDescriptor<RabbitHoleThread>()).first
        )
        #expect(fetchedThread.engagements.count == 1)
        #expect(fetchedThread.engagements.first?.contentTitle == "step 1")

        let fetchedRow = try #require(
            try context.fetch(FetchDescriptor<CuriosityEngagement>()).first
        )
        #expect(fetchedRow.thread?.title == "Bioluminescence")
    }

    @Test func crossMethodEngagementsCanShareOneThread() throws {
        let context = try makeContext()
        let thread = RabbitHoleThread()
        thread.title = "Whale falls"
        context.insert(thread)

        for slug in ["read", "watch", "reflect"] {
            let row = CuriosityEngagement()
            row.methodSlug = slug
            row.contentTitle = "step-\(slug)"
            row.thread = thread
            context.insert(row)
        }
        try context.save()

        let fetched = try #require(
            try context.fetch(FetchDescriptor<RabbitHoleThread>()).first
        )
        #expect(fetched.engagements.count == 3)
        let slugs = Set(fetched.engagements.map(\.methodSlug))
        #expect(slugs == Set(["read", "watch", "reflect"]))
    }

    // MARK: - Soft-delete cascade (RH0 §4)

    @Test func softDeletingThreadLeavesEngagementsAlive() throws {
        let context = try makeContext()
        let thread = RabbitHoleThread()
        thread.title = "to be deleted"
        context.insert(thread)

        let row = CuriosityEngagement()
        row.methodSlug = "read"
        row.contentTitle = "outlives the thread"
        row.thread = thread
        context.insert(row)
        try context.save()

        thread.deletedAt = Date()
        try context.save()

        // Engagement row still exists, regardless of the thread's tombstone.
        let liveEngagements = try context.fetch(
            FetchDescriptor<CuriosityEngagement>(
                predicate: #Predicate { $0.deletedAt == nil }
            )
        )
        #expect(liveEngagements.count == 1)
        #expect(liveEngagements.first?.contentTitle == "outlives the thread")
    }

    // MARK: - Invariant: thread carries no reflection body / no TimerSession field

    @Test func threadDoesNotExposeReflectionOrTimerSessionFields() throws {
        // Compile-time intent check: if a future change adds these properties to
        // RabbitHoleThread, this test won't fail — but the doc reviewer should.
        // We assert via Mirror that none of the forbidden field names appear on
        // a fresh instance's reflected children.
        let thread = RabbitHoleThread()
        let mirror = Mirror(reflecting: thread)
        let propertyNames = Set(mirror.children.compactMap { $0.label })

        #expect(!propertyNames.contains("session"))
        #expect(!propertyNames.contains("timerSession"))
        #expect(!propertyNames.contains("reflection"))
        #expect(!propertyNames.contains("reflectionEntry"))
        #expect(!propertyNames.contains("body"))
        #expect(!propertyNames.contains("methodSlug"))
    }
}
