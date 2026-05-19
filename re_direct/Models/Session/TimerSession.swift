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
