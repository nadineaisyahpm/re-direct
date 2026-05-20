import Foundation
import SwiftData

@Model
final class ReminderTheme {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.unique) var slug: String = ""
    var displayName: String = ""
    var assetName: String = ""
    var createdAt: Date = Date()

    init() {}
}
