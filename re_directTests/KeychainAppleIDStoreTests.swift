import Testing
import Foundation
@testable import re_direct

/// Keychain APIs require the host process to carry entitlements. When tests are
/// run via `xcodebuild ... CODE_SIGNING_ALLOWED=NO`, `SecItem*` calls return
/// `errSecMissingEntitlement` (-34018). We detect that and skip this suite so
/// unsigned CLI runs report green instead of red. When tests are run from Xcode
/// with a code-signing identity (or from CI with one), the suite runs normally.
enum KeychainAvailability {
    static let isAvailable: Bool = {
        let probe = KeychainAppleIDStore(
            service: "app.redirect.identity.tests.probe.\(UUID().uuidString)",
            account: "probe"
        )
        do {
            _ = try probe.read()
            return true
        } catch KeychainStoreError.unexpectedStatus(let status) where status == -34018 {
            return false
        } catch {
            return true
        }
    }()
}

@Suite("KeychainAppleIDStore", .enabled(if: KeychainAvailability.isAvailable, "Keychain unavailable in unsigned test runs"))
struct KeychainAppleIDStoreTests {

    private func freshStore() -> KeychainAppleIDStore {
        let service = "app.redirect.identity.tests.\(UUID().uuidString)"
        return KeychainAppleIDStore(service: service, account: "apple-user-id")
    }

    @Test func readReturnsNilWhenAbsent() throws {
        let store = freshStore()
        let value = try store.read()
        #expect(value == nil)
    }

    @Test func writeThenReadRoundTrip() throws {
        let store = freshStore()
        try store.write("apple.user.0123456789")
        let value = try store.read()
        #expect(value == "apple.user.0123456789")
        try store.delete()
    }

    @Test func writeOverwritesExistingValue() throws {
        let store = freshStore()
        try store.write("first")
        try store.write("second")
        let value = try store.read()
        #expect(value == "second")
        try store.delete()
    }

    @Test func deleteRemovesValue() throws {
        let store = freshStore()
        try store.write("transient")
        try store.delete()
        let value = try store.read()
        #expect(value == nil)
    }

    @Test func deleteIsIdempotent() throws {
        let store = freshStore()
        try store.delete()
        try store.delete()
    }
}
