import Testing
@testable import VoxtralCore

@Suite("MistralModel.displayName")
struct MistralModelTests {

    @Test("versioned model: voxtral-mini-transcribe-26-02")
    func versionedModel() {
        let model = MistralModel(id: "voxtral-mini-transcribe-26-02", name: "", capabilities: [])
        #expect(model.displayName == "Voxtral Mini Transcribe v26.02")
    }

    @Test("latest model: mistral-small-latest")
    func latestModel() {
        let model = MistralModel(id: "mistral-small-latest", name: "", capabilities: [])
        #expect(model.displayName == "Mistral Small Latest")
    }

    @Test("single-word model ID")
    func singleWord() {
        let model = MistralModel(id: "codestral", name: "", capabilities: [])
        #expect(model.displayName == "Codestral")
    }

    @Test("two-part version: voxtral-mini-transcribe-25-07")
    func twoPartVersion() {
        let model = MistralModel(id: "voxtral-mini-transcribe-25-07", name: "", capabilities: [])
        #expect(model.displayName == "Voxtral Mini Transcribe v25.07")
    }
}
