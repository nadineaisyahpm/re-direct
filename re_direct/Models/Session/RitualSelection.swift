import Foundation
import SwiftData

@Model
final class RitualSelection {
    @Attribute(.unique) var id: UUID = UUID()
    var activatedAt: Date = Date()
    var deactivatedAt: Date? = nil
    var createdAt: Date = Date()

    var ritual: Ritual?

    init() {}

    var isActive: Bool { deactivatedAt == nil }
}
