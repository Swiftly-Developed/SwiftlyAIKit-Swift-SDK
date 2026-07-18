import Foundation

/// Groq API Models
///
/// Provider-specific types for Groq's OpenAI-compatible Chat Completions API.
///
/// ## See Also
/// - ``GroqProvider``

// MARK: - Request Models

/// Groq chat completion request (OpenAI-compatible)
public struct GroqRequest: Codable, Sendable {
    /// Model to use for completion
    public let model: String

    /// Array of messages in the conversation
    public let messages: [GroqMessage]

    /// Sampling temperature (0-2, default: 1)
    public let temperature: Double?

    /// Nucleus sampling parameter (0-1, default: 1)
    public let top_p: Double?

    /// Maximum number of tokens to generate
    public let max_tokens: Int?

    /// Frequency penalty (-2 to 2, default: 0)
    public let frequency_penalty: Double?

    /// Presence penalty (-2 to 2, default: 0)
    public let presence_penalty: Double?

    /// Enable SSE streaming
    public let stream: Bool?

    /// Include usage in streaming response
    public let stream_options: GroqStreamOptions?

    /// Tools/functions available for calling
    public let tools: [GroqTool]?

    /// Control function calling behavior
    public let tool_choice: GroqToolChoice?

    /// Response format for structured output
    public let response_format: GroqResponseFormat?

    /// Stop sequences
    public let stop: [String]?

    /// Number of completions to generate
    public let n: Int?

    /// Unique identifier for tracking
    public let user: String?

    /// Seed for deterministic outputs
    public let seed: Int?

    /// Log probabilities configuration
    public let logprobs: Bool?

    /// Number of top log probabilities to return
    public let top_logprobs: Int?

    public init(
        model: String,
        messages: [GroqMessage],
        temperature: Double? = nil,
        top_p: Double? = nil,
        max_tokens: Int? = nil,
        frequency_penalty: Double? = nil,
        presence_penalty: Double? = nil,
        stream: Bool? = nil,
        stream_options: GroqStreamOptions? = nil,
        tools: [GroqTool]? = nil,
        tool_choice: GroqToolChoice? = nil,
        response_format: GroqResponseFormat? = nil,
        stop: [String]? = nil,
        n: Int? = nil,
        user: String? = nil,
        seed: Int? = nil,
        logprobs: Bool? = nil,
        top_logprobs: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.top_p = top_p
        self.max_tokens = max_tokens
        self.frequency_penalty = frequency_penalty
        self.presence_penalty = presence_penalty
        self.stream = stream
        self.stream_options = stream_options
        self.tools = tools
        self.tool_choice = tool_choice
        self.response_format = response_format
        self.stop = stop
        self.n = n
        self.user = user
        self.seed = seed
        self.logprobs = logprobs
        self.top_logprobs = top_logprobs
    }
}

/// Stream options for Groq
public struct GroqStreamOptions: Codable, Sendable {
    /// Include usage statistics in stream
    public let include_usage: Bool?

    public init(include_usage: Bool? = nil) {
        self.include_usage = include_usage
    }
}

/// Groq message in conversation
public struct GroqMessage: Codable, Sendable {
    /// Role of the message sender
    public let role: String

    /// Content of the message (text, array for multimodal, or null for tool calls)
    public let content: GroqMessageContent?

    /// Tool calls made by the assistant
    public let tool_calls: [GroqToolCall]?

    /// Tool call ID (for tool role)
    public let tool_call_id: String?

    /// Name (for function role, legacy)
    public let name: String?

    public init(
        role: String,
        content: GroqMessageContent? = nil,
        tool_calls: [GroqToolCall]? = nil,
        tool_call_id: String? = nil,
        name: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.tool_call_id = tool_call_id
        self.name = name
    }

    /// Convenience initializer for text-only messages
    public init(role: String, text: String) {
        self.role = role
        self.content = .text(text)
        self.tool_calls = nil
        self.tool_call_id = nil
        self.name = nil
    }
}

/// Groq message content (text or multimodal array)
public enum GroqMessageContent: Codable, Sendable {
    case text(String)
    case multimodal([GroqContentPart])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .multimodal(let parts):
            try container.encode(parts)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let parts = try? container.decode([GroqContentPart].self) {
            self = .multimodal(parts)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid content format")
        }
    }

    /// Get text content if available
    public var textValue: String? {
        switch self {
        case .text(let text):
            return text
        case .multimodal(let parts):
            return parts.compactMap { part -> String? in
                if case .text(let text) = part {
                    return text
                }
                return nil
            }.joined(separator: " ")
        }
    }
}

/// Groq content part for multimodal messages
public enum GroqContentPart: Codable, Sendable {
    case text(String)
    case imageUrl(GroqImageUrl)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case image_url
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageUrl(let imageUrl):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageUrl, forKey: .image_url)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageUrl = try container.decode(GroqImageUrl.self, forKey: .image_url)
            self = .imageUrl(imageUrl)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }
}

/// Groq image URL for vision
public struct GroqImageUrl: Codable, Sendable {
    /// URL of the image (can be URL or base64 data URL)
    public let url: String

    /// Detail level (auto, low, high)
    public let detail: String?

    public init(url: String, detail: String? = nil) {
        self.url = url
        self.detail = detail
    }
}

/// Groq tool definition
public struct GroqTool: Codable, Sendable {
    /// Type of tool (always "function")
    public let type: String

    /// Function definition
    public let function: GroqFunction

    public init(type: String = "function", function: GroqFunction) {
        self.type = type
        self.function = function
    }
}

/// Groq function definition
public struct GroqFunction: Codable, Sendable {
    /// Function name
    public let name: String

    /// Function description
    public let description: String?

    /// JSON Schema for parameters
    public let parameters: [String: AnyCodable]?

    /// Strict mode for parameter validation
    public let strict: Bool?

    public init(
        name: String,
        description: String? = nil,
        parameters: [String: AnyCodable]? = nil,
        strict: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }
}

/// Tool choice control
public enum GroqToolChoice: Codable, Sendable {
    case none
    case auto
    case required
    case function(String)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .function(let name):
            struct FunctionChoice: Codable {
                let type: String
                let function: FunctionName

                struct FunctionName: Codable {
                    let name: String
                }
            }
            let choice = FunctionChoice(type: "function", function: FunctionChoice.FunctionName(name: name))
            try container.encode(choice)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            switch str {
            case "none": self = .none
            case "auto": self = .auto
            case "required": self = .required
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid tool choice")
            }
        } else if let dict = try? container.decode([String: [String: String]].self),
                  let funcName = dict["function"]?["name"] {
            self = .function(funcName)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid tool choice format")
        }
    }
}

/// Response format for structured output
public struct GroqResponseFormat: Codable, Sendable {
    /// Type of response format ("text" or "json_object" or "json_schema")
    public let type: String

    /// JSON Schema for validation (optional, for json_schema type)
    public let json_schema: GroqJsonSchema?

    public init(type: String, json_schema: GroqJsonSchema? = nil) {
        self.type = type
        self.json_schema = json_schema
    }

    /// Create a text response format
    public static var text: Self {
        Self(type: "text")
    }

    /// Create a JSON object response format
    public static var jsonObject: Self {
        Self(type: "json_object")
    }

    /// Create a JSON schema response format
    public static func jsonSchema(_ schema: GroqJsonSchema) -> Self {
        Self(type: "json_schema", json_schema: schema)
    }
}

/// JSON Schema definition for structured outputs
public struct GroqJsonSchema: Codable, Sendable {
    /// Name of the schema
    public let name: String

    /// Description of the schema
    public let description: String?

    /// The JSON Schema object
    public let schema: [String: AnyCodable]

    /// Whether to enforce strict schema validation
    public let strict: Bool?

    public init(name: String, description: String? = nil, schema: [String: AnyCodable], strict: Bool? = nil) {
        self.name = name
        self.description = description
        self.schema = schema
        self.strict = strict
    }
}

// MARK: - Response Models

/// Groq chat completion response
public struct GroqResponse: Codable, Sendable {
    /// Unique identifier for the completion
    public let id: String

    /// Object type (always "chat.completion")
    public let object: String

    /// Unix timestamp of creation
    public let created: Int

    /// Model used for completion
    public let model: String

    /// System fingerprint
    public let system_fingerprint: String?

    /// Array of completion choices
    public let choices: [GroqChoice]

    /// Token usage information
    public let usage: GroqUsage?

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        system_fingerprint: String? = nil,
        choices: [GroqChoice],
        usage: GroqUsage? = nil
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.system_fingerprint = system_fingerprint
        self.choices = choices
        self.usage = usage
    }
}

/// Groq completion choice
public struct GroqChoice: Codable, Sendable {
    /// Index of this choice
    public let index: Int

    /// Generated message
    public let message: GroqResponseMessage

    /// Reason for completion finish
    public let finish_reason: String?

    /// Log probabilities (if requested)
    public let logprobs: GroqLogprobs?

    public init(index: Int, message: GroqResponseMessage, finish_reason: String? = nil, logprobs: GroqLogprobs? = nil) {
        self.index = index
        self.message = message
        self.finish_reason = finish_reason
        self.logprobs = logprobs
    }
}

/// Groq log probabilities
public struct GroqLogprobs: Codable, Sendable {
    /// Array of log probability content
    public let content: [GroqLogprobContent]?

    public init(content: [GroqLogprobContent]? = nil) {
        self.content = content
    }
}

/// Groq log probability content
public struct GroqLogprobContent: Codable, Sendable {
    /// The token
    public let token: String

    /// Log probability of this token
    public let logprob: Double

    /// UTF-8 byte representation
    public let bytes: [Int]?

    /// Top log probabilities
    public let top_logprobs: [GroqTopLogprob]?

    public init(token: String, logprob: Double, bytes: [Int]? = nil, top_logprobs: [GroqTopLogprob]? = nil) {
        self.token = token
        self.logprob = logprob
        self.bytes = bytes
        self.top_logprobs = top_logprobs
    }
}

/// Groq top log probability entry
public struct GroqTopLogprob: Codable, Sendable {
    /// The token
    public let token: String

    /// Log probability
    public let logprob: Double

    /// UTF-8 byte representation
    public let bytes: [Int]?

    public init(token: String, logprob: Double, bytes: [Int]? = nil) {
        self.token = token
        self.logprob = logprob
        self.bytes = bytes
    }
}

/// Groq response message
public struct GroqResponseMessage: Codable, Sendable {
    /// Role of the message sender
    public let role: String

    /// Content of the message
    public let content: String?

    /// Tool calls made by the assistant
    public let tool_calls: [GroqToolCall]?

    /// Refusal message (if content was refused)
    public let refusal: String?

    public init(
        role: String,
        content: String? = nil,
        tool_calls: [GroqToolCall]? = nil,
        refusal: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.refusal = refusal
    }
}

/// Groq tool call
public struct GroqToolCall: Codable, Sendable {
    /// Tool call ID
    public let id: String

    /// Type of tool (always "function")
    public let type: String

    /// Function call details
    public let function: GroqFunctionCall

    public init(id: String, type: String = "function", function: GroqFunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Groq function call
public struct GroqFunctionCall: Codable, Sendable {
    /// Function name
    public let name: String

    /// Function arguments (JSON string)
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// Groq token usage information
public struct GroqUsage: Codable, Sendable {
    /// Number of tokens in the prompt
    public let prompt_tokens: Int

    /// Number of tokens in the completion
    public let completion_tokens: Int

    /// Total tokens used
    public let total_tokens: Int

    /// Detailed prompt token information
    public let prompt_tokens_details: GroqPromptTokensDetails?

    /// Detailed completion token information
    public let completion_tokens_details: GroqCompletionTokensDetails?

    public init(
        prompt_tokens: Int,
        completion_tokens: Int,
        total_tokens: Int,
        prompt_tokens_details: GroqPromptTokensDetails? = nil,
        completion_tokens_details: GroqCompletionTokensDetails? = nil
    ) {
        self.prompt_tokens = prompt_tokens
        self.completion_tokens = completion_tokens
        self.total_tokens = total_tokens
        self.prompt_tokens_details = prompt_tokens_details
        self.completion_tokens_details = completion_tokens_details
    }
}

/// Groq prompt tokens details
public struct GroqPromptTokensDetails: Codable, Sendable {
    /// Cached tokens (from automatic prompt caching)
    public let cached_tokens: Int?

    /// Text tokens in prompt
    public let text_tokens: Int?

    /// Audio tokens in prompt (if applicable)
    public let audio_tokens: Int?

    /// Image tokens in prompt (if applicable)
    public let image_tokens: Int?

    public init(
        cached_tokens: Int? = nil,
        text_tokens: Int? = nil,
        audio_tokens: Int? = nil,
        image_tokens: Int? = nil
    ) {
        self.cached_tokens = cached_tokens
        self.text_tokens = text_tokens
        self.audio_tokens = audio_tokens
        self.image_tokens = image_tokens
    }
}

/// Groq completion tokens details
public struct GroqCompletionTokensDetails: Codable, Sendable {
    /// Reasoning tokens used (for models with reasoning)
    public let reasoning_tokens: Int?

    /// Text tokens in completion
    public let text_tokens: Int?

    /// Audio tokens in completion (if applicable)
    public let audio_tokens: Int?

    /// Accepted prediction tokens
    public let accepted_prediction_tokens: Int?

    /// Rejected prediction tokens
    public let rejected_prediction_tokens: Int?

    public init(
        reasoning_tokens: Int? = nil,
        text_tokens: Int? = nil,
        audio_tokens: Int? = nil,
        accepted_prediction_tokens: Int? = nil,
        rejected_prediction_tokens: Int? = nil
    ) {
        self.reasoning_tokens = reasoning_tokens
        self.text_tokens = text_tokens
        self.audio_tokens = audio_tokens
        self.accepted_prediction_tokens = accepted_prediction_tokens
        self.rejected_prediction_tokens = rejected_prediction_tokens
    }
}

// MARK: - Streaming Models

/// Groq streaming chunk
public struct GroqStreamChunk: Codable, Sendable {
    /// Unique identifier for the chunk
    public let id: String

    /// Object type (always "chat.completion.chunk")
    public let object: String

    /// Unix timestamp of creation
    public let created: Int

    /// Model used for completion
    public let model: String

    /// System fingerprint
    public let system_fingerprint: String?

    /// Array of delta choices
    public let choices: [GroqDeltaChoice]

    /// Token usage (only when stream_options.include_usage is true)
    public let usage: GroqUsage?

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        system_fingerprint: String? = nil,
        choices: [GroqDeltaChoice],
        usage: GroqUsage? = nil
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.system_fingerprint = system_fingerprint
        self.choices = choices
        self.usage = usage
    }
}

/// Groq delta choice for streaming
public struct GroqDeltaChoice: Codable, Sendable {
    /// Index of this choice
    public let index: Int

    /// Incremental message delta
    public let delta: GroqDelta

    /// Reason for completion finish (only in final chunk)
    public let finish_reason: String?

    /// Log probabilities (if requested)
    public let logprobs: GroqLogprobs?

    public init(index: Int, delta: GroqDelta, finish_reason: String? = nil, logprobs: GroqLogprobs? = nil) {
        self.index = index
        self.delta = delta
        self.finish_reason = finish_reason
        self.logprobs = logprobs
    }
}

/// Groq incremental message delta
public struct GroqDelta: Codable, Sendable {
    /// Role of the message sender (only in first chunk)
    public let role: String?

    /// Incremental content
    public let content: String?

    /// Tool calls (incremental)
    public let tool_calls: [GroqDeltaToolCall]?

    /// Refusal message delta
    public let refusal: String?

    public init(
        role: String? = nil,
        content: String? = nil,
        tool_calls: [GroqDeltaToolCall]? = nil,
        refusal: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.refusal = refusal
    }
}

/// Groq delta tool call for streaming
public struct GroqDeltaToolCall: Codable, Sendable {
    /// Index of the tool call
    public let index: Int

    /// Tool call ID (only in first chunk for this tool call)
    public let id: String?

    /// Type of tool (only in first chunk)
    public let type: String?

    /// Function call delta
    public let function: GroqDeltaFunctionCall?

    public init(index: Int, id: String? = nil, type: String? = nil, function: GroqDeltaFunctionCall? = nil) {
        self.index = index
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Groq delta function call for streaming
public struct GroqDeltaFunctionCall: Codable, Sendable {
    /// Function name (only in first chunk)
    public let name: String?

    /// Arguments delta
    public let arguments: String?

    public init(name: String? = nil, arguments: String? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Error Models

/// Groq error response
public struct GroqError: Codable, Sendable, Error {
    /// Error details
    public let error: GroqErrorDetail

    public init(error: GroqErrorDetail) {
        self.error = error
    }
}

/// Groq error detail
public struct GroqErrorDetail: Codable, Sendable {
    /// Error message
    public let message: String

    /// Error type
    public let type: String?

    /// Error code
    public let code: String?

    /// Parameter that caused the error
    public let param: String?

    public init(message: String, type: String? = nil, code: String? = nil, param: String? = nil) {
        self.message = message
        self.type = type
        self.code = code
        self.param = param
    }
}

// MARK: - Models List Response

/// Groq models list response
public struct GroqModelsResponse: Codable, Sendable {
    /// Object type
    public let object: String

    /// Array of available models
    public let data: [GroqModelInfo]

    public init(object: String, data: [GroqModelInfo]) {
        self.object = object
        self.data = data
    }
}

/// Groq model information
public struct GroqModelInfo: Codable, Sendable {
    /// Model ID
    public let id: String

    /// Object type
    public let object: String

    /// Unix timestamp of creation
    public let created: Int

    /// Owner of the model
    public let owned_by: String

    public init(id: String, object: String, created: Int, owned_by: String) {
        self.id = id
        self.object = object
        self.created = created
        self.owned_by = owned_by
    }
}
