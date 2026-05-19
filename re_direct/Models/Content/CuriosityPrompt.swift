import Foundation
import SwiftData

@Model
final class CuriosityPrompt {
    @Attribute(.unique) var id: UUID = UUID()
    var slug: String = ""
    var body: String = ""
    var source: String = "seed"
    var tier: String = "free"
    var estimatedMinutes: Int = 10
    var createdAt: Date = Date()

    var topic: CuriosityTopic?

    init() {}
}
