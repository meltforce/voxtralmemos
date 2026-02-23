import Foundation

public final class MistralDirectService: TranscriptionService, @unchecked Sendable {
    public static let defaultTranscriptionModel = "voxtral-mini-transcribe-26-02"

    /// Returns the stored transcription model if it looks like a valid transcription model ID,
    /// otherwise falls back to the default.
    public static var resolvedTranscriptionModel: String {
        if let stored = UserDefaults.standard.string(forKey: "transcriptionModel"),
           stored.contains("transcribe") {
            return stored
        }
        return defaultTranscriptionModel
    }

    private let keychainService: KeychainService

    public init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    private var apiKey: String {
        get throws {
            guard let key = keychainService.getAPIKey(), !key.isEmpty else {
                throw MistralError.missingAPIKey
            }
            return key
        }
    }

    // MARK: - Transcription

    public func transcribe(audioFileURL: URL, language: String?, model: String = "voxtral-mini-transcribe-26-02") async throws -> TranscriptionResult {
        let key = try apiKey
        let url = URL(string: "https://api.mistral.ai/v1/audio/transcriptions")!
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioFileURL)
        var body = Data()

        // model field
        body.appendMultipart(boundary: boundary, name: "model", value: model)

        // language field (optional)
        if let language, !language.isEmpty, language != "auto" {
            body.appendMultipart(boundary: boundary, name: "language", value: language)
        }

        // audio file
        let filename = audioFileURL.lastPathComponent
        body.appendMultipartFile(boundary: boundary, name: "file", filename: filename, mimeType: "audio/mp4", data: audioData)

        // closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MistralError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MistralError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return TranscriptionResult(text: decoded.text, language: decoded.language)
    }

    // MARK: - Chat / Prompt

    public func runPrompt(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let key = try apiKey
        let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let chatRequest = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: transcript)
            ]
        )
        request.httpBody = try JSONEncoder().encode(chatRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MistralError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MistralError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw MistralError.emptyResponse
        }
        return content
    }

    // MARK: - Models

    public func listModels() async throws -> [MistralModel] {
        let key = try apiKey
        let url = URL(string: "https://api.mistral.ai/v1/models")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MistralError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let models = decoded.data
            .filter {
                $0.capabilities?.completionChat == true
                && $0.id.hasSuffix("-latest")
                && !$0.id.contains("pixtral")
                && !$0.id.contains("vibe")
                && !$0.id.contains("voxtral")
                && !$0.id.contains("embed")
                && !$0.id.contains("moderation")
            }
            .map { MistralModel(id: $0.id, name: $0.id, capabilities: ["chat"]) }
        let unique = Dictionary(grouping: models, by: \.id).compactMap(\.value.first)
        return unique.sorted { $0.id < $1.id }
    }

    // MARK: - Transcription Models

    public func listTranscriptionModels() async throws -> [MistralModel] {
        let key = try apiKey
        let url = URL(string: "https://api.mistral.ai/v1/models")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MistralError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let models = decoded.data
            .filter { $0.id.contains("voxtral") && $0.id.contains("transcribe") && !$0.id.contains("realtime") }
            .map { MistralModel(id: $0.id, name: $0.id, capabilities: ["transcription"]) }
        let unique = Dictionary(grouping: models, by: \.id).compactMap(\.value.first)
        return unique.sorted { $0.id < $1.id }
    }

    // MARK: - Validate

    public func validateAPIKey() async throws -> Bool {
        let key = try apiKey
        let url = URL(string: "https://api.mistral.ai/v1/models")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 200
    }
}

// MARK: - Request/Response types

private struct TranscriptionResponse: Decodable {
    let text: String
    let language: String?
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    let message: ChatMessage
}

private struct ModelsResponse: Decodable {
    let data: [ModelEntry]
}

private struct ModelEntry: Decodable {
    let id: String
    let capabilities: ModelCapabilities?
}

private struct ModelCapabilities: Decodable {
    let completionChat: Bool?

    enum CodingKeys: String, CodingKey {
        case completionChat = "completion_chat"
    }
}

public enum MistralError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Add your Mistral API key in Settings."
        case .invalidResponse:
            return "Invalid response from Mistral API."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .emptyResponse:
            return "Empty response from Mistral API."
        }
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
