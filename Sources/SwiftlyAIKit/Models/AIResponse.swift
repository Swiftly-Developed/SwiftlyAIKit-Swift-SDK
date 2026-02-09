import Foundation

/// Represents the reason why generation stopped
public enum AIStopReason: String, Codable, Sendable {
    /// Natural end of message
    case endTurn = "end_turn"

    /// Maximum tokens reached
    case maxTokens = "max_tokens"

    /// Stop sequence matched
    case stopSequence = "stop_sequence"

    /// Tool/function was invoked
    case toolUse = "tool_use"

    /// Content was filtered
    case contentFilter = "content_filter"

    /// Other/unknown reason
    case other
}

/// Token usage statistics
public struct AIUsage: Codable, Sendable {
    /// Tokens in the input/prompt
    public let inputTokens: Int

    /// Tokens in the output/completion
    public let outputTokens: Int

    /// Total tokens used
    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    /// Cached tokens (if prompt caching was used)
    public let cachedTokens: Int?

    /// Reasoning tokens (for models with reasoning capabilities like Grok 4)
    public let reasoningTokens: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cachedTokens: Int? = nil,
        reasoningTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedTokens = cachedTokens
        self.reasoningTokens = reasoningTokens
    }
}

/// Represents a provider-agnostic AI completion response
///
/// `AIResponse` is the universal response format returned by all AI providers in SwiftlyAIKit.
///
/// ## Overview
///
/// Every successful AI request returns an `AIResponse` containing:
/// - The AI's message (``message``)
/// - Why it stopped generating (``stopReason``)
/// - Token usage for billing (``usage``)
/// - Metadata and provider-specific data
///
/// ## Quick Example
///
/// ```swift
/// let response = try await gateway.sendMessage(request)
///
/// print(response.message.content)
/// print("Tokens used: \(response.usage?.totalTokens ?? 0)")
/// print("Stop reason: \(response.stopReason?.rawValue ?? "unknown")")
/// ```
///
/// ## Accessing Content
///
/// ```swift
/// // Get text content directly
/// let text = response.message.content
///
/// // Or use convenience property
/// let text2 = response.textContent
/// ```
///
/// ## Token Usage
///
/// ```swift
/// if let usage = response.usage {
///     print("Input tokens: \(usage.inputTokens)")
///     print("Output tokens: \(usage.outputTokens)")
///     print("Total: \(usage.totalTokens)")
///
///     // Calculate cost
///     let cost = Double(usage.totalTokens) * 0.000003
///     print("Cost: $\(cost)")
/// }
/// ```
///
/// ## Topics
///
/// ### Response Properties
/// - ``id``
/// - ``model``
/// - ``message``
/// - ``stopReason``
/// - ``usage``
/// - ``provider``
/// - ``createdAt``
/// - ``metadata``
/// - ``providerData``
///
/// ### Convenience Properties
/// - ``textContent``
///
/// ### Related Types
/// - ``AIMessage``
/// - ``AIStopReason``
/// - ``AIUsage``
/// - ``ProviderType``
/// - ``AIRequest``
///
/// ## See Also
/// - ``AIGateway/sendMessage(_:to:clientAPIKey:)``
/// - ``AIMessage``
/// - ``AIUsage``
public struct AIResponse: Codable, Sendable {
    /// Unique identifier for this response
    public let id: String

    /// The model that generated the response
    public let model: String

    /// The generated message
    public let message: AIMessage

    /// Why generation stopped
    public let stopReason: AIStopReason?

    /// Token usage statistics
    public let usage: AIUsage?

    /// Provider that generated this response
    public let provider: ProviderType

    /// Response timestamp
    public let createdAt: Date

    /// Custom metadata
    public let metadata: [String: String]?

    /// Provider-specific data
    public let providerData: [String: AnyCodable]?

    /// Initialize a new AI response
    ///
    /// - Parameters:
    ///   - id: Unique response identifier
    ///   - model: Model that generated the response
    ///   - message: The generated message
    ///   - stopReason: Why generation stopped (optional)
    ///   - usage: Token usage statistics (optional)
    ///   - provider: Provider that generated the response
    ///   - createdAt: Response timestamp
    ///   - metadata: Custom metadata (optional)
    ///   - providerData: Provider-specific data (optional)
    public init(
        id: String,
        model: String,
        message: AIMessage,
        stopReason: AIStopReason? = nil,
        usage: AIUsage? = nil,
        provider: ProviderType,
        createdAt: Date = Date(),
        metadata: [String: String]? = nil,
        providerData: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.model = model
        self.message = message
        self.stopReason = stopReason
        self.usage = usage
        self.provider = provider
        self.createdAt = createdAt
        self.metadata = metadata
        self.providerData = providerData
    }

    /// Convenience property to get the text content of the response
    public var textContent: String {
        message.textContent
    }
}
