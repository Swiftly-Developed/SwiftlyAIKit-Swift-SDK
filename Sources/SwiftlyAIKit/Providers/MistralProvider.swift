import Foundation

/// Mistral AI provider implementation (placeholder)
public struct MistralProvider: ProviderProtocol {
    public let providerType: ProviderType = .mistral

    public init() {}

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        throw AIError.unsupportedFeature(feature: "Mistral AI provider", provider: .mistral)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.unsupportedFeature(feature: "Mistral AI provider", provider: .mistral))
        }
    }
}
