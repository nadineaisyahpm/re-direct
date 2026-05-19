import Foundation
import SwiftData

@Model
final class TopicTrail {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.unique) var slug: String = ""
    var title: String = ""
    var summary: String = ""
    var createdAt: Date = Date()

    var topic: CuriosityTopic?

    @Relationship(deleteRule: .cascade, inverse: \TopicTrailStep.trail)
    var steps: [TopicTrailStep]? = []

    init() {}
}
