import Foundation

public final class MistralDirectService: TranscriptionService, @unchecked Sendable {
    public static let defaultTranscriptionModel = "voxtral-mini-latest"

    // MARK: - URL Constants
    private static let transcriptionURL = URL(string: "https://api.mistral.ai/v1/audio/transcriptions")!
    private static let chatURL = URL(string: "https://api.mistral.ai/v1/chat/completions")!
    private static let modelsURL = URL(string: "https://api.mistral.ai/v1/models")!

    /// Returns the stored transcription model if it looks like a valid transcription model ID,
    /// otherwise falls back to the default.
    public static var resolvedTranscriptionModel: String {
        if let stored = UserDefaults.standard.string(forKey: "transcriptionModel"),
           !stored.isEmpty,
           stored.contains("voxtral") {
            return stored
        }
        return defaultTranscriptionModel
    }

    private let keychainService: KeychainService
    private let session: URLSession
    private let apiKeyOverride: String?

    public init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        self.apiKeyOverride = nil
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = NetworkConfiguration.default.requestTimeout
        config.timeoutIntervalForResource = NetworkConfiguration.default.resourceTimeout
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    /// Internal init for test injection of a custom URLSession and optional API key override.
    init(keychainService: KeychainService = KeychainService(), session: URLSession, apiKeyOverride: String? = nil) {
        self.keychainService = keychainService
        self.session = session
        self.apiKeyOverride = apiKeyOverride
    }

    private var apiKey: String {
        get throws {
            if let override = apiKeyOverride, !override.isEmpty { return override }
            guard let key = keychainService.getAPIKey(), !key.isEmpty else {
                throw MistralError.missingAPIKey
            }
            return key
        }
    }

    // MARK: - Retry Logic

    private func performRequest(_ request: URLRequest, configuration: NetworkConfiguration = .default) async throws -> (Data, HTTPURLResponse) {
        var lastError: any Error = MistralError.invalidResponse

        for attempt in 0...configuration.maxRetries {
            if attempt > 0 {
                let delay = min(configuration.baseRetryDelay * pow(2.0, Double(attempt - 1)), 30)
                try await Task.sleep(for: .seconds(delay))
            }

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw MistralError.invalidResponse
                }

                guard httpResponse.statusCode == 200 else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                    let error = MistralError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
                    if error.isRetryable && attempt < configuration.maxRetries {
                        lastError = error
                        continue
                    }
                    throw error
                }

                return (data, httpResponse)
            } catch let error as MistralError {
                if error.isRetryable && attempt < configuration.maxRetries {
                    lastError = error
                    continue
                }
                throw error
            } catch let error as URLError where Self.isTransientURLError(error) {
                if attempt < configuration.maxRetries {
                    lastError = error
                    continue
                }
                throw error
            }
        }

        throw lastError
    }

    private static func isTransientURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    // MARK: - Transcription

    public func transcribe(audioFileURL: URL, language: String?, model: String = "voxtral-mini-latest") async throws -> TranscriptionResult {
        let key = try apiKey
        let boundary = UUID().uuidString

        var request = URLRequest(url: Self.transcriptionURL)
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

        let (data, _) = try await performRequest(request, configuration: .transcription)

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return TranscriptionResult(text: decoded.text, language: decoded.language)
    }

    // MARK: - Chat / Prompt

    public func runPrompt(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let key = try apiKey

        var request = URLRequest(url: Self.chatURL)
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

        let (data, _) = try await performRequest(request)

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw MistralError.emptyResponse
        }
        return content
    }

    // MARK: - Models

    public func listModels() async throws -> [MistralModel] {
        let key = try apiKey
        var request = URLRequest(url: Self.modelsURL)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await performRequest(request)

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
        var request = URLRequest(url: Self.modelsURL)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await performRequest(request)

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let models = decoded.data
            .filter {
                $0.id.contains("voxtral")
                && !$0.id.contains("realtime")
                && !$0.id.contains("small")
            }
            .map { MistralModel(id: $0.id, name: $0.id, capabilities: ["transcription"]) }
        let unique = Dictionary(grouping: models, by: \.id).compactMap(\.value.first)
        return unique.sorted { $0.id < $1.id }
    }

    // MARK: - Validate

    public func validateAPIKey() async throws -> Bool {
        let key = try apiKey
        var request = URLRequest(url: Self.modelsURL)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (_, _) = try await performRequest(request)
            return true
        } catch let error as MistralError {
            if case .apiError(statusCode: 401, _) = error {
                return false
            }
            throw error
        }
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

    public var isRetryable: Bool {
        switch self {
        case .apiError(let statusCode, _):
            return statusCode == 429 || (500...504).contains(statusCode)
        case .missingAPIKey, .emptyResponse, .invalidResponse:
            return false
        }
    }

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
