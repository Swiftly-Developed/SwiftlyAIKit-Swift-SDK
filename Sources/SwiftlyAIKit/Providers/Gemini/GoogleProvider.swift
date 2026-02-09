import Foundation

/// Google AI provider implementation (alias for GeminiProvider)
///
/// ## See Also
/// - ``GeminiProvider``
/// - <doc:GeminiGuide>
public struct GoogleProvider: ProviderProtocol {
    public let providerType: ProviderType = .google

    public init() {}

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        throw AIError.unsupportedFeature(feature: "Google AI provider", provider: .google)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.unsupportedFeature(feature: "Google AI provider", provider: .google))
        }
    }
}
