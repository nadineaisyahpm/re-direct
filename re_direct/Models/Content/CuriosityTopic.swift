import Foundation
import SwiftData

@Model
final class CuriosityTopic {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.unique) var slug: String = ""
    var title: String = ""
    var summary: String = ""
    var coverAssetName: String = ""
    var accentColorHex: String = ""
    var seedVersion: Int = 1
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \CuriosityPrompt.topic)
    var prompts: [CuriosityPrompt]? = []

    @Relationship(deleteRule: .cascade, inverse: \TopicTrail.topic)
    var trails: [TopicTrail]? = []

    init() {}
}
