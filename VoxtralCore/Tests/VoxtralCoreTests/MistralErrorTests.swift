import Testing
@testable import VoxtralCore

@Suite("MistralError.isRetryable")
struct MistralErrorTests {

    @Test("429 Too Many Requests is retryable")
    func rateLimited() {
        let error = MistralError.apiError(statusCode: 429, message: "rate limited")
        #expect(error.isRetryable == true)
    }

    @Test("500 Internal Server Error is retryable")
    func internalServerError() {
        let error = MistralError.apiError(statusCode: 500, message: "server error")
        #expect(error.isRetryable == true)
    }

    @Test("502 Bad Gateway is retryable")
    func badGateway() {
        let error = MistralError.apiError(statusCode: 502, message: "bad gateway")
        #expect(error.isRetryable == true)
    }

    @Test("503 Service Unavailable is retryable")
    func serviceUnavailable() {
        let error = MistralError.apiError(statusCode: 503, message: "unavailable")
        #expect(error.isRetryable == true)
    }

    @Test("504 Gateway Timeout is retryable")
    func gatewayTimeout() {
        let error = MistralError.apiError(statusCode: 504, message: "timeout")
        #expect(error.isRetryable == true)
    }

    @Test("401 Unauthorized is not retryable")
    func unauthorized() {
        let error = MistralError.apiError(statusCode: 401, message: "unauthorized")
        #expect(error.isRetryable == false)
    }

    @Test("400 Bad Request is not retryable")
    func badRequest() {
        let error = MistralError.apiError(statusCode: 400, message: "bad request")
        #expect(error.isRetryable == false)
    }

    @Test("missingAPIKey is not retryable")
    func missingAPIKey() {
        #expect(MistralError.missingAPIKey.isRetryable == false)
    }

    @Test("emptyResponse is not retryable")
    func emptyResponse() {
        #expect(MistralError.emptyResponse.isRetryable == false)
    }

    @Test("invalidResponse is not retryable")
    func invalidResponse() {
        #expect(MistralError.invalidResponse.isRetryable == false)
    }
}
