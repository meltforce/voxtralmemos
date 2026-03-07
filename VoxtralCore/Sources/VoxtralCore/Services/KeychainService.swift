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
    private let service: String
    private let apiKeyAccount: String

    public init() {
        self.service = "com.meltforce.voxtralmemos"
        self.apiKeyAccount = "mistral-api-key"
        migrateFromAccessGroup()
    }

    /// Internal init for tests — allows using a separate keychain namespace.
    init(service: String, account: String) {
        self.service = service
        self.apiKeyAccount = account
    }

    /// Migrates existing keychain items that were saved with the old access group.
    private func migrateFromAccessGroup() {
        // Check if an item already exists without access group
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess { return } // Already accessible, no migration needed

        // Try reading with the old access group
        var oldQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecAttrAccessGroup as String: "group.com.meltforce.voxtralmemos",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var oldResult: AnyObject?
        let oldStatus = SecItemCopyMatching(oldQuery as CFDictionary, &oldResult)
        guard oldStatus == errSecSuccess, let data = oldResult as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return }

        // Save without access group
        let newQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            // Delete old entry with access group
            oldQuery = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: apiKeyAccount,
                kSecAttrAccessGroup as String: "group.com.meltforce.voxtralmemos"
            ]
            SecItemDelete(oldQuery as CFDictionary)
        }
    }

    public func saveAPIKey(_ key: String) throws {
        deleteAPIKey()
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    public func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
