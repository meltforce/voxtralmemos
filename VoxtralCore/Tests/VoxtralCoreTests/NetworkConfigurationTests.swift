import Testing
@testable import VoxtralCore

@Suite("NetworkConfiguration")
struct NetworkConfigurationTests {

    @Test("default preset values")
    func defaultPreset() {
        let config = NetworkConfiguration.default
        #expect(config.requestTimeout == 30)
        #expect(config.resourceTimeout == 300)
        #expect(config.maxRetries == 3)
        #expect(config.baseRetryDelay == 1)
    }

    @Test("transcription preset values")
    func transcriptionPreset() {
        let config = NetworkConfiguration.transcription
        #expect(config.requestTimeout == 60)
        #expect(config.resourceTimeout == 600)
        #expect(config.maxRetries == 2)
        #expect(config.baseRetryDelay == 2)
    }

    @Test("custom configuration")
    func customConfig() {
        let config = NetworkConfiguration(
            requestTimeout: 10,
            resourceTimeout: 120,
            maxRetries: 5,
            baseRetryDelay: 0.5
        )
        #expect(config.requestTimeout == 10)
        #expect(config.resourceTimeout == 120)
        #expect(config.maxRetries == 5)
        #expect(config.baseRetryDelay == 0.5)
    }
}
