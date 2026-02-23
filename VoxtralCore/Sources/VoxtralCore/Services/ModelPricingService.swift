import Foundation

public struct ModelPricing: Sendable {
    public let modelId: String
    public let inputPricePerMillion: Double
    public let outputPricePerMillion: Double

    public var estimatedCostPerMemo: String {
        // Average memo: ~500 input tokens (transcript) + ~200 output tokens (summary)
        let cost = (500.0 * inputPricePerMillion + 200.0 * outputPricePerMillion) / 1_000_000.0
        if cost < 0.001 {
            return "<$0.001"
        }
        return String(format: "$%.3f", cost)
    }
}

public final class ModelPricingService: Sendable {
    public static let shared = ModelPricingService()

    // Pricing as of February 2025 — see mistral.ai/pricing
    public let pricing: [String: ModelPricing] = [
        "mistral-large-latest": ModelPricing(modelId: "mistral-large-latest", inputPricePerMillion: 2.0, outputPricePerMillion: 6.0),
        "mistral-small-latest": ModelPricing(modelId: "mistral-small-latest", inputPricePerMillion: 0.1, outputPricePerMillion: 0.3),
        "pixtral-large-latest": ModelPricing(modelId: "pixtral-large-latest", inputPricePerMillion: 2.0, outputPricePerMillion: 6.0),
        "open-mistral-nemo": ModelPricing(modelId: "open-mistral-nemo", inputPricePerMillion: 0.15, outputPricePerMillion: 0.15),
        "ministral-8b-latest": ModelPricing(modelId: "ministral-8b-latest", inputPricePerMillion: 0.1, outputPricePerMillion: 0.1),
    ]

    // Transcription: $0.003 per minute
    public let transcriptionCostPerMinute: Double = 0.003

    public init() {}

    public func pricingFor(modelId: String) -> ModelPricing? {
        // Try exact match first, then prefix match
        if let exact = pricing[modelId] { return exact }
        return pricing.first { modelId.hasPrefix($0.key.replacingOccurrences(of: "-latest", with: "")) }?.value
    }
}
