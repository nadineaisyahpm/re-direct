import Testing
import Foundation
@testable import re_direct

@MainActor
@Suite("RecentRabbitHolesSection")
struct RecentRabbitHolesSectionTests {

    @Test func displayLabelMapsCanonicalSlugs() {
        #expect(RecentRabbitHolesSection.displayLabel(for: "watch") == "watch")
        #expect(RecentRabbitHolesSection.displayLabel(for: "read") == "read")
        #expect(RecentRabbitHolesSection.displayLabel(for: "mini-game") == "mini game")
        #expect(RecentRabbitHolesSection.displayLabel(for: "reflect") == "reflect")
        #expect(RecentRabbitHolesSection.displayLabel(for: "deep-dive") == "deep dive")
    }

    @Test func displayLabelPassesThroughUnknownSlug() {
        // Defensive: unexpected future slugs render verbatim instead of
        // crashing or showing an empty label.
        #expect(RecentRabbitHolesSection.displayLabel(for: "stretch") == "stretch")
        #expect(RecentRabbitHolesSection.displayLabel(for: "") == "")
    }
}
