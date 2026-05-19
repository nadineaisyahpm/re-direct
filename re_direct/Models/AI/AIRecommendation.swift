import Foundation
import SwiftData

@Model
final class AIRecommendation {
    @Attribute(.unique) var id: UUID = UUID()
    var promptInputHash: String = ""
    var body: String = ""
    var suggestedMinutes: Int = 10
    var provider: String = ""
    var modelVersion: String = ""
    var accepted: Bool = false
    var createdAt: Date = Date()
    var deletedAt: Date? = nil

    var topic: CuriosityTopic?

    init() {}
}
