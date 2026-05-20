import Testing
import Foundation
@testable import re_direct

@MainActor
@Suite("EngagementCaption")
struct EngagementCaptionTests {

    // Anchor "now" to a Saturday noon UTC for stable boundary math.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private func daysBefore(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    // MARK: relativeDate

    @Test func sameDayReturnsEarlierToday() {
        let earlierToday = calendar.date(byAdding: .hour, value: -3, to: now)!
        #expect(EngagementCaption.relativeDate(earlierToday, now: now, calendar: calendar) == "earlier today")
    }

    @Test func yesterdayReturnsYesterday() {
        #expect(EngagementCaption.relativeDate(daysBefore(1), now: now, calendar: calendar) == "yesterday")
    }

    @Test func twoToSixDaysReturnsNDaysAgo() {
        for n in 2...6 {
            #expect(EngagementCaption.relativeDate(daysBefore(n), now: now, calendar: calendar) == "\(n) days ago")
        }
    }

    @Test func sevenToThirteenDaysReturnsLastWeek() {
        for n in 7...13 {
            #expect(EngagementCaption.relativeDate(daysBefore(n), now: now, calendar: calendar) == "last week")
        }
    }

    @Test func fourteenToTwentyNineDaysReturnsNDaysAgo() {
        for n in [14, 20, 29] {
            #expect(EngagementCaption.relativeDate(daysBefore(n), now: now, calendar: calendar) == "\(n) days ago")
        }
    }

    @Test func thirtyPlusDaysReturnsNDaysAgo() {
        #expect(EngagementCaption.relativeDate(daysBefore(45), now: now, calendar: calendar) == "45 days ago")
    }

    @Test func futureDateClampsToEarlierToday() {
        let future = calendar.date(byAdding: .day, value: 2, to: now)!
        #expect(EngagementCaption.relativeDate(future, now: now, calendar: calendar) == "earlier today")
    }

    // MARK: durationText

    @Test func nilDurationReturnsNil() {
        #expect(EngagementCaption.durationText(nil) == nil)
    }

    @Test func zeroDurationReturnsNil() {
        #expect(EngagementCaption.durationText(0) == nil)
    }

    @Test func subMinuteDurationRoundsUpToOneMin() {
        // 15 seconds rounds to 0; clamp to 1 so display isn't misleading.
        #expect(EngagementCaption.durationText(15) == "1 min")
    }

    @Test func minuteBoundariesRoundCorrectly() {
        #expect(EngagementCaption.durationText(60) == "1 min")
        #expect(EngagementCaption.durationText(89) == "1 min")        // rounds down
        #expect(EngagementCaption.durationText(90) == "2 min")        // rounds up
        #expect(EngagementCaption.durationText(720) == "12 min")      // exact
        #expect(EngagementCaption.durationText(1_800) == "30 min")
    }

    // MARK: caption assembly

    @Test func captionWithDurationJoinsWithMiddot() {
        let engagement = CuriosityEngagement()
        engagement.contentTitle = "test"
        engagement.engagedAt = daysBefore(3)
        engagement.durationSeconds = 720
        let result = EngagementCaption.caption(for: engagement, now: now, calendar: calendar)
        #expect(result == "3 days ago · 12 min")
    }

    @Test func captionWithoutDurationShowsOnlyDate() {
        let engagement = CuriosityEngagement()
        engagement.contentTitle = "test"
        engagement.engagedAt = daysBefore(1)
        engagement.durationSeconds = nil
        let result = EngagementCaption.caption(for: engagement, now: now, calendar: calendar)
        #expect(result == "yesterday")
    }

    @Test func captionEarlierTodayWithDuration() {
        let engagement = CuriosityEngagement()
        engagement.contentTitle = "test"
        engagement.engagedAt = now
        engagement.durationSeconds = 300
        let result = EngagementCaption.caption(for: engagement, now: now, calendar: calendar)
        #expect(result == "earlier today · 5 min")
    }

    @Test func captionAcceptsAlternateSeparator() {
        let engagement = CuriosityEngagement()
        engagement.contentTitle = "test"
        engagement.engagedAt = daysBefore(3)
        engagement.durationSeconds = 720
        let result = EngagementCaption.caption(
            for: engagement,
            now: now,
            calendar: calendar,
            separator: "–"
        )
        #expect(result == "3 days ago – 12 min")
    }

    @Test func separatorIsIgnoredWhenDurationAbsent() {
        let engagement = CuriosityEngagement()
        engagement.contentTitle = "test"
        engagement.engagedAt = daysBefore(2)
        engagement.durationSeconds = nil
        let result = EngagementCaption.caption(
            for: engagement,
            now: now,
            calendar: calendar,
            separator: "–"
        )
        #expect(result == "2 days ago")
    }
}
