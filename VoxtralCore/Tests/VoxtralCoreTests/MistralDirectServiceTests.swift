import Testing
import Foundation
@testable import VoxtralCore

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Helpers

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeService(apiKey: String = "test-key") -> MistralDirectService {
    MistralDirectService(session: makeSession(), apiKeyOverride: apiKey)
}

private func jsonResponse(_ json: String, statusCode: Int = 200, url: String = "https://api.mistral.ai/v1/models") -> (Data, HTTPURLResponse) {
    let data = json.data(using: .utf8)!
    let response = HTTPURLResponse(url: URL(string: url)!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    return (data, response)
}

// MARK: - Tests

@Suite("MistralDirectService", .serialized)
struct MistralDirectServiceTests {

    @Test("validateAPIKey returns true for 200")
    func validateSuccess() async throws {
        let service = makeService()
        MockURLProtocol.handler = { _ in
            jsonResponse(#"{"data":[]}"#)
        }
        let result = try await service.validateAPIKey()
        #expect(result == true)
    }

    @Test("validateAPIKey returns false for 401")
    func validateUnauthorized() async throws {
        let service = makeService()
        MockURLProtocol.handler = { _ in
            jsonResponse(#"{"error":"unauthorized"}"#, statusCode: 401)
        }
        let result = try await service.validateAPIKey()
        #expect(result == false)
    }

    @Test("listModels parses response and filters correctly")
    func listModelsFiltering() async throws {
        let service = makeService()
        MockURLProtocol.handler = { _ in
            jsonResponse(#"""
            {
                "data": [
                    {"id": "mistral-small-latest", "capabilities": {"completion_chat": true}},
                    {"id": "mistral-large-latest", "capabilities": {"completion_chat": true}},
                    {"id": "pixtral-large-latest", "capabilities": {"completion_chat": true}},
                    {"id": "voxtral-mini-latest", "capabilities": {"completion_chat": false}},
                    {"id": "mistral-embed-latest", "capabilities": {"completion_chat": true}}
                ]
            }
            """#)
        }
        let models = try await service.listModels()
        let ids = models.map(\.id)
        #expect(ids.contains("mistral-small-latest"))
        #expect(ids.contains("mistral-large-latest"))
        #expect(!ids.contains("pixtral-large-latest"))
        #expect(!ids.contains("voxtral-mini-latest"))
        #expect(!ids.contains("mistral-embed-latest"))
    }

    @Test("runPrompt builds correct request and parses response")
    func runPromptSuccess() async throws {
        let service = makeService()
        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            return jsonResponse(#"""
            {
                "choices": [{"message": {"role": "assistant", "content": "Summary here"}}]
            }
            """#, url: "https://api.mistral.ai/v1/chat/completions")
        }
        let result = try await service.runPrompt(transcript: "Hello", systemPrompt: "Summarize", model: "mistral-small-latest")
        #expect(result == "Summary here")
    }

    @Test("runPrompt throws emptyResponse when choices empty")
    func runPromptEmpty() async throws {
        let service = makeService()
        MockURLProtocol.handler = { _ in
            jsonResponse(#"{"choices": []}"#, url: "https://api.mistral.ai/v1/chat/completions")
        }
        await #expect(throws: MistralError.self) {
            _ = try await service.runPrompt(transcript: "Hello", systemPrompt: "Summarize", model: "mistral-small-latest")
        }
    }

    @Test("throws missingAPIKey when no key stored")
    func missingAPIKey() async throws {
        // No apiKeyOverride and no keychain key → missingAPIKey
        let service = MistralDirectService(session: makeSession())
        await #expect(throws: MistralError.self) {
            _ = try await service.validateAPIKey()
        }
    }

    @Test("non-retryable error is thrown immediately")
    func nonRetryableError() async throws {
        let service = makeService()
        var callCount = 0
        MockURLProtocol.handler = { _ in
            callCount += 1
            return jsonResponse(#"{"error":"bad request"}"#, statusCode: 400)
        }
        await #expect(throws: MistralError.self) {
            _ = try await service.validateAPIKey()
        }
        #expect(callCount == 1)
    }
}
