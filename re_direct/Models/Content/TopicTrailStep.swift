import Foundation
import SwiftData

@Model
final class TopicTrailStep {
    @Attribute(.unique) var id: UUID = UUID()
    var stepOrder: Int = 0
    var estimatedMinutes: Int = 10

    var trail: TopicTrail?
    var prompt: CuriosityPrompt?

    init() {}
}
