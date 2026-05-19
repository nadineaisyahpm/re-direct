import Foundation
import SwiftData

// Aggregates only — no raw event log is stored.
@Model
final class ScreenTimeSummary {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var trackedMinutes: Int = 0
    var redirectedMinutes: Int = 0
    var source: String = "self-reported"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}
}
