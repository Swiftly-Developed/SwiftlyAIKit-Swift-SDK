import Foundation

/// Ollama API Models
///
/// Provider-specific types for Ollama's native `/api/chat` and `/api/tags` endpoints.
///
/// Ollama is a local/self-hosted LLM server. Its chat API differs from the OpenAI-compatible
/// shape used by most providers:
/// - Generation parameters nest under an `options` object (`num_predict`, `temperature`, …).
/// - Streaming is **newline-delimited JSON** (each line a full ``OllamaChatResponse``), not SSE —
///   there is no `data:` prefix and no `[DONE]` sentinel.
/// - Tool-call arguments are a JSON **object** (not a stringified JSON like OpenAI).
///
/// ## See Also
/// - ``OllamaProvider``

// MARK: - Request Models

/// Ollama chat request (`POST /api/chat`)
public struct OllamaChatRequest: Codable, Sendable {
    /// Model to use for completion (e.g. `llama3.2:latest`)
    public let model: String

    /// Array of messages in the conversation
    public let messages: [OllamaMessage]

    /// Whether to stream the response as newline-delimited JSON
    public let stream: Bool

    /// Tools/functions available for calling
    public let tools: [OllamaToolDefinition]?

    /// Generation options (temperature, num_predict, stop, …)
    public let options: OllamaOptions?

    public init(
        model: String,
        messages: [OllamaMessage],
        stream: Bool,
        tools: [OllamaToolDefinition]? = nil,
        options: OllamaOptions? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.tools = tools
        self.options = options
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case tools
        case options
    }
}

/// Ollama message in conversation
public struct OllamaMessage: Codable, Sendable {
    /// Role of the message sender (`system`, `user`, `assistant`, `tool`)
    public let role: String

    /// Text content of the message
    public let content: String?

    /// Base64-encoded images for multimodal (vision) requests
    public let images: [String]?

    /// Tool calls made by the assistant (for replaying a prior turn)
    public let toolCalls: [OllamaToolCall]?

    /// Tool call ID this message responds to (for `tool` role)
    public let toolCallID: String?

    public init(
        role: String,
        content: String? = nil,
        images: [String]? = nil,
        toolCalls: [OllamaToolCall]? = nil,
        toolCallID: String? = nil
    ) {
        self.role = role
        self.content = content
        self.images = images
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case images
        case toolCalls = "tool_calls"
        case toolCallID = "tool_call_id"
    }
}

/// Ollama tool definition
public struct OllamaToolDefinition: Codable, Sendable {
    /// Type of tool (always "function")
    public let type: String

    /// Function definition
    public let function: OllamaFunctionDefinition

    public init(type: String = "function", function: OllamaFunctionDefinition) {
        self.type = type
        self.function = function
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case function
    }
}

/// Ollama function definition
public struct OllamaFunctionDefinition: Codable, Sendable {
    /// Function name
    public let name: String

    /// Function description
    public let description: String?

    /// JSON Schema for parameters
    public let parameters: [String: AnyCodable]?

    public init(name: String, description: String? = nil, parameters: [String: AnyCodable]? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case parameters
    }
}

/// Ollama generation options
///
/// Ollama nests sampling/generation parameters under an `options` object rather than at the top
/// level. Max tokens is `num_predict`; stop sequences are `stop` (an array).
public struct OllamaOptions: Codable, Sendable {
    /// Sampling temperature
    public let temperature: Double?

    /// Nucleus sampling parameter
    public let topP: Double?

    /// Top-k sampling parameter
    public let topK: Int?

    /// Maximum number of tokens to generate (Ollama's `num_predict`)
    public let numPredict: Int?

    /// Stop sequences
    public let stop: [String]?

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        numPredict: Int? = nil,
        stop: [String]? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.numPredict = numPredict
        self.stop = stop
    }

    private enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case numPredict = "num_predict"
        case stop
    }

    /// Whether any option is set (used to omit an empty `options` object from the request).
    public var isEmpty: Bool {
        temperature == nil && topP == nil && topK == nil && numPredict == nil && stop == nil
    }
}

// MARK: - Response Models

/// Ollama chat response
///
/// Used for both the non-streaming response and each newline-delimited streaming line.
/// Intermediate streaming lines carry `done == false` and a partial `message.content`; the final
/// line carries `done == true`, `done_reason`, and the `prompt_eval_count`/`eval_count` token
/// counts.
public struct OllamaChatResponse: Codable, Sendable {
    /// Model that generated the response
    public let model: String

    /// ISO-8601 creation timestamp
    public let createdAt: String?

    /// The generated (or partial) message
    public let message: OllamaResponseMessage?

    /// Whether generation has finished
    public let done: Bool

    /// Reason generation stopped (`stop`, `length`, …); present on the final line
    public let doneReason: String?

    /// Number of tokens in the prompt (present on the final line)
    public let promptEvalCount: Int?

    /// Number of tokens generated (present on the final line)
    public let evalCount: Int?

    public init(
        model: String,
        createdAt: String? = nil,
        message: OllamaResponseMessage? = nil,
        done: Bool,
        doneReason: String? = nil,
        promptEvalCount: Int? = nil,
        evalCount: Int? = nil
    ) {
        self.model = model
        self.createdAt = createdAt
        self.message = message
        self.done = done
        self.doneReason = doneReason
        self.promptEvalCount = promptEvalCount
        self.evalCount = evalCount
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
        case doneReason = "done_reason"
        case promptEvalCount = "prompt_eval_count"
        case evalCount = "eval_count"
    }
}

/// Ollama response message
public struct OllamaResponseMessage: Codable, Sendable {
    /// Role of the message sender
    public let role: String

    /// Content of the message (may be a partial delta while streaming)
    public let content: String?

    /// Tool calls made by the assistant
    public let toolCalls: [OllamaToolCall]?

    public init(role: String, content: String? = nil, toolCalls: [OllamaToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
    }
}

/// Ollama tool call
///
/// Ollama tool calls carry only a `function` (no `id`/`type`), and `function.arguments` is a JSON
/// **object** rather than a stringified JSON.
public struct OllamaToolCall: Codable, Sendable {
    /// Function call details
    public let function: OllamaToolCallFunction

    public init(function: OllamaToolCallFunction) {
        self.function = function
    }

    private enum CodingKeys: String, CodingKey {
        case function
    }
}

/// Ollama tool call function
public struct OllamaToolCallFunction: Codable, Sendable {
    /// Function name
    public let name: String

    /// Function arguments as a JSON object
    public let arguments: AnyCodable

    public init(name: String, arguments: AnyCodable) {
        self.name = name
        self.arguments = arguments
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case arguments
    }
}

// MARK: - Models List Response

/// Ollama models list response (`GET /api/tags`)
public struct OllamaModelsResponse: Codable, Sendable {
    /// Array of locally-available models
    public let models: [OllamaModelInfo]

    public init(models: [OllamaModelInfo]) {
        self.models = models
    }

    private enum CodingKeys: String, CodingKey {
        case models
    }
}

/// Ollama model information
public struct OllamaModelInfo: Codable, Sendable {
    /// Model name (e.g. `llama3.2:latest`)
    public let name: String

    /// Model identifier
    public let model: String

    /// ISO-8601 last-modified timestamp
    public let modifiedAt: String?

    /// Size in bytes
    public let size: Int64?

    /// Content digest
    public let digest: String?

    /// Detailed model metadata
    public let details: OllamaModelDetails?

    public init(
        name: String,
        model: String,
        modifiedAt: String? = nil,
        size: Int64? = nil,
        digest: String? = nil,
        details: OllamaModelDetails? = nil
    ) {
        self.name = name
        self.model = model
        self.modifiedAt = modifiedAt
        self.size = size
        self.digest = digest
        self.details = details
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case model
        case modifiedAt = "modified_at"
        case size
        case digest
        case details
    }
}

/// Ollama model details
public struct OllamaModelDetails: Codable, Sendable {
    /// Model file format (e.g. `gguf`)
    public let format: String?

    /// Model family (e.g. `llama`)
    public let family: String?

    /// Model families
    public let families: [String]?

    /// Parameter size (e.g. `3.2B`)
    public let parameterSize: String?

    /// Quantization level (e.g. `Q4_K_M`)
    public let quantizationLevel: String?

    public init(
        format: String? = nil,
        family: String? = nil,
        families: [String]? = nil,
        parameterSize: String? = nil,
        quantizationLevel: String? = nil
    ) {
        self.format = format
        self.family = family
        self.families = families
        self.parameterSize = parameterSize
        self.quantizationLevel = quantizationLevel
    }

    private enum CodingKeys: String, CodingKey {
        case format
        case family
        case families
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

// MARK: - Error Models

/// Ollama error response
public struct OllamaError: Codable, Sendable, Error {
    /// Error message
    public let error: String

    public init(error: String) {
        self.error = error
    }

    private enum CodingKeys: String, CodingKey {
        case error
    }
}
