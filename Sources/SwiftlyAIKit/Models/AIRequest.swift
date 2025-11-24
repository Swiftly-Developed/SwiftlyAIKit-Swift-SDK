import Foundation

/// Represents a provider-agnostic AI completion request
///
/// This structure provides a unified interface for making requests to different AI providers.
/// Provider-specific implementations will map this to their native request formats.
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
        toolChoice: AIToolChoice? = nil
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
