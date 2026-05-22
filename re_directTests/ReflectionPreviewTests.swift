import Testing
import Foundation
@testable import re_direct

@Suite("ReflectionPreview")
struct ReflectionPreviewTests {

    @Test func shortBodyIsUnchangedWithNoEllipsis() {
        let body = "a quiet day."
        let out = ReflectionPreview.preview(body)
        #expect(out == "a quiet day.")
        #expect(!out.hasSuffix("..."))
    }

    @Test func bodyAtExactlyWordLimitIsUnchanged() {
        // Default limit is 12 words.
        let body = "one two three four five six seven eight nine ten eleven twelve"
        let out = ReflectionPreview.preview(body)
        #expect(out == body)
        #expect(!out.hasSuffix("..."))
    }

    @Test func bodyOverWordLimitIsTruncatedWithEllipsis() {
        let body = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen"
        let out = ReflectionPreview.preview(body)
        #expect(out == "one two three four five six seven eight nine ten eleven twelve...")
        #expect(out.hasSuffix("..."))
    }

    @Test func leadingAndTrailingWhitespaceIsTrimmedBeforeCounting() {
        let body = "   first second third   "
        let out = ReflectionPreview.preview(body)
        #expect(out == "first second third")
    }

    @Test func newlinesActAsWordSeparators() {
        // Three words split by newlines — under the limit, should pass through
        // trimmed but otherwise as-is.
        let body = "one\ntwo\nthree"
        let out = ReflectionPreview.preview(body)
        #expect(out == "one\ntwo\nthree")
    }

    @Test func newlinesDoNotInflateWordCount() {
        // 13 words separated by mixed newlines and spaces; should truncate
        // because real word count exceeds the default 12-word limit.
        let body = """
        the room was quiet enough that i could
        finally hear what i had been avoiding all week
        """
        let out = ReflectionPreview.preview(body)
        #expect(out.hasSuffix("..."))
        // Joined preview uses single spaces. 12 words: the/room/was/quiet/
        // enough/that/i/could/finally/hear/what/i.
        #expect(out == "the room was quiet enough that i could finally hear what i...")
    }

    @Test func multipleSpacesCollapseInTruncatedOutput() {
        let body = "one  two   three four five six seven eight nine ten eleven twelve thirteen"
        let out = ReflectionPreview.preview(body)
        #expect(out == "one two three four five six seven eight nine ten eleven twelve...")
    }

    @Test func emptyBodyReturnsEmptyString() {
        #expect(ReflectionPreview.preview("") == "")
        #expect(ReflectionPreview.preview("   \n  ") == "")
    }

    @Test func customWordLimitRespected() {
        let body = "one two three four five"
        // Limit 3 → truncate.
        #expect(ReflectionPreview.preview(body, wordLimit: 3) == "one two three...")
        // Limit 5 → at limit, unchanged.
        #expect(ReflectionPreview.preview(body, wordLimit: 5) == body)
    }

    @Test func zeroOrNegativeWordLimitReturnsTrimmedBody() {
        // Edge guard — a non-positive limit means "no truncation," so the
        // trimmed body comes back as-is.
        let body = "  one two three  "
        #expect(ReflectionPreview.preview(body, wordLimit: 0) == "one two three")
        #expect(ReflectionPreview.preview(body, wordLimit: -1) == "one two three")
    }
}
