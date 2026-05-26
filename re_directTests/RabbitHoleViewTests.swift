import Testing
import SwiftUI
import SwiftData
@testable import re_direct

@MainActor
@Suite("RabbitHoleView (RH3-B shell)")
struct RabbitHoleViewTests {

    // MARK: - Tab configuration

    @Test("Tab 1 is the Rabbit Hole entry")
    func tabOneIsRabbitHole() {
        let entry = SharedNavBar.tabs[1]
        #expect(entry.icon == "arrow.turn.down.right")
        #expect(entry.label == "rabbit hole")
    }

    @Test("Tabs 0, 2, 3, 4 are unchanged from the pre-RH3-B array")
    func surroundingTabsUnchanged() {
        // Pinned snapshot of the pre-RH3-B tabs, with index 1 replaced by
        // the new Rabbit Hole entry. Tabs 0, 2, 3, 4 must match the
        // pre-existing app navigation exactly.
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

    // MARK: - Empty-state copy

    @Test("Empty-state headline matches the design extraction")
    func emptyStateHeadline() {
        #expect(RabbitHoleEmptyCopy.headline == "no threads yet.")
    }

    @Test("Empty-state sub describes the thread origin honestly")
    func emptyStateSub() {
        // The phrasing matters: a thread starts from an *already-logged*
        // rabbit hole. This guards against future copy edits that imply
        // thread creation is the primary entry point.
        #expect(RabbitHoleEmptyCopy.sub.contains("already logged"))
    }

    @Test("Empty-state CTA copy")
    func emptyStateCTA() {
        #expect(RabbitHoleEmptyCopy.cta == "start your first thread")
    }

    @Test("Empty-state copy strings are all non-empty")
    func emptyStateCopyNonEmpty() {
        #expect(!RabbitHoleEmptyCopy.headline.isEmpty)
        #expect(!RabbitHoleEmptyCopy.sub.isEmpty)
        #expect(!RabbitHoleEmptyCopy.cta.isEmpty)
    }

    // MARK: - View construction smoke

    @Test("RabbitHoleView constructs without crashing")
    func viewConstructsCleanly() throws {
        // Mount the view under a real in-memory ModelContainer + the
        // ActiveMethodStore environment, matching the production hosting
        // shape. This catches obvious init-time failures (missing
        // environment, default-argument crashes, etc.).
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        _ = RabbitHoleView()
            .modelContainer(container)
            .environment(ActiveMethodStore())
    }
}
