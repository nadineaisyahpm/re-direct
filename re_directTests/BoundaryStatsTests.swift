import Testing
import Foundation
@testable import re_direct

@MainActor
@Suite("BoundaryStats")
struct BoundaryStatsTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private func makeActive(at start: Date) -> TimerSession {
        let s = TimerSession()
        s.startedAt = start
        return s
    }

    private func makeCompleted(at start: Date, duration: TimeInterval = 1_500) -> TimerSession {
        let s = makeActive(at: start)
        s.endedAt = start.addingTimeInterval(duration)
        s.completed = true
        s.actualMinutes = Int(duration / 60)
        return s
    }

    private func makeInterrupted(at start: Date, duration: TimeInterval = 600) -> TimerSession {
        let s = makeActive(at: start)
        s.endedAt = start.addingTimeInterval(duration)
        s.completed = false
        s.interruptedReason = "stopped early"
        s.actualMinutes = Int(duration / 60)
        return s
    }

    private func makeDeleted(at start: Date) -> TimerSession {
        let s = makeCompleted(at: start)
        s.deletedAt = .now
        return s
    }

    // MARK: empty

    @Test func emptyArrayReturnsZeroes() {
        let stats = BoundaryStats.compute(from: [], now: now, calendar: calendar)
        #expect(stats.total == 0)
        #expect(stats.active == 0)
        #expect(stats.completed == 0)
        #expect(stats.interrupted == 0)
        #expect(stats.lastStartedAt == nil)
        #expect(stats.lastStartedRelative == nil)
    }

    // MARK: counts

    @Test func mixedLifecycleCountsCorrectly() {
        let sessions = [
            makeActive(at: now.addingTimeInterval(-300)),
            makeCompleted(at: now.addingTimeInterval(-3_600)),
            makeCompleted(at: now.addingTimeInterval(-7_200)),
            makeInterrupted(at: now.addingTimeInterval(-1_800)),
        ]
        let stats = BoundaryStats.compute(from: sessions, now: now, calendar: calendar)
        #expect(stats.total == 4)
        #expect(stats.active == 1)
        #expect(stats.completed == 2)
        #expect(stats.interrupted == 1)
    }

    @Test func totalIncludesEveryLifecycleStateExceptDeleted() {
        let sessions = [
            makeActive(at: now),
            makeCompleted(at: now),
            makeInterrupted(at: now),
            makeDeleted(at: now),    // should NOT count
        ]
        let stats = BoundaryStats.compute(from: sessions, now: now, calendar: calendar)
        #expect(stats.total == 3)        // 1 active + 1 completed + 1 interrupted
        #expect(stats.active == 1)
        #expect(stats.completed == 1)
        #expect(stats.interrupted == 1)
    }

    // MARK: lastStarted

    @Test func lastStartedAtIsMaxStartedAt() {
        let oldest = now.addingTimeInterval(-86_400 * 3)
        let middle = now.addingTimeInterval(-86_400 * 1)
        let newest = now.addingTimeInterval(-300)
        let sessions = [
            makeCompleted(at: oldest),
            makeInterrupted(at: middle),
            makeActive(at: newest),
        ]
        let stats = BoundaryStats.compute(from: sessions, now: now, calendar: calendar)
        #expect(stats.lastStartedAt == newest)
    }

    @Test func lastStartedRelativeRendersUsingEngagementCaption() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let sessions = [makeActive(at: yesterday)]
        let stats = BoundaryStats.compute(from: sessions, now: now, calendar: calendar)
        #expect(stats.lastStartedRelative == "yesterday")
    }

    @Test func lastStartedRelativeIsNilWhenNoLiveSessions() {
        let sessions = [makeDeleted(at: now)]
        let stats = BoundaryStats.compute(from: sessions, now: now, calendar: calendar)
        #expect(stats.lastStartedAt == nil)
        #expect(stats.lastStartedRelative == nil)
    }
}
