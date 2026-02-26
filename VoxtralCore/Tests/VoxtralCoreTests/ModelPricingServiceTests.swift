import Testing
@testable import VoxtralCore

@Suite("ModelPricingService")
struct ModelPricingServiceTests {

    @Test("exact match returns correct pricing")
    func exactMatch() {
        let service = ModelPricingService()
        let pricing = service.pricingFor(modelId: "mistral-small-latest")
        #expect(pricing != nil)
        #expect(pricing?.inputPricePerMillion == 0.1)
        #expect(pricing?.outputPricePerMillion == 0.3)
    }

    @Test("prefix match works for versioned model IDs")
    func prefixMatch() {
        let service = ModelPricingService()
        let pricing = service.pricingFor(modelId: "mistral-small-2501")
        #expect(pricing != nil)
        #expect(pricing?.modelId == "mistral-small-latest")
    }

    @Test("unknown model returns nil")
    func unknownModel() {
        let service = ModelPricingService()
        let pricing = service.pricingFor(modelId: "nonexistent-model")
        #expect(pricing == nil)
    }

    @Test("estimatedCostPerMemo formats correctly")
    func costFormatting() {
        let pricing = ModelPricing(modelId: "test", inputPricePerMillion: 0.1, outputPricePerMillion: 0.3)
        // (500 * 0.1 + 200 * 0.3) / 1_000_000 = 110 / 1_000_000 = 0.00011
        #expect(pricing.estimatedCostPerMemo == "<$0.001")
    }

    @Test("estimatedCostPerMemo shows value for expensive models")
    func costFormattingExpensive() {
        let pricing = ModelPricing(modelId: "test", inputPricePerMillion: 2.0, outputPricePerMillion: 6.0)
        // (500 * 2.0 + 200 * 6.0) / 1_000_000 = 2200 / 1_000_000 = 0.0022
        #expect(pricing.estimatedCostPerMemo == "$0.002")
    }
}
