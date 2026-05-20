import Foundation
import SwiftData

/// Persists a successful Sign In with Apple result into local storage:
/// - the stable Apple user identifier into the Keychain
/// - the user's display name into the single on-device `UserProfile` row
@MainActor
struct AppleSignInPersister {

    let keychain: any AppleUserIdentifierStore
    let context: ModelContext

    func persist(_ result: AppleSignInResult) throws {
        try keychain.write(result.user)

        let existing = try context.fetch(FetchDescriptor<UserProfile>())
        let profile: UserProfile
        if let first = existing.first {
            profile = first
        } else {
            profile = UserProfile()
            context.insert(profile)
        }

        // Apple only provides fullName on the first sign-in for a given Apple ID.
        // For returning sign-ins it's nil — preserve the previously stored name.
        if let components = result.fullName {
            let formatter = PersonNameComponentsFormatter()
            formatter.style = .default
            let formatted = formatter.string(from: components)
            if !formatted.isEmpty {
                profile.displayName = formatted
            }
        }
        profile.updatedAt = Date()

        try context.save()
    }
}
