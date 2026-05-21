import Testing
import Foundation
@testable import re_direct

@MainActor
@Suite("TimerSession lifecycle")
struct TimerSessionLifecycleTests {

    private let startedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSession() -> TimerSession {
        let s = TimerSession()
        s.startedAt = startedAt
        s.plannedMinutes = 25
        return s
    }

    // MARK: status

    @Test func newSessionIsActive() {
        let s = makeSession()
        #expect(s.status == .active)
        #expect(s.isActive)
        #expect(s.isCompleted == false)
        #expect(s.isInterrupted == false)
        #expect(s.isDeleted == false)
    }

    @Test func endedAndCompletedSessionIsCompleted() {
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(1_500)
        s.completed = true
        s.actualMinutes = 25
        #expect(s.status == .completed)
        #expect(s.isCompleted)
        #expect(s.isActive == false)
        #expect(s.isInterrupted == false)
    }

    @Test func endedWithReasonSessionIsInterrupted() {
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(600)
        s.completed = false
        s.interruptedReason = "user-cancelled"
        s.actualMinutes = 10
        #expect(s.status == .interrupted)
        #expect(s.isInterrupted)
        #expect(s.isActive == false)
        #expect(s.isCompleted == false)
    }

    @Test func endedWithoutReasonStillCountsAsInterrupted() {
        // Defensive: if the end path forgot to set interruptedReason, the
        // session is still interrupted (it ended early without completing).
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(120)
        s.completed = false
        s.interruptedReason = nil
        #expect(s.status == .interrupted)
        #expect(s.isInterrupted)
    }

    @Test func softDeletedSessionIsNotActive() {
        let s = makeSession()
        s.deletedAt = Date()
        #expect(s.status == .deleted)
        #expect(s.isDeleted)
        #expect(s.isActive == false)
    }

    @Test func softDeleteOverridesPriorCompletedState() {
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(1_500)
        s.completed = true
        s.deletedAt = Date()
        #expect(s.status == .deleted)
        #expect(s.isDeleted)
        #expect(s.isCompleted == false)
    }

    @Test func softDeleteOverridesPriorInterruptedState() {
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(180)
        s.completed = false
        s.interruptedReason = "app-backgrounded"
        s.deletedAt = Date()
        #expect(s.status == .deleted)
        #expect(s.isInterrupted == false)
    }

    // MARK: elapsed

    @Test func elapsedSecondsForActiveUsesNow() {
        let s = makeSession()
        let now = startedAt.addingTimeInterval(300)
        #expect(s.elapsedSeconds(now: now) == 300)
        #expect(s.elapsedMinutes(now: now) == 5)
    }

    @Test func elapsedSecondsForEndedIgnoresNow() {
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(900)
        let now = startedAt.addingTimeInterval(3_600)
        #expect(s.elapsedSeconds(now: now) == 900)
        #expect(s.elapsedMinutes(now: now) == 15)
    }

    @Test func elapsedMinutesTruncates() {
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(89)   // 1 min 29 s → 1 min
        #expect(s.elapsedMinutes() == 1)

        s.endedAt = startedAt.addingTimeInterval(59)   // 0 min 59 s → 0 min
        #expect(s.elapsedMinutes() == 0)
    }

    @Test func elapsedClampsAtZeroWhenEndBeforeStart() {
        // Defensive: negative interval clamps to 0.
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(-60)
        #expect(s.elapsedSeconds() == 0)
        #expect(s.elapsedMinutes() == 0)
    }

    @Test func elapsedForDeletedSessionStillComputable() {
        // Soft-delete doesn't zero elapsed; analytics may still want the
        // wall-clock span of a deleted session.
        let s = makeSession()
        s.endedAt = startedAt.addingTimeInterval(600)
        s.completed = true
        s.deletedAt = Date()
        #expect(s.elapsedSeconds() == 600)
    }
}
