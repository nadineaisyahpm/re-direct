import Foundation
import SwiftData

// Sensitive: reflection content never leaves the device.
@Model
final class ReflectionEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var mood: String = ""
    var body: String = ""
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil

    var session: TimerSession?

    init() {}
}
