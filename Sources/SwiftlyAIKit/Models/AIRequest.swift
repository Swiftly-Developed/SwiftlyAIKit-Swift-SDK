import Foundation

/// Represents a provider-agnostic AI completion request
///
/// `AIRequest` is the universal request format used across all AI providers in SwiftlyAIKit.
/// Create a request once, send to any provider.
///
/// ## Overview
///
/// Every AI interaction starts with an `AIRequest`. It contains:
/// - The model to use
/// - Conversation messages
/// - Optional parameters (temperature, max tokens, etc.)
/// - Optional tools for function calling
///
/// ## Quick Example
///
/// ```swift
/// let request = AIRequest(
///     model: .claude(.sonnet4_5),
///     prompt: "Explain quantum computing"
/// )
///
/// let response = try await gateway.sendMessage(request)
/// ```
///
/// ## With Conversation History
///
/// ```swift
/// let request = AIRequest(
///     model: .gpt4(.o),
///     messages: [
///         .user("What is AI?"),
///         .assistant("AI is..."),
///         .user("Tell me more")
///     ]
/// )
/// ```
///
/// ## With Parameters
///
/// ```swift
/// let request = AIRequest(
///     model: .claude(.sonnet4_5),
///     messages: [.user("Be creative!")],
///     temperature: 0.9,
///     maxTokens: 500
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Requests
/// - ``init(model:messages:maxTokens:systemPrompt:temperature:topP:topK:stopSequences:stream:metadata:providerOptions:tools:toolChoice:)``
/// - ``init(model:prompt:maxTokens:systemPrompt:temperature:)``
///
/// ### Request Properties
/// - ``model``
/// - ``messages``
/// - ``maxTokens``
/// - ``systemPrompt``
/// - ``temperature``
/// - ``topP``
/// - ``topK``
/// - ``stopSequences``
/// - ``stream``
/// - ``metadata``
/// - ``providerOptions``
/// - ``tools``
/// - ``toolChoice``
///
/// ### Related Types
/// - ``AIMessage``
/// - ``AIResponse``
/// - ``AITool``
/// - ``AIToolChoice``
/// - ``ModelProvider``
///
/// ## See Also
/// - <doc:QuickStart>
/// - ``AIGateway/sendMessage(_:to:clientAPIKey:)``
/// - ``AIGateway/streamMessage(_:to:clientAPIKey:)``
public struct AIRequest: Codable, Sendable {
    /// The model to use for completion
    public let model: String

    /// The conversation messages
    public let messages: [AIMessage]

    /// Maximum number of tokens to generate
    public let maxTokens: Int?

    /// System prompt/instructions (alternative to system messages)
    public let systemPrompt: String?

    /// Temperature (0.0 to 1.0+)
    public let temperature: Double?

    /// Top-p nucleus sampling
    public let topP: Double?

    /// Top-k sampling
    public let topK: Int?

    /// Stop sequences
    public let stopSequences: [String]?

    /// Enable streaming responses
    public let stream: Bool

    /// Custom metadata
    public let metadata: [String: String]?

    /// Provider-specific options
    public let providerOptions: [String: AnyCodable]?

    /// Tools/functions the model may call
    public let tools: [AITool]?

    /// Controls which tools the model may call
    public let toolChoice: AIToolChoice?

    /// Raw tool definitions as JSON Data, for provider-specific pass-through.
    /// When set, providers should use this instead of `tools` to preserve full schemas
    /// (e.g. nested object properties in array items) that the simplified AITool model cannot represent.
    public let rawToolsJSON: Data?

    /// Raw tool choice as JSON Data, for provider-specific pass-through.
    public let rawToolChoiceJSON: Data?

    /// Initialize a new AI request
    ///
    /// - Parameters:
    ///   - model: Model identifier
    ///   - messages: Conversation messages
    ///   - maxTokens: Maximum tokens to generate (optional)
    ///   - systemPrompt: System instructions (optional)
    ///   - temperature: Sampling temperature (optional)
    ///   - topP: Nucleus sampling threshold (optional)
    ///   - topK: Top-k sampling (optional)
    ///   - stopSequences: Custom stop sequences (optional)
    ///   - stream: Enable streaming (default false)
    ///   - metadata: Custom metadata (optional)
    ///   - providerOptions: Provider-specific options (optional)
    ///   - tools: Tools/functions the model may call (optional)
    ///   - toolChoice: Controls which tools the model may call (optional)
    ///   - rawToolsJSON: Raw tool definitions as JSON Data for pass-through (optional)
    ///   - rawToolChoiceJSON: Raw tool choice as JSON Data for pass-through (optional)
    public init(
        model: String,
        messages: [AIMessage],
        maxTokens: Int? = nil,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String]? = nil,
        stream: Bool = false,
        metadata: [String: String]? = nil,
        providerOptions: [String: AnyCodable]? = nil,
        tools: [AITool]? = nil,
        toolChoice: AIToolChoice? = nil,
        rawToolsJSON: Data? = nil,
        rawToolChoiceJSON: Data? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
        self.stream = stream
        self.metadata = metadata
        self.providerOptions = providerOptions
        self.tools = tools
        self.toolChoice = toolChoice
        self.rawToolsJSON = rawToolsJSON
        self.rawToolChoiceJSON = rawToolChoiceJSON
    }

    /// Convenience initializer for a simple text request
    ///
    /// - Parameters:
    ///   - model: Model identifier
    ///   - prompt: User prompt text
    ///   - maxTokens: Maximum tokens to generate
    ///   - systemPrompt: System instructions (optional)
    ///   - temperature: Sampling temperature (optional)
    public init(
        model: String,
        prompt: String,
        maxTokens: Int? = nil,
        systemPrompt: String? = nil,
        temperature: Double? = nil
    ) {
        self.init(
            model: model,
            messages: [AIMessage(role: .user, text: prompt)],
            maxTokens: maxTokens,
            systemPrompt: systemPrompt,
            temperature: temperature
        )
    }
}
