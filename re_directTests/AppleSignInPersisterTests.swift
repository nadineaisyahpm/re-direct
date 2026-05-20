import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("AppleSignInPersister")
struct AppleSignInPersisterTests {

    final class StubKeychainStore: AppleUserIdentifierStore, @unchecked Sendable {
        private let lock = NSLock()
        private var value: String?

        func read() throws -> String? {
            lock.lock(); defer { lock.unlock() }
            return value
        }
        func write(_ identifier: String) throws {
            lock.lock(); defer { lock.unlock() }
            value = identifier
        }
        func delete() throws {
            lock.lock(); defer { lock.unlock() }
            value = nil
        }
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeNameComponents(given: String?, family: String?) -> PersonNameComponents {
        var c = PersonNameComponents()
        c.givenName = given
        c.familyName = family
        return c
    }

    @Test func persistsUserIdentifierToKeychain() throws {
        let store = StubKeychainStore()
        let context = try makeContext()
        let persister = AppleSignInPersister(keychain: store, context: context)

        try persister.persist(AppleSignInResult(
            user: "001234.abcdef.5678",
            email: "user@example.com",
            fullName: makeNameComponents(given: "Nadine", family: "Maharani")
        ))

        #expect(try store.read() == "001234.abcdef.5678")
    }

    @Test func createsUserProfileOnFirstSignInWithName() throws {
        let store = StubKeychainStore()
        let context = try makeContext()
        let persister = AppleSignInPersister(keychain: store, context: context)

        try persister.persist(AppleSignInResult(
            user: "user-1",
            email: nil,
            fullName: makeNameComponents(given: "Nadine", family: "Maharani")
        ))

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.displayName == "Nadine Maharani")
    }

    @Test func preservesDisplayNameOnReturningSignIn() throws {
        let store = StubKeychainStore()
        let context = try makeContext()

        // Seed an existing profile (simulates a prior first sign-in).
        let existing = UserProfile()
        existing.displayName = "Nadine Maharani"
        context.insert(existing)
        try context.save()

        let persister = AppleSignInPersister(keychain: store, context: context)
        try persister.persist(AppleSignInResult(
            user: "user-1",
            email: nil,
            fullName: nil   // Apple returns nil for returning users
        ))

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.displayName == "Nadine Maharani")
    }

    @Test func doesNotOverwriteWithEmptyNameComponents() throws {
        let store = StubKeychainStore()
        let context = try makeContext()

        let existing = UserProfile()
        existing.displayName = "Existing Name"
        context.insert(existing)
        try context.save()

        let persister = AppleSignInPersister(keychain: store, context: context)
        try persister.persist(AppleSignInResult(
            user: "user-1",
            email: nil,
            fullName: PersonNameComponents()   // empty components
        ))

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.first?.displayName == "Existing Name")
    }

    @Test func isIdempotentAcrossRepeatedSignIns() throws {
        let store = StubKeychainStore()
        let context = try makeContext()
        let persister = AppleSignInPersister(keychain: store, context: context)
        let result = AppleSignInResult(
            user: "user-1",
            email: nil,
            fullName: makeNameComponents(given: "Nadine", family: nil)
        )

        try persister.persist(result)
        try persister.persist(result)
        try persister.persist(result)

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.displayName == "Nadine")
        #expect(try store.read() == "user-1")
    }
}
