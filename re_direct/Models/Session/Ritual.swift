import Foundation
import SwiftData

@Model
final class Ritual {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var detail: String = ""
    var defaultMinutes: Int = 25
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil

    var topic: CuriosityTopic?
    var redirectMethod: RedirectMethod?

    @Relationship(deleteRule: .nullify, inverse: \RitualSelection.ritual)
    var selections: [RitualSelection]? = []

    init() {}
}
