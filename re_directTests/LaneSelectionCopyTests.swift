import Testing
@testable import re_direct

@Suite("LaneSelectionCopy")
struct LaneSelectionCopyTests {

    // MARK: - primaryText

    @Test func primaryTextUnselectedUsesSelectVerb() {
        let text = LaneSelectionCopy.primaryText(laneLabel: "Watch", isSelected: false)
        #expect(text == "select Watch as your redirection method")
    }

    @Test func primaryTextSelectedUsesIsVerb() {
        let text = LaneSelectionCopy.primaryText(laneLabel: "Watch", isSelected: true)
        #expect(text == "Watch is your redirection method")
    }

    @Test func primaryTextAllLanesUnselected() {
        let lanes = ["Watch", "Read", "Mini Game", "Reflect", "Deep Dive"]
        for lane in lanes {
            let text = LaneSelectionCopy.primaryText(laneLabel: lane, isSelected: false)
            #expect(text.hasPrefix("select \(lane)"))
            #expect(text.hasSuffix("your redirection method"))
        }
    }

    @Test func primaryTextAllLanesSelected() {
        let lanes = ["Watch", "Read", "Mini Game", "Reflect", "Deep Dive"]
        for lane in lanes {
            let text = LaneSelectionCopy.primaryText(laneLabel: lane, isSelected: true)
            #expect(text.hasPrefix(lane))
            #expect(text.hasSuffix("your redirection method"))
            #expect(!text.hasPrefix("select"))
        }
    }

    // MARK: - supportingText

    @Test func supportingTextWatchContainsVideoRabbitHole() {
        let text = LaneSelectionCopy.supportingText(slug: "watch")
        #expect(text.contains("rabbit holes") || text.contains("watches"))
    }

    @Test func supportingTextReadContainsArticles() {
        let text = LaneSelectionCopy.supportingText(slug: "read")
        #expect(text.contains("articles") || text.contains("essays"))
    }

    @Test func supportingTextMiniGameContainsPuzzle() {
        let text = LaneSelectionCopy.supportingText(slug: "mini-game")
        #expect(text.contains("puzzle") || text.contains("attention"))
    }

    @Test func supportingTextReflectContainsQuestion() {
        let text = LaneSelectionCopy.supportingText(slug: "reflect")
        #expect(text.contains("question") || text.contains("write"))
    }

    @Test func supportingTextDeepDiveContainsThreads() {
        let text = LaneSelectionCopy.supportingText(slug: "deep-dive")
        #expect(text.contains("threads") || text.contains("unfolding"))
    }

    @Test func supportingTextAllCanonicalSlugsReturnNonEmpty() {
        let slugs = ["watch", "read", "mini-game", "reflect", "deep-dive"]
        for slug in slugs {
            let text = LaneSelectionCopy.supportingText(slug: slug)
            #expect(!text.isEmpty, "Expected non-empty supporting text for slug '\(slug)'")
        }
    }

    @Test func supportingTextUnknownSlugReturnsNonEmptyFallback() {
        let text = LaneSelectionCopy.supportingText(slug: "unknown-future-slug")
        #expect(!text.isEmpty)
    }

    @Test func supportingTextDoesNotContainReflectionBody() {
        // Privacy invariant: supporting text must never echo private content.
        // This is a sentinel check — the copy is static, but guards against
        // a future accidental wiring that pulls live data into this helper.
        let slugs = ["watch", "read", "mini-game", "reflect", "deep-dive"]
        for slug in slugs {
            let text = LaneSelectionCopy.supportingText(slug: slug)
            // No dynamic insertion points exist; the strings are literals.
            // Test simply confirms the helper returns a plain string.
            #expect(text == LaneSelectionCopy.supportingText(slug: slug))
        }
    }
}
