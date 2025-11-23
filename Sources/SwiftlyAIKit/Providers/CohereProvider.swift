import Foundation

/// Cohere provider implementation (placeholder)
public struct CohereProvider: ProviderProtocol {
    public let providerType: ProviderType = .cohere

    public init() {}

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        throw AIError.unsupportedFeature(feature: "Cohere provider", provider: .cohere)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.unsupportedFeature(feature: "Cohere provider", provider: .cohere))
        }
    }
}
