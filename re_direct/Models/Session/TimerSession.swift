import Foundation
import SwiftData

@Model
final class TimerSession {
    @Attribute(.unique) var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date? = nil
    var plannedMinutes: Int = 25
    var actualMinutes: Int = 0
    var completed: Bool = false
    var interruptedReason: String? = nil
    var createdAt: Date = Date()
    var deletedAt: Date? = nil

    var ritual: Ritual?

    @Relationship(deleteRule: .nullify, inverse: \ReflectionEntry.session)
    var reflection: ReflectionEntry?

    init() {}
}

// MARK: - Lifecycle helpers
//
// A TimerSession's lifecycle is derived from its stored fields. The four
// states below are mutually exclusive. Transitions are one-way:
//   active → completed    (endedAt set, completed = true)
//   active → interrupted  (endedAt set, completed = false; interruptedReason
//                          is conventionally set, but isInterrupted does not
//                          require it — defensive against partial writes)
//   any    → deleted      (deletedAt set; overrides prior state for default
//                          queries and analytics)
//
// These helpers do not mutate the model. They are computed properties used
// by reads (UI, queries, tests). Mutations happen in the future timer-tick
// slice and write to the stored fields directly.

extension TimerSession {

    enum LifecycleStatus: String, Sendable {
        case active
        case completed
        case interrupted
        case deleted
    }

    var status: LifecycleStatus {
        if deletedAt != nil { return .deleted }
        if endedAt == nil   { return .active }
        if completed        { return .completed }
        return .interrupted
    }

    var isActive: Bool      { status == .active }
    var isCompleted: Bool   { status == .completed }
    var isInterrupted: Bool { status == .interrupted }
    var isDeleted: Bool     { status == .deleted }

    /// Wall-clock seconds between `startedAt` and the end boundary. Uses
    /// `endedAt` if present; otherwise falls back to `now` (default: real
    /// `Date()`, exposed for deterministic tests). Clamps to 0 if the
    /// boundary somehow lands before `startedAt`.
    func elapsedSeconds(now: Date = Date()) -> Int {
        let end = endedAt ?? now
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }

    func elapsedMinutes(now: Date = Date()) -> Int {
        elapsedSeconds(now: now) / 60
    }
}
