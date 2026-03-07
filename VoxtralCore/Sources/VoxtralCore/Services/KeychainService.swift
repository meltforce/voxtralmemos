import Foundation
import Security

public enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))."
        }
    }
}

public final class KeychainService: Sendable {
    private static let accessGroup = "group.com.meltforce.voxtralmemos"

    private let service: String
    private let apiKeyAccount: String
    private let useAccessGroup: Bool

    public init() {
        self.service = "com.meltforce.voxtralmemos"
        self.apiKeyAccount = "mistral-api-key"
        self.useAccessGroup = true
        migrateToAccessGroup()
    }

    /// Internal init for tests — allows using a separate keychain namespace.
    init(service: String, account: String) {
        self.service = service
        self.apiKeyAccount = account
        self.useAccessGroup = false
    }

    /// Migrates existing keychain items (without access group) to the shared group.
    private func migrateToAccessGroup() {
        // Try reading without access group
        let oldQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(oldQuery as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return }

        // Check if it already exists with the access group
        var groupQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecAttrAccessGroup as String: Self.accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var groupResult: AnyObject?
        let groupStatus = SecItemCopyMatching(groupQuery as CFDictionary, &groupResult)
        if groupStatus == errSecSuccess { return } // Already migrated

        // Save with access group
        groupQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecAttrAccessGroup as String: Self.accessGroup,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(groupQuery as CFDictionary, nil)

        // Delete old entry without group
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
    }

    public func saveAPIKey(_ key: String) throws {
        deleteAPIKey()
        let data = key.data(using: .utf8)!
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = Self.accessGroup
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    public func getAPIKey() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = Self.accessGroup
        }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public func deleteAPIKey() -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = Self.accessGroup
        }
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
