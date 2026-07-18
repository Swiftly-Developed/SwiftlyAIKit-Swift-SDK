import Foundation

/// Google AI provider — a thin alias that delegates to ``GeminiProvider``.
///
/// Both `GoogleProvider` and ``GeminiProvider`` target the same Google Generative
/// Language API and report ``ProviderType/google``. `AIGateway` registers
/// ``GeminiProvider`` for `.google`; this type exists so the `GoogleProvider` name
/// documented in earlier releases keeps working. Every call forwards verbatim to an
/// internal ``GeminiProvider`` — prefer using ``GeminiProvider`` directly.
///
/// ## See Also
/// - ``GeminiProvider``
/// - <doc:GeminiGuide>
public struct GoogleProvider: ProviderProtocol {
    public let providerType: ProviderType = .google

    /// The real implementation every call delegates to.
    private let gemini: GeminiProvider

    /// Initialize with the same options as ``GeminiProvider``.
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

    /// List available Gemini models. See ``GeminiProvider/listModels(apiKey:)``.
    public func listModels(apiKey: String) async throws -> GeminiModelsResponse {
        try await gemini.listModels(apiKey: apiKey)
    }
}
