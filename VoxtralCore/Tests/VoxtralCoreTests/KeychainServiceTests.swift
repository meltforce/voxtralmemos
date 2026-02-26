import Testing
import Foundation
@testable import VoxtralCore

/// Keychain tests require a host app with entitlements (macOS or simulator with host app).
/// These tests pass via `swift test` on macOS; on iOS Simulator without a host app they will
/// throw KeychainError.saveFailed(-34018) and be reported as failures.
@Suite("KeychainService", .serialized)
struct KeychainServiceTests {
    private let service = KeychainService(service: "com.meltforce.voxtralmemos.keychain-tests", account: "test-api-key")

    init() {
        service.deleteAPIKey()
    }

    @Test("save and retrieve API key")
    func saveAndRetrieve() throws {
        try service.saveAPIKey("test-key-123")
        #expect(service.getAPIKey() == "test-key-123")
    }

    @Test("delete removes the API key")
    func deleteKey() throws {
        try service.saveAPIKey("test-key-123")
        service.deleteAPIKey()
        #expect(service.getAPIKey() == nil)
    }

    @Test("overwrite replaces existing key")
    func overwrite() throws {
        try service.saveAPIKey("old-key")
        try service.saveAPIKey("new-key")
        #expect(service.getAPIKey() == "new-key")
    }

    @Test("getAPIKey returns nil when empty")
    func getEmpty() {
        #expect(service.getAPIKey() == nil)
    }

    @Test("delete is idempotent")
    func deleteIdempotent() {
        #expect(service.deleteAPIKey() == true)
        #expect(service.deleteAPIKey() == true)
    }
}
