import Foundation
import SwiftData

@Model
final class RedirectMethod {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.unique) var slug: String = ""
    var displayName: String = ""
    var summary: String = ""
    var createdAt: Date = Date()

    init() {}
}
