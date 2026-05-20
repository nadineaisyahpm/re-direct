import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID = UUID()
    var displayName: String = ""
    var onboardingComplete: Bool = false
    var timezoneIdentifier: String = TimeZone.current.identifier
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var activeReminderTheme: ReminderTheme?
    var activeRedirectMethod: RedirectMethod?

    init() {}
}
