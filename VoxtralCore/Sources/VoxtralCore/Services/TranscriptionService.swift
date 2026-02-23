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

    /// Short display name: "voxtral-mini-transcribe-26-02" → "Voxtral Mini Transcribe v26.02"
    public var displayName: String {
        var parts = id.split(separator: "-").map(String.init)

        // Detect trailing version segments (e.g. ["26","02"] or ["25","07"])
        var versionParts: [String] = []
        while let last = parts.last, last.allSatisfy(\.isNumber) {
            versionParts.insert(parts.removeLast(), at: 0)
        }

        let base = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        if versionParts.isEmpty {
            return base
        }
        return "\(base) v\(versionParts.joined(separator: "."))"
    }
}

public protocol TranscriptionService: Sendable {
    func transcribe(audioFileURL: URL, language: String?, model: String) async throws -> TranscriptionResult
    func runPrompt(transcript: String, systemPrompt: String, model: String) async throws -> String
    func listModels() async throws -> [MistralModel]
    func listTranscriptionModels() async throws -> [MistralModel]
    func validateAPIKey() async throws -> Bool
}
