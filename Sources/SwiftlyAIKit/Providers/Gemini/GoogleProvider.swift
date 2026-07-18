import Foundation

/// Google AI provider — a thin alias that delegates to ``GeminiProvider``.
///
/// This type exists for naming parity with ``ProviderType/google``. It forwards every
/// operation to an internal ``GeminiProvider``, so both public types behave identically.
///
/// Previously this was an unimplemented stub that threw ``AIError/unsupportedFeature(feature:provider:)``;
/// the gateway now registers ``GeminiProvider`` directly, but this alias remains fully functional
/// for any caller that constructs it explicitly.
///
/// ## See Also
/// - ``GeminiProvider``
/// - <doc:GeminiGuide>
public struct GoogleProvider: ProviderProtocol {
    public let providerType: ProviderType = .google

    /// The real implementation all calls are forwarded to.
    private let gemini: GeminiProvider

    /// Initialize a Google provider backed by a ``GeminiProvider``.
    /// - Parameters:
    ///   - baseURL: Base URL for the Gemini API (default: https://generativelanguage.googleapis.com/v1beta)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta",
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.gemini = GeminiProvider(
            baseURL: baseURL,
            timeout: timeout,
            maxRetries: maxRetries,
            enableLogging: enableLogging
        )
    }

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        try await gemini.sendMessage(request, apiKey: apiKey)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        gemini.streamMessage(request, apiKey: apiKey)
    }

    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int? {
        try await gemini.countTokens(request, apiKey: apiKey)
    }

    /// List available Google Gemini models. Forwards to ``GeminiProvider/listModels(apiKey:)``.
    /// - Parameter apiKey: API key for authentication
    /// - Returns: The raw model list from Google's `models.list` endpoint
    public func listModels(apiKey: String) async throws -> GeminiModelsResponse {
        try await gemini.listModels(apiKey: apiKey)
    }
}
