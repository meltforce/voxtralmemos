import Foundation

public struct TranscriptionResult: Sendable {
    public let text: String
    public let language: String?

    public init(text: String, language: String?) {
        self.text = text
        self.language = language
    }
}

public struct MistralModel: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let capabilities: [String]

    public init(id: String, name: String, capabilities: [String]) {
        self.id = id
        self.name = name
        self.capabilities = capabilities
    }
}

public protocol TranscriptionService: Sendable {
    func transcribe(audioFileURL: URL, language: String?, model: String) async throws -> TranscriptionResult
    func runPrompt(transcript: String, systemPrompt: String, model: String) async throws -> String
    func listModels() async throws -> [MistralModel]
    func listTranscriptionModels() async throws -> [MistralModel]
    func validateAPIKey() async throws -> Bool
}
