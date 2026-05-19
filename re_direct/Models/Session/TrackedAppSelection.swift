import Foundation
import SwiftData

@Model
final class TrackedAppSelection {
    @Attribute(.unique) var id: UUID = UUID()
    var bundleIdentifier: String = ""
    var displayName: String = ""
    var category: String = ""
    var dailyLimitMinutes: Int = 60
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil

    init() {}
}
