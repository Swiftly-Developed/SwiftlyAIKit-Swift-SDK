import Foundation

/// DeepSeek API Models
///
/// Provider-specific types for DeepSeek's Chat Completions API.
///
/// ## See Also
/// - ``DeepSeekProvider``
/// - <doc:DeepSeekGuide>

// MARK: - Request Models

/// DeepSeek chat completion request (OpenAI-compatible)
public struct DeepSeekRequest: Codable, Sendable {
    /// Model to use for completion
    public let model: String

    /// Array of messages in the conversation
    public let messages: [DeepSeekMessage]

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

    /// Tools/functions available for calling (max 128)
    public let tools: [DeepSeekTool]?

    /// Control function calling behavior
    public let tool_choice: DeepSeekToolChoice?

    /// Response format for structured output
    public let response_format: DeepSeekResponseFormat?

    /// Stop sequences
    public let stop: [String]?

    /// Number of completions to generate
    public let n: Int?

    /// Unique identifier for tracking
    public let user: String?

    public init(
        model: String,
        messages: [DeepSeekMessage],
        temperature: Double? = nil,
        top_p: Double? = nil,
        max_tokens: Int? = nil,
        frequency_penalty: Double? = nil,
        presence_penalty: Double? = nil,
        stream: Bool? = nil,
        tools: [DeepSeekTool]? = nil,
        tool_choice: DeepSeekToolChoice? = nil,
        response_format: DeepSeekResponseFormat? = nil,
        stop: [String]? = nil,
        n: Int? = nil,
        user: String? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.top_p = top_p
        self.max_tokens = max_tokens
        self.frequency_penalty = frequency_penalty
        self.presence_penalty = presence_penalty
        self.stream = stream
        self.tools = tools
        self.tool_choice = tool_choice
        self.response_format = response_format
        self.stop = stop
        self.n = n
        self.user = user
    }
}

/// DeepSeek message in conversation
public struct DeepSeekMessage: Codable, Sendable {
    /// Role of the message sender
    public let role: String

    /// Content of the message (text or null for tool calls)
    public let content: String?

    /// Tool calls made by the assistant
    public let tool_calls: [DeepSeekToolCall]?

    /// Tool call ID (for tool role)
    public let tool_call_id: String?

    /// Function name (for function role, legacy)
    public let name: String?

    public init(
        role: String,
        content: String? = nil,
        tool_calls: [DeepSeekToolCall]? = nil,
        tool_call_id: String? = nil,
        name: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.tool_call_id = tool_call_id
        self.name = name
    }
}

/// DeepSeek tool definition
public struct DeepSeekTool: Codable, Sendable {
    /// Type of tool (always "function")
    public let type: String

    /// Function definition
    public let function: DeepSeekFunction

    public init(type: String = "function", function: DeepSeekFunction) {
        self.type = type
        self.function = function
    }
}

/// DeepSeek function definition
public struct DeepSeekFunction: Codable, Sendable {
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
public enum DeepSeekToolChoice: Codable, Sendable {
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
public struct DeepSeekResponseFormat: Codable, Sendable {
    /// Type of response format
    public let type: String

    /// JSON Schema for validation (optional)
    public let schema: [String: AnyCodable]?

    public init(type: String, schema: [String: AnyCodable]? = nil) {
        self.type = type
        self.schema = schema
    }
}

// MARK: - Response Models

/// DeepSeek chat completion response
public struct DeepSeekResponse: Codable, Sendable {
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
    public let choices: [DeepSeekChoice]

    /// Token usage information
    public let usage: DeepSeekUsage?

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        system_fingerprint: String? = nil,
        choices: [DeepSeekChoice],
        usage: DeepSeekUsage? = nil
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

/// DeepSeek completion choice
public struct DeepSeekChoice: Codable, Sendable {
    /// Index of this choice
    public let index: Int

    /// Generated message
    public let message: DeepSeekResponseMessage

    /// Reason for completion finish
    public let finish_reason: String?

    public init(index: Int, message: DeepSeekResponseMessage, finish_reason: String? = nil) {
        self.index = index
        self.message = message
        self.finish_reason = finish_reason
    }
}

/// DeepSeek response message
public struct DeepSeekResponseMessage: Codable, Sendable {
    /// Role of the message sender
    public let role: String

    /// Content of the message
    public let content: String?

    /// Tool calls made by the assistant
    public let tool_calls: [DeepSeekToolCall]?

    /// Reasoning content (for deepseek-reasoner model)
    public let reasoning_content: String?

    public init(
        role: String,
        content: String? = nil,
        tool_calls: [DeepSeekToolCall]? = nil,
        reasoning_content: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.reasoning_content = reasoning_content
    }
}

/// DeepSeek tool call
public struct DeepSeekToolCall: Codable, Sendable {
    /// Tool call ID
    public let id: String

    /// Type of tool (always "function")
    public let type: String

    /// Function call details
    public let function: DeepSeekFunctionCall

    public init(id: String, type: String = "function", function: DeepSeekFunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// DeepSeek function call
public struct DeepSeekFunctionCall: Codable, Sendable {
    /// Function name
    public let name: String

    /// Function arguments (JSON string)
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// DeepSeek token usage information
public struct DeepSeekUsage: Codable, Sendable {
    /// Number of tokens in the prompt
    public let prompt_tokens: Int

    /// Number of tokens in the completion
    public let completion_tokens: Int

    /// Total tokens used
    public let total_tokens: Int

    /// Prompt cache hit tokens (for prompt caching feature)
    public let prompt_cache_hit_tokens: Int?

    /// Prompt cache miss tokens (for prompt caching feature)
    public let prompt_cache_miss_tokens: Int?

    public init(
        prompt_tokens: Int,
        completion_tokens: Int,
        total_tokens: Int,
        prompt_cache_hit_tokens: Int? = nil,
        prompt_cache_miss_tokens: Int? = nil
    ) {
        self.prompt_tokens = prompt_tokens
        self.completion_tokens = completion_tokens
        self.total_tokens = total_tokens
        self.prompt_cache_hit_tokens = prompt_cache_hit_tokens
        self.prompt_cache_miss_tokens = prompt_cache_miss_tokens
    }
}

// MARK: - Streaming Models

/// DeepSeek streaming chunk
public struct DeepSeekStreamChunk: Codable, Sendable {
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
    public let choices: [DeepSeekDeltaChoice]

    /// Token usage (only in final chunk)
    public let usage: DeepSeekUsage?

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        system_fingerprint: String? = nil,
        choices: [DeepSeekDeltaChoice],
        usage: DeepSeekUsage? = nil
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

/// DeepSeek delta choice for streaming
public struct DeepSeekDeltaChoice: Codable, Sendable {
    /// Index of this choice
    public let index: Int

    /// Incremental message delta
    public let delta: DeepSeekDelta

    /// Reason for completion finish (only in final chunk)
    public let finish_reason: String?

    public init(index: Int, delta: DeepSeekDelta, finish_reason: String? = nil) {
        self.index = index
        self.delta = delta
        self.finish_reason = finish_reason
    }
}

/// DeepSeek incremental message delta
public struct DeepSeekDelta: Codable, Sendable {
    /// Role of the message sender (only in first chunk)
    public let role: String?

    /// Incremental content
    public let content: String?

    /// Tool calls (incremental)
    public let tool_calls: [DeepSeekToolCall]?

    /// Reasoning content delta (for deepseek-reasoner model)
    public let reasoning_content: String?

    public init(
        role: String? = nil,
        content: String? = nil,
        tool_calls: [DeepSeekToolCall]? = nil,
        reasoning_content: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.reasoning_content = reasoning_content
    }
}

// MARK: - Models List Response

/// Response from DeepSeek's GET /models endpoint (OpenAI-compatible)
public struct DeepSeekModelsResponse: Codable, Sendable {
    /// Object type (always "list")
    public let object: String
    /// Array of available models
    public let data: [DeepSeekModelInfo]

    enum CodingKeys: String, CodingKey {
        case object
        case data
    }

    public init(object: String = "list", data: [DeepSeekModelInfo]) {
        self.object = object
        self.data = data
    }
}

/// DeepSeek model information (one entry from GET /models)
public struct DeepSeekModelInfo: Codable, Sendable {
    /// Model ID, e.g. "deepseek-chat"
    public let id: String
    /// Object type (always "model")
    public let object: String
    /// Organization that owns the model, e.g. "deepseek"
    public let ownedBy: String

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case ownedBy = "owned_by"
    }

    public init(id: String, object: String = "model", ownedBy: String = "deepseek") {
        self.id = id
        self.object = object
        self.ownedBy = ownedBy
    }
}

// MARK: - Error Models

/// DeepSeek error response
public struct DeepSeekError: Codable, Sendable, Error {
    /// Error details
    public let error: DeepSeekErrorDetail

    public init(error: DeepSeekErrorDetail) {
        self.error = error
    }
}

/// DeepSeek error detail
public struct DeepSeekErrorDetail: Codable, Sendable {
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
