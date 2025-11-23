import Foundation

/// OpenAI provider implementation (placeholder)
public struct OpenAIProvider: ProviderProtocol {
    public let providerType: ProviderType = .openai

    public init() {}

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        throw AIError.unsupportedFeature(feature: "OpenAI provider", provider: .openai)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.unsupportedFeature(feature: "OpenAI provider", provider: .openai))
        }
    }
}
