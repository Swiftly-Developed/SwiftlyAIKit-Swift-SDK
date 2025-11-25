import Foundation

// MARK: - Request Models

/// Grok chat completion request (OpenAI-compatible)
public struct GrokRequest: Codable, Sendable {
    /// Model to use for completion
    public let model: String

    /// Array of messages in the conversation
    public let messages: [GrokMessage]

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
    public let stream_options: GrokStreamOptions?

    /// Tools/functions available for calling
    public let tools: [GrokTool]?

    /// Control function calling behavior
    public let tool_choice: GrokToolChoice?

    /// Response format for structured output
    public let response_format: GrokResponseFormat?

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

    /// Search parameters for live web search
    public let search_parameters: GrokSearchParameters?

    /// Whether to run this as a deferred completion
    public let deferred: Bool?

    public init(
        model: String,
        messages: [GrokMessage],
        temperature: Double? = nil,
        top_p: Double? = nil,
        max_tokens: Int? = nil,
        frequency_penalty: Double? = nil,
        presence_penalty: Double? = nil,
        stream: Bool? = nil,
        stream_options: GrokStreamOptions? = nil,
        tools: [GrokTool]? = nil,
        tool_choice: GrokToolChoice? = nil,
        response_format: GrokResponseFormat? = nil,
        stop: [String]? = nil,
        n: Int? = nil,
        user: String? = nil,
        seed: Int? = nil,
        logprobs: Bool? = nil,
        top_logprobs: Int? = nil,
        search_parameters: GrokSearchParameters? = nil,
        deferred: Bool? = nil
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
        self.search_parameters = search_parameters
        self.deferred = deferred
    }
}

/// Stream options for Grok
public struct GrokStreamOptions: Codable, Sendable {
    /// Include usage statistics in stream
    public let include_usage: Bool?

    public init(include_usage: Bool? = nil) {
        self.include_usage = include_usage
    }
}

/// Search parameters for Grok live search
public struct GrokSearchParameters: Codable, Sendable {
    /// Mode for search (auto, on, off)
    public let mode: String?

    /// Maximum number of search results to use
    public let max_search_results: Int?

    /// Whether to include sources in response
    public let return_citations: Bool?

    /// Domains to include in search
    public let from_date: String?

    /// End date for search results
    public let to_date: String?

    public init(
        mode: String? = nil,
        max_search_results: Int? = nil,
        return_citations: Bool? = nil,
        from_date: String? = nil,
        to_date: String? = nil
    ) {
        self.mode = mode
        self.max_search_results = max_search_results
        self.return_citations = return_citations
        self.from_date = from_date
        self.to_date = to_date
    }
}

/// Grok message in conversation
public struct GrokMessage: Codable, Sendable {
    /// Role of the message sender
    public let role: String

    /// Content of the message (text, array for multimodal, or null for tool calls)
    public let content: GrokMessageContent?

    /// Tool calls made by the assistant
    public let tool_calls: [GrokToolCall]?

    /// Tool call ID (for tool role)
    public let tool_call_id: String?

    /// Name (for function role, legacy)
    public let name: String?

    public init(
        role: String,
        content: GrokMessageContent? = nil,
        tool_calls: [GrokToolCall]? = nil,
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

/// Grok message content (text or multimodal array)
public enum GrokMessageContent: Codable, Sendable {
    case text(String)
    case multimodal([GrokContentPart])

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
        } else if let parts = try? container.decode([GrokContentPart].self) {
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

/// Grok content part for multimodal messages
public enum GrokContentPart: Codable, Sendable {
    case text(String)
    case imageUrl(GrokImageUrl)

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
            let imageUrl = try container.decode(GrokImageUrl.self, forKey: .image_url)
            self = .imageUrl(imageUrl)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }
}

/// Grok image URL for vision
public struct GrokImageUrl: Codable, Sendable {
    /// URL of the image (can be URL or base64 data URL)
    public let url: String

    /// Detail level (auto, low, high)
    public let detail: String?

    public init(url: String, detail: String? = nil) {
        self.url = url
        self.detail = detail
    }
}

/// Grok tool definition
public struct GrokTool: Codable, Sendable {
    /// Type of tool (always "function")
    public let type: String

    /// Function definition
    public let function: GrokFunction

    public init(type: String = "function", function: GrokFunction) {
        self.type = type
        self.function = function
    }
}

/// Grok function definition
public struct GrokFunction: Codable, Sendable {
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
public enum GrokToolChoice: Codable, Sendable {
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
public struct GrokResponseFormat: Codable, Sendable {
    /// Type of response format ("text" or "json_object" or "json_schema")
    public let type: String

    /// JSON Schema for validation (optional, for json_schema type)
    public let json_schema: GrokJsonSchema?

    public init(type: String, json_schema: GrokJsonSchema? = nil) {
        self.type = type
        self.json_schema = json_schema
    }

    /// Create a text response format
    public static var text: GrokResponseFormat {
        GrokResponseFormat(type: "text")
    }

    /// Create a JSON object response format
    public static var jsonObject: GrokResponseFormat {
        GrokResponseFormat(type: "json_object")
    }

    /// Create a JSON schema response format
    public static func jsonSchema(_ schema: GrokJsonSchema) -> GrokResponseFormat {
        GrokResponseFormat(type: "json_schema", json_schema: schema)
    }
}

/// JSON Schema definition for structured outputs
public struct GrokJsonSchema: Codable, Sendable {
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

/// Grok chat completion response
public struct GrokResponse: Codable, Sendable {
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
    public let choices: [GrokChoice]

    /// Token usage information
    public let usage: GrokUsage?

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        system_fingerprint: String? = nil,
        choices: [GrokChoice],
        usage: GrokUsage? = nil
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

/// Grok completion choice
public struct GrokChoice: Codable, Sendable {
    /// Index of this choice
    public let index: Int

    /// Generated message
    public let message: GrokResponseMessage

    /// Reason for completion finish
    public let finish_reason: String?

    /// Log probabilities (if requested)
    public let logprobs: GrokLogprobs?

    public init(index: Int, message: GrokResponseMessage, finish_reason: String? = nil, logprobs: GrokLogprobs? = nil) {
        self.index = index
        self.message = message
        self.finish_reason = finish_reason
        self.logprobs = logprobs
    }
}

/// Grok log probabilities
public struct GrokLogprobs: Codable, Sendable {
    /// Array of log probability content
    public let content: [GrokLogprobContent]?

    public init(content: [GrokLogprobContent]? = nil) {
        self.content = content
    }
}

/// Grok log probability content
public struct GrokLogprobContent: Codable, Sendable {
    /// The token
    public let token: String

    /// Log probability of this token
    public let logprob: Double

    /// UTF-8 byte representation
    public let bytes: [Int]?

    /// Top log probabilities
    public let top_logprobs: [GrokTopLogprob]?

    public init(token: String, logprob: Double, bytes: [Int]? = nil, top_logprobs: [GrokTopLogprob]? = nil) {
        self.token = token
        self.logprob = logprob
        self.bytes = bytes
        self.top_logprobs = top_logprobs
    }
}

/// Grok top log probability entry
public struct GrokTopLogprob: Codable, Sendable {
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

/// Grok response message
public struct GrokResponseMessage: Codable, Sendable {
    /// Role of the message sender
    public let role: String

    /// Content of the message
    public let content: String?

    /// Tool calls made by the assistant
    public let tool_calls: [GrokToolCall]?

    /// Refusal message (if content was refused)
    public let refusal: String?

    public init(
        role: String,
        content: String? = nil,
        tool_calls: [GrokToolCall]? = nil,
        refusal: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.refusal = refusal
    }
}

/// Grok tool call
public struct GrokToolCall: Codable, Sendable {
    /// Tool call ID
    public let id: String

    /// Type of tool (always "function")
    public let type: String

    /// Function call details
    public let function: GrokFunctionCall

    public init(id: String, type: String = "function", function: GrokFunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Grok function call
public struct GrokFunctionCall: Codable, Sendable {
    /// Function name
    public let name: String

    /// Function arguments (JSON string)
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// Grok token usage information
public struct GrokUsage: Codable, Sendable {
    /// Number of tokens in the prompt
    public let prompt_tokens: Int

    /// Number of tokens in the completion
    public let completion_tokens: Int

    /// Total tokens used
    public let total_tokens: Int

    /// Detailed prompt token information
    public let prompt_tokens_details: GrokPromptTokensDetails?

    /// Detailed completion token information
    public let completion_tokens_details: GrokCompletionTokensDetails?

    public init(
        prompt_tokens: Int,
        completion_tokens: Int,
        total_tokens: Int,
        prompt_tokens_details: GrokPromptTokensDetails? = nil,
        completion_tokens_details: GrokCompletionTokensDetails? = nil
    ) {
        self.prompt_tokens = prompt_tokens
        self.completion_tokens = completion_tokens
        self.total_tokens = total_tokens
        self.prompt_tokens_details = prompt_tokens_details
        self.completion_tokens_details = completion_tokens_details
    }
}

/// Grok prompt tokens details
public struct GrokPromptTokensDetails: Codable, Sendable {
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

/// Grok completion tokens details
public struct GrokCompletionTokensDetails: Codable, Sendable {
    /// Reasoning tokens used (for models with reasoning like Grok 4)
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

/// Grok streaming chunk
public struct GrokStreamChunk: Codable, Sendable {
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
    public let choices: [GrokDeltaChoice]

    /// Token usage (only when stream_options.include_usage is true)
    public let usage: GrokUsage?

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        system_fingerprint: String? = nil,
        choices: [GrokDeltaChoice],
        usage: GrokUsage? = nil
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

/// Grok delta choice for streaming
public struct GrokDeltaChoice: Codable, Sendable {
    /// Index of this choice
    public let index: Int

    /// Incremental message delta
    public let delta: GrokDelta

    /// Reason for completion finish (only in final chunk)
    public let finish_reason: String?

    /// Log probabilities (if requested)
    public let logprobs: GrokLogprobs?

    public init(index: Int, delta: GrokDelta, finish_reason: String? = nil, logprobs: GrokLogprobs? = nil) {
        self.index = index
        self.delta = delta
        self.finish_reason = finish_reason
        self.logprobs = logprobs
    }
}

/// Grok incremental message delta
public struct GrokDelta: Codable, Sendable {
    /// Role of the message sender (only in first chunk)
    public let role: String?

    /// Incremental content
    public let content: String?

    /// Tool calls (incremental)
    public let tool_calls: [GrokDeltaToolCall]?

    /// Refusal message delta
    public let refusal: String?

    public init(
        role: String? = nil,
        content: String? = nil,
        tool_calls: [GrokDeltaToolCall]? = nil,
        refusal: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.refusal = refusal
    }
}

/// Grok delta tool call for streaming
public struct GrokDeltaToolCall: Codable, Sendable {
    /// Index of the tool call
    public let index: Int

    /// Tool call ID (only in first chunk for this tool call)
    public let id: String?

    /// Type of tool (only in first chunk)
    public let type: String?

    /// Function call delta
    public let function: GrokDeltaFunctionCall?

    public init(index: Int, id: String? = nil, type: String? = nil, function: GrokDeltaFunctionCall? = nil) {
        self.index = index
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Grok delta function call for streaming
public struct GrokDeltaFunctionCall: Codable, Sendable {
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

/// Grok error response
public struct GrokError: Codable, Sendable, Error {
    /// Error details
    public let error: GrokErrorDetail

    public init(error: GrokErrorDetail) {
        self.error = error
    }
}

/// Grok error detail
public struct GrokErrorDetail: Codable, Sendable {
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

// MARK: - Tokenization Models (Grok-specific)

/// Grok tokenize text request
public struct GrokTokenizeRequest: Codable, Sendable {
    /// Model to use for tokenization
    public let model: String

    /// Text to tokenize
    public let text: String

    public init(model: String, text: String) {
        self.model = model
        self.text = text
    }
}

/// Grok tokenize text response
public struct GrokTokenizeResponse: Codable, Sendable {
    /// Array of token information
    public let tokens: [GrokTokenInfo]

    public init(tokens: [GrokTokenInfo]) {
        self.tokens = tokens
    }
}

/// Grok token information
public struct GrokTokenInfo: Codable, Sendable {
    /// Token ID
    public let token_id: Int

    /// String representation of the token
    public let string_token: String

    public init(token_id: Int, string_token: String) {
        self.token_id = token_id
        self.string_token = string_token
    }
}

// MARK: - Deferred Completion Models (Grok-specific)

/// Grok deferred completion response (initial)
public struct GrokDeferredResponse: Codable, Sendable {
    /// Request ID to poll for results
    public let request_id: String

    public init(request_id: String) {
        self.request_id = request_id
    }
}

/// Grok deferred completion status
public struct GrokDeferredStatus: Codable, Sendable {
    /// Status of the deferred completion
    public let status: String

    /// The completion response (when complete)
    public let result: GrokResponse?

    /// Error information (if failed)
    public let error: GrokErrorDetail?

    public init(status: String, result: GrokResponse? = nil, error: GrokErrorDetail? = nil) {
        self.status = status
        self.result = result
        self.error = error
    }
}

// MARK: - Image Generation Models (Grok-specific)

/// Grok image generation request
public struct GrokImageRequest: Codable, Sendable {
    /// The prompt describing the image to generate
    public let prompt: String

    /// Model to use (grok-2-image)
    public let model: String

    /// Number of images to generate (1-10)
    public let n: Int?

    /// Response format (url or b64_json)
    public let response_format: GrokImageResponseFormat?

    /// User identifier for tracking
    public let user: String?

    public init(
        prompt: String,
        model: String = "grok-2-image",
        n: Int? = nil,
        response_format: GrokImageResponseFormat? = nil,
        user: String? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.n = n
        self.response_format = response_format
        self.user = user
    }
}

/// Grok image response format
public enum GrokImageResponseFormat: String, Codable, Sendable {
    case url
    case b64_json
}

/// Grok image generation response
public struct GrokImageResponse: Codable, Sendable {
    /// Unix timestamp of creation
    public let created: Int

    /// Array of generated images
    public let data: [GrokGeneratedImage]

    public init(created: Int, data: [GrokGeneratedImage]) {
        self.created = created
        self.data = data
    }
}

/// Grok generated image
public struct GrokGeneratedImage: Codable, Sendable {
    /// URL of the generated image (if response_format is url)
    public let url: String?

    /// Base64-encoded image data (if response_format is b64_json)
    public let b64_json: String?

    /// The revised prompt used for generation
    public let revised_prompt: String?

    public init(url: String? = nil, b64_json: String? = nil, revised_prompt: String? = nil) {
        self.url = url
        self.b64_json = b64_json
        self.revised_prompt = revised_prompt
    }
}

// MARK: - Models List Response

/// Grok models list response
public struct GrokModelsResponse: Codable, Sendable {
    /// Object type
    public let object: String

    /// Array of available models
    public let data: [GrokModelInfo]

    public init(object: String, data: [GrokModelInfo]) {
        self.object = object
        self.data = data
    }
}

/// Grok model information
public struct GrokModelInfo: Codable, Sendable {
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
