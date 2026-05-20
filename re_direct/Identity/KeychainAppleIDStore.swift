import Foundation
import Security

protocol AppleUserIdentifierStore: Sendable {
    func read() throws -> String?
    func write(_ identifier: String) throws
    func delete() throws
}

enum KeychainStoreError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case dataConversion
}

/// Stores the Sign In with Apple stable user identifier in the device Keychain.
/// Accessibility class is `AfterFirstUnlockThisDeviceOnly`: never synced to iCloud,
/// readable only after first device unlock.
struct KeychainAppleIDStore: AppleUserIdentifierStore {
    let service: String
    let account: String

    init(service: String = "app.redirect.identity", account: String = "apple-user-id") {
        self.service = service
        self.account = account
    }

    func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
        guard let data = ref as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainStoreError.dataConversion
        }
        return value
    }

    func write(_ identifier: String) throws {
        guard let data = identifier.data(using: .utf8) else {
            throw KeychainStoreError.dataConversion
        }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(addStatus)
            }
            return
        }
        throw KeychainStoreError.unexpectedStatus(updateStatus)
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }
}
