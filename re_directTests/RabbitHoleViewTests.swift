import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import re_direct

@MainActor
@Suite("RabbitHoleView (RH3-B + RH3-C + RH3-D)")
struct RabbitHoleViewTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // ─────────────────────────────────────────
    // MARK: RH3-B: Tab configuration
    // ─────────────────────────────────────────

    @Test("Tab 1 is the Rabbit Hole entry")
    func tabOneIsRabbitHole() {
        let entry = SharedNavBar.tabs[1]
        #expect(entry.icon == "arrow.turn.down.right")
        #expect(entry.label == "rabbit hole")
    }

    @Test("Tabs 0, 2, 3, 4 are unchanged from the pre-RH3-B array")
    func surroundingTabsUnchanged() {
        #expect(SharedNavBar.tabs[0].icon  == "leaf.fill")
        #expect(SharedNavBar.tabs[0].label == "home")

        #expect(SharedNavBar.tabs[2].icon  == "hourglass")
        #expect(SharedNavBar.tabs[2].label == "usage")

        #expect(SharedNavBar.tabs[3].icon  == "waveform.path.ecg")
        #expect(SharedNavBar.tabs[3].label == "re:log")

        #expect(SharedNavBar.tabs[4].icon  == "gearshape.fill")
        #expect(SharedNavBar.tabs[4].label == "settings")
    }

    @Test("Tabs array has exactly 5 entries")
    func tabsArrayHasFiveEntries() {
        #expect(SharedNavBar.tabs.count == 5)
    }

    // ─────────────────────────────────────────
    // MARK: RH3-B: Empty-state copy
    // ─────────────────────────────────────────

    @Test("Empty-state headline matches the design extraction")
    func emptyStateHeadline() {
        #expect(RabbitHoleEmptyCopy.headline == "no threads yet.")
    }

    @Test("Empty-state sub describes the thread origin honestly")
    func emptyStateSub() {
        #expect(RabbitHoleEmptyCopy.sub.contains("already logged"))
    }

    @Test("Empty-state CTA copy")
    func emptyStateCTA() {
        #expect(RabbitHoleEmptyCopy.cta == "start your first thread")
    }

    @Test("Loose-only caption copy")
    func looseOnlyCaption() {
        #expect(RabbitHoleEmptyCopy.looseCaption == "these could become threads.")
    }

    @Test("Empty-state copy strings are all non-empty")
    func emptyStateCopyNonEmpty() {
        #expect(!RabbitHoleEmptyCopy.headline.isEmpty)
        #expect(!RabbitHoleEmptyCopy.sub.isEmpty)
        #expect(!RabbitHoleEmptyCopy.cta.isEmpty)
        #expect(!RabbitHoleEmptyCopy.looseCaption.isEmpty)
    }

    // ─────────────────────────────────────────
    // MARK: RH3-B/C: View construction smoke
    // ─────────────────────────────────────────

    @Test("RabbitHoleView constructs without crashing")
    func viewConstructsCleanly() throws {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        _ = RabbitHoleView()
            .modelContainer(container)
            .environment(ActiveMethodStore())
    }

    // ─────────────────────────────────────────
    // MARK: RH3-C: Mode resolver
    // ─────────────────────────────────────────

    @Test("Mode is .empty when both lists are empty")
    func modeEmpty() {
        #expect(RabbitHoleMode.resolve(threadCount: 0, looseCount: 0) == .empty)
    }

    @Test("Mode is .looseOnly when threads are empty but loose ends exist")
    func modeLooseOnly() {
        #expect(RabbitHoleMode.resolve(threadCount: 0, looseCount: 1) == .looseOnly)
        #expect(RabbitHoleMode.resolve(threadCount: 0, looseCount: 7) == .looseOnly)
    }

    @Test("Mode is .populated whenever any thread exists")
    func modePopulated() {
        #expect(RabbitHoleMode.resolve(threadCount: 1, looseCount: 0) == .populated)
        #expect(RabbitHoleMode.resolve(threadCount: 1, looseCount: 3) == .populated)
        #expect(RabbitHoleMode.resolve(threadCount: 9, looseCount: 9) == .populated)
    }

    // ─────────────────────────────────────────
    // MARK: RH3-C: Step count formatter
    // ─────────────────────────────────────────

    @Test("Step count plural rule")
    func stepCountPlural() {
        #expect(ThreadStepCount.display(0)   == "0 steps")
        #expect(ThreadStepCount.display(1)   == "1 step")
        #expect(ThreadStepCount.display(2)   == "2 steps")
        #expect(ThreadStepCount.display(100) == "100 steps")
    }

    // ─────────────────────────────────────────
    // MARK: RH3-C: Overflow copy
    // ─────────────────────────────────────────

    @Test("Overflow returns nil when count is zero or negative")
    func overflowNilWhenNone() {
        #expect(ThreadOverflowCopy.display(0)  == nil)
        #expect(ThreadOverflowCopy.display(-5) == nil)
    }

    @Test("Overflow uses singular arc for n == 1")
    func overflowSingular() {
        #expect(ThreadOverflowCopy.display(1) == "and 1 more arc")
    }

    @Test("Overflow uses plural arcs for n > 1")
    func overflowPlural() {
        #expect(ThreadOverflowCopy.display(2)   == "and 2 more arcs")
        #expect(ThreadOverflowCopy.display(100) == "and 100 more arcs")
    }

    // ─────────────────────────────────────────
    // MARK: RH3-C: Color palette
    // ─────────────────────────────────────────

    @Test("Card hex falls back to paper cream when no slug provided")
    func cardHexFallbackOnNilSlug() {
        #expect(RabbitHoleColorPalette.cardHex(forActiveSlug: nil) == "#FFFDF2")
    }

    @Test("Card hex falls back to paper cream when slug unrecognized")
    func cardHexFallbackOnUnknownSlug() {
        #expect(RabbitHoleColorPalette.cardHex(forActiveSlug: "no-such-method") == "#FFFDF2")
    }

    @Test("Card hex resolves each canonical method slug to its RedirectRitual hex")
    func cardHexAllCanonicalSlugs() {
        // These pin the mapping against `RedirectRitual.samples` so that
        // any future visual change to the lane palette must also pass
        // here — the today card and the re:tuals card stay in sync.
        let expectations: [(slug: String, hex: String)] = [
            ("watch",     "#B8A8B0"),
            ("read",      "#1B4D4A"),
            ("mini-game", "#C8B898"),
            ("deep-dive", "#2C2F3A"),
            ("reflect",   "#D4C4B8"),
        ]
        for (slug, hex) in expectations {
            #expect(RabbitHoleColorPalette.cardHex(forActiveSlug: slug) == hex,
                    "Expected \(slug) → \(hex)")
        }
    }

    @Test("Light-text rule matches the RitualSwipeCard mauve/teal/slate set")
    func usesLightTextRule() {
        #expect(RabbitHoleColorPalette.usesLightText(forHex: "#B8A8B0"))
        #expect(RabbitHoleColorPalette.usesLightText(forHex: "#1B4D4A"))
        #expect(RabbitHoleColorPalette.usesLightText(forHex: "#2C2F3A"))
    }

    @Test("Light-text rule is false for cream / sandy / cocoa lanes")
    func usesLightTextFalseOnLightBackgrounds() {
        #expect(!RabbitHoleColorPalette.usesLightText(forHex: "#C8B898"))
        #expect(!RabbitHoleColorPalette.usesLightText(forHex: "#D4C4B8"))
        #expect(!RabbitHoleColorPalette.usesLightText(forHex: "#FFFDF2"))
    }

    // ─────────────────────────────────────────
    // MARK: RH3-C: Engagement preview model — privacy invariant
    // ─────────────────────────────────────────

    @Test("EngagementPreviewRowModel has only safe display fields")
    func previewRowModelStructurallyExcludesPrivateFields() {
        // Compile-time check enforced by Mirror inspection: the model's
        // stored property labels are exactly the safe-to-display set.
        // If a future change adds a property here, this fails and we
        // re-examine whether the new field could leak private data.
        let model = EngagementPreviewRowModel(
            id: UUID(),
            title: "t",
            methodSlug: "read",
            dateCaption: "earlier today"
        )
        let labels = Set(Mirror(reflecting: model).children.compactMap { $0.label })
        #expect(labels == Set(["id", "title", "methodSlug", "dateCaption"]))
        #expect(!labels.contains("body"))
        #expect(!labels.contains("reflection"))
        #expect(!labels.contains("reflectionBody"))
    }

    @Test("EngagementPreviewRowModel from CuriosityEngagement does not carry reflection body")
    func previewRowModelDropsReflectionBody() throws {
        let context = try makeContext()

        let reflection = ReflectionEntry()
        reflection.mood = "curious"
        reflection.body = "PRIVATE-REFLECTION-SENTINEL-A"
        context.insert(reflection)

        let engagement = CuriosityEngagement()
        engagement.methodSlug = "reflect"
        engagement.contentTitle = "Quiet five minutes about whales"
        engagement.note = "user-typed note, not a reflection body"
        engagement.reflection = reflection
        context.insert(engagement)
        try context.save()

        let model = EngagementPreviewRowModel(engagement)

        // Title, slug, date caption are populated.
        #expect(model.title == "Quiet five minutes about whales")
        #expect(model.methodSlug == "reflect")
        #expect(!model.dateCaption.isEmpty)

        // The reflection body sentinel must NOT appear anywhere on the
        // displayable model. We assert on every stored String property
        // via Mirror so a future field addition is caught.
        let stringValues: [String] = Mirror(reflecting: model)
            .children
            .compactMap { $0.value as? String }
        for value in stringValues {
            #expect(!value.contains("PRIVATE-REFLECTION-SENTINEL"),
                    "Reflection body leaked into model: \(value)")
        }
    }

    // ─────────────────────────────────────────
    // MARK: RH3-C: SwiftData queries — schema-side predicates
    // ─────────────────────────────────────────

    @Test("Thread predicate excludes deleted threads")
    func threadPredicateExcludesDeleted() throws {
        let context = try makeContext()

        let live = RabbitHoleThread()
        live.title = "live"
        live.statusRaw = ThreadStatus.open.rawValue
        live.lastEngagedAt = Date()
        context.insert(live)

        let gone = RabbitHoleThread()
        gone.title = "tombstone"
        gone.statusRaw = ThreadStatus.open.rawValue
        gone.deletedAt = Date()
        context.insert(gone)
        try context.save()

        let descriptor = FetchDescriptor<RabbitHoleThread>(
            predicate: #Predicate { $0.deletedAt == nil && $0.statusRaw != "closed" },
            sortBy: [SortDescriptor(\.lastEngagedAt, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "live")
    }

    @Test("Thread predicate excludes closed threads")
    func threadPredicateExcludesClosed() throws {
        let context = try makeContext()

        let open = RabbitHoleThread()
        open.title = "open"
        open.statusRaw = ThreadStatus.open.rawValue
        context.insert(open)

        let resting = RabbitHoleThread()
        resting.title = "resting"
        resting.statusRaw = ThreadStatus.resting.rawValue
        context.insert(resting)

        let closed = RabbitHoleThread()
        closed.title = "closed"
        closed.statusRaw = ThreadStatus.closed.rawValue
        context.insert(closed)

        try context.save()

        let descriptor = FetchDescriptor<RabbitHoleThread>(
            predicate: #Predicate { $0.deletedAt == nil && $0.statusRaw != "closed" }
        )
        let fetched = try context.fetch(descriptor)
        let titles = Set(fetched.map(\.title))
        #expect(titles == Set(["open", "resting"]))
    }

    @Test("Loose-end predicate matches engagements where thread is nil")
    func looseEndPredicate() throws {
        let context = try makeContext()

        let thread = RabbitHoleThread()
        thread.title = "Bioluminescence"
        context.insert(thread)

        let threaded = CuriosityEngagement()
        threaded.methodSlug = "read"
        threaded.contentTitle = "in a thread"
        threaded.thread = thread
        context.insert(threaded)

        let loose = CuriosityEngagement()
        loose.methodSlug = "read"
        loose.contentTitle = "wandering"
        context.insert(loose)

        let alsoLoose = CuriosityEngagement()
        alsoLoose.methodSlug = "watch"
        alsoLoose.contentTitle = "also wandering"
        context.insert(alsoLoose)

        try context.save()

        let descriptor = FetchDescriptor<CuriosityEngagement>(
            predicate: #Predicate { $0.deletedAt == nil && $0.thread == nil },
            sortBy: [SortDescriptor(\.engagedAt, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)
        let titles = Set(fetched.map(\.contentTitle))
        #expect(titles == Set(["wandering", "also wandering"]))
    }

    // ─────────────────────────────────────────
    // MARK: RH3-C: Partitioning logic (pure)
    // ─────────────────────────────────────────

    @Test("Today + list partition keeps first thread as today, next 3 as list")
    func partitionTodayAndList() {
        // Simulate the partition logic: today = first, list = next 3.
        let titles = ["a", "b", "c", "d", "e", "f"]
        let today = titles.first
        let list = Array(titles.dropFirst().prefix(3))
        let overflow = max(0, titles.count - 4)

        #expect(today == "a")
        #expect(list == ["b", "c", "d"])
        #expect(overflow == 2)
    }

    @Test("Partition produces empty list and zero overflow at single thread")
    func partitionSingle() {
        let titles = ["only"]
        let today = titles.first
        let list = Array(titles.dropFirst().prefix(3))
        let overflow = max(0, titles.count - 4)

        #expect(today == "only")
        #expect(list.isEmpty)
        #expect(overflow == 0)
    }

    @Test("Partition produces zero overflow at exactly four threads")
    func partitionFourThreads() {
        let titles = ["a", "b", "c", "d"]
        let overflow = max(0, titles.count - 4)
        #expect(overflow == 0)
    }

    // ─────────────────────────────────────────
    // MARK: RH3-C: Engagement display cap (memory guard)
    // ─────────────────────────────────────────

    @Test("Engagement display cap is a sane bounded value")
    func engagementDisplayCapBounded() {
        // The exact value can move; we just enforce that it stays a
        // small fixed bound and that it's positive. This guards against
        // a future refactor accidentally setting it to .max or zero.
        #expect(ThreadPreviewSheet.engagementDisplayCap > 0)
        #expect(ThreadPreviewSheet.engagementDisplayCap <= 100)
    }

    @Test("Overflow footnote describes shown vs total honestly")
    func overflowFootnoteCopy() {
        let copy = ThreadPreviewSheet.overflowFootnote(shown: 25, total: 73)
        #expect(copy.contains("25"))
        #expect(copy.contains("73"))
    }

    // ─────────────────────────────────────────
    // MARK: RH3-D: Input validator
    // ─────────────────────────────────────────

    @Test("Empty title sanitizes to nil")
    func validatorEmptyTitleNil() {
        #expect(NewThreadInputValidator.sanitizedTitle("") == nil)
    }

    @Test("Whitespace-only title sanitizes to nil")
    func validatorWhitespaceTitleNil() {
        #expect(NewThreadInputValidator.sanitizedTitle("   ") == nil)
        #expect(NewThreadInputValidator.sanitizedTitle("\t\n\n") == nil)
        #expect(NewThreadInputValidator.sanitizedTitle("  \r\n  ") == nil)
    }

    @Test("Title with content survives sanitization, trimmed on both sides")
    func validatorTitleTrims() {
        #expect(NewThreadInputValidator.sanitizedTitle("Bioluminescence") == "Bioluminescence")
        #expect(NewThreadInputValidator.sanitizedTitle("   leading spaces") == "leading spaces")
        #expect(NewThreadInputValidator.sanitizedTitle("trailing spaces   ") == "trailing spaces")
        #expect(NewThreadInputValidator.sanitizedTitle("  both  sides  ") == "both  sides")
    }

    @Test("isValidTitle mirrors sanitizedTitle non-nil")
    func validatorIsValidMatchesSanitize() {
        #expect(!NewThreadInputValidator.isValidTitle(""))
        #expect(!NewThreadInputValidator.isValidTitle("   "))
        #expect(NewThreadInputValidator.isValidTitle("x"))
        #expect(NewThreadInputValidator.isValidTitle("  x  "))
    }

    @Test("Empty summary sanitizes to nil")
    func validatorEmptySummaryNil() {
        #expect(NewThreadInputValidator.sanitizedSummary("") == nil)
        #expect(NewThreadInputValidator.sanitizedSummary("   ") == nil)
    }

    @Test("Summary trims both sides")
    func validatorSummaryTrims() {
        #expect(NewThreadInputValidator.sanitizedSummary("a short summary") == "a short summary")
        #expect(NewThreadInputValidator.sanitizedSummary("  trimmed  ") == "trimmed")
    }

    // ─────────────────────────────────────────
    // MARK: RH3-D: Inserter
    // ─────────────────────────────────────────

    @Test("Insert with valid title creates exactly one thread")
    func inserterCreatesOneThread() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let result = NewThreadInserter.insert(
            title: "Deep-sea bioluminescence",
            summary: nil,
            into: context,
            now: now
        )
        try context.save()

        #expect(result != nil)
        let count = try context.fetchCount(FetchDescriptor<RabbitHoleThread>())
        #expect(count == 1)
    }

    @Test("Insert sets defaults: status open, sourceKind manual, timestamps")
    func inserterSetsDefaults() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let thread = try #require(
            NewThreadInserter.insert(
                title: "x",
                summary: nil,
                into: context,
                now: now
            )
        )

        #expect(thread.status == .open)
        #expect(thread.source == .manual)
        #expect(thread.statusRaw == "open")
        #expect(thread.sourceRaw == "manual")
        #expect(thread.createdAt == now)
        #expect(thread.updatedAt == now)
        #expect(thread.lastEngagedAt == now)
        #expect(thread.deletedAt == nil)
    }

    @Test("Insert trims title and writes the trimmed value")
    func inserterTrimsTitle() throws {
        let context = try makeContext()
        let thread = try #require(
            NewThreadInserter.insert(
                title: "   Whales and falls   ",
                summary: nil,
                into: context
            )
        )
        #expect(thread.title == "Whales and falls")
    }

    @Test("Insert with nil summary leaves summary nil")
    func inserterNilSummary() throws {
        let context = try makeContext()
        let thread = try #require(
            NewThreadInserter.insert(
                title: "x",
                summary: nil,
                into: context
            )
        )
        #expect(thread.summary == nil)
    }

    @Test("Insert with empty / whitespace summary stores nil")
    func inserterEmptySummaryBecomesNil() throws {
        let context = try makeContext()
        let thread = try #require(
            NewThreadInserter.insert(
                title: "x",
                summary: "    ",
                into: context
            )
        )
        #expect(thread.summary == nil)
    }

    @Test("Insert with non-empty summary stores trimmed value")
    func inserterSummaryTrimmed() throws {
        let context = try makeContext()
        let thread = try #require(
            NewThreadInserter.insert(
                title: "x",
                summary: "  a real summary  ",
                into: context
            )
        )
        #expect(thread.summary == "a real summary")
    }

    @Test("Insert with whitespace-only title returns nil and creates nothing")
    func inserterRejectsBlankTitle() throws {
        let context = try makeContext()

        let result = NewThreadInserter.insert(
            title: "    ",
            summary: "should not save",
            into: context
        )
        try context.save()

        #expect(result == nil)
        let count = try context.fetchCount(FetchDescriptor<RabbitHoleThread>())
        #expect(count == 0)
    }

    @Test("Insert does not create or attach any engagements")
    func inserterCreatesNoEngagements() throws {
        let context = try makeContext()

        let thread = try #require(
            NewThreadInserter.insert(
                title: "x",
                summary: nil,
                into: context
            )
        )
        try context.save()

        // No engagements created.
        let engagementCount = try context.fetchCount(FetchDescriptor<CuriosityEngagement>())
        #expect(engagementCount == 0)

        // None attached to the new thread.
        #expect(thread.engagements.isEmpty)
    }

    @Test("Cancel path: not calling insert leaves the store empty")
    func cancelPathWritesNothing() throws {
        let context = try makeContext()

        // Simulate the cancel path — user types but never calls save.
        // No code path runs against `context`, so nothing should land.
        let title = "draft title that gets cancelled"
        let summary = "draft summary that gets cancelled"
        _ = title
        _ = summary

        try context.save()

        let threadCount = try context.fetchCount(FetchDescriptor<RabbitHoleThread>())
        let engagementCount = try context.fetchCount(FetchDescriptor<CuriosityEngagement>())
        #expect(threadCount == 0)
        #expect(engagementCount == 0)
    }
}
