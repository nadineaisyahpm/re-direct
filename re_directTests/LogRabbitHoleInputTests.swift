import Testing
import Foundation
@testable import re_direct

@MainActor
@Suite("LogRabbitHoleInput")
struct LogRabbitHoleInputTests {

    @Test func emptyTitleIsInvalid() {
        var input = LogRabbitHoleInput()
        input.title = ""
        #expect(input.isValid == false)
    }

    @Test func titleUnderThreeCharsIsInvalid() {
        var input = LogRabbitHoleInput()
        input.title = "ab"
        #expect(input.isValid == false)
    }

    @Test func titleExactlyThreeCharsIsValid() {
        var input = LogRabbitHoleInput()
        input.title = "abc"
        #expect(input.isValid == true)
    }

    @Test func titleIsTrimmedBeforeLengthCheck() {
        var input = LogRabbitHoleInput()
        input.title = "  ab  "
        #expect(input.isValid == false)

        input.title = "  abc  "
        #expect(input.isValid == true)
        #expect(input.trimmedTitle == "abc")
    }

    @Test func methodSlugMustBeCanonical() {
        var input = LogRabbitHoleInput()
        input.title = "valid title"
        input.methodSlug = "stretch"   // not in canonical set
        #expect(input.isValid == false)

        input.methodSlug = "read"
        #expect(input.isValid == true)
    }

    @Test func durationMustBePositive() {
        var input = LogRabbitHoleInput()
        input.title = "valid title"
        input.methodSlug = "read"
        input.durationMinutes = 0
        #expect(input.isValid == false)

        input.durationMinutes = -10
        #expect(input.isValid == false)

        input.durationMinutes = 1
        #expect(input.isValid == true)
    }

    @Test func canonicalMethodSlugsMatchSeedContract() {
        // Mirrors bundledRedirectMethodSlugsMatchCanonicalSet for the local
        // input form. Catches drift if either side renames a slug.
        let expected: Set<String> = ["watch", "read", "mini-game", "reflect", "deep-dive"]
        #expect(Set(LogRabbitHoleInput.canonicalMethodSlugs) == expected)
    }

    @Test func makeEngagementCarriesAllFields() {
        var input = LogRabbitHoleInput()
        input.title = "  Why deep sea glows  "
        input.methodSlug = "watch"
        input.durationMinutes = 12
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let engagement = input.makeEngagement(at: now)

        #expect(engagement.methodSlug == "watch")
        #expect(engagement.contentTitle == "Why deep sea glows")
        #expect(engagement.durationSeconds == 720)
        #expect(engagement.engagedAt == now)
        #expect(engagement.deletedAt == nil)
        #expect(engagement.topic == nil)
        #expect(engagement.prompt == nil)
        #expect(engagement.session == nil)
    }

    @Test func durationChoicesAreReasonable() {
        let choices = LogRabbitHoleInput.durationChoices
        #expect(choices.allSatisfy { $0 > 0 })
        #expect(choices.first == choices.min())
        #expect(choices.last == choices.max())
    }
}
