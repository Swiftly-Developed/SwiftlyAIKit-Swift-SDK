import Foundation

/// Mistral AI API Models
///
/// Provider-specific types for Mistral's Chat Completions API.
///
/// ## See Also
/// - ``MistralProvider``
/// - <doc:MistralGuide>

// MARK: - Content Blocks

/// Content block for Mistral messages supporting text and images
public enum MistralContentBlock: Codable, Sendable, Equatable {
    case text(String)
    case imageUrl(url: String, detail: String?)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }

    enum ImageUrlKeys: String, CodingKey {
        case url
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageContainer = try container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            let url = try imageContainer.decode(String.self, forKey: .url)
            let detail = try imageContainer.decodeIfPresent(String.self, forKey: .detail)
            self = .imageUrl(url: url, detail: detail)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageUrl(let url, let detail):
            try container.encode("image_url", forKey: .type)
            var imageContainer = container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            try imageContainer.encode(url, forKey: .url)
            if let detail = detail {
                try imageContainer.encode(detail, forKey: .detail)
            }
        }
    }
}

// MARK: - Message Structure

/// Message in a Mistral conversation
public struct MistralMessage: Codable, Sendable, Equatable {
    public let role: Role
    public let content: MessageContent?
    public let toolCalls: [MistralToolCall]?
    public let toolCallId: String?
    public let name: String?

    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public enum MessageContent: Codable, Sendable, Equatable {
        case text(String)
        case contentArray([MistralContentBlock])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let array = try? container.decode([MistralContentBlock].self) {
                self = .contentArray(array)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Content must be either a string or an array of content blocks"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .contentArray(let blocks):
                try container.encode(blocks)
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
        case name
    }

    public init(
        role: Role,
        content: MessageContent? = nil,
        toolCalls: [MistralToolCall]? = nil,
        toolCallId: String? = nil,
        name: String? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.name = name
    }
}

// MARK: - Tool/Function Calling

/// Definition of a tool/function that the model can call
public struct MistralToolDefinition: Codable, Sendable, Equatable {
    public let type: String
    public let function: FunctionDefinition

    public struct FunctionDefinition: Codable, Sendable, Equatable {
        public let name: String
        public let description: String?
        public let parameters: [String: AnyCodable]?

        public init(name: String, description: String? = nil, parameters: [String: AnyCodable]? = nil) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }

    public init(type: String = "function", function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// A tool call made by the model
public struct MistralToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let function: FunctionCall

    public struct FunctionCall: Codable, Sendable, Equatable {
        public let name: String
        public let arguments: String

        public init(name: String, arguments: String) {
            self.name = name
            self.arguments = arguments
        }
    }

    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Tool choice strategy for function calling
public enum MistralToolChoice: Codable, Sendable, Equatable {
    case auto
    case none
    case any
    case required
    case specific(name: String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            switch string {
            case "auto":
                self = .auto
            case "none":
                self = .none
            case "any":
                self = .any
            case "required":
                self = .required
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown tool choice: \(string)"
                )
            }
        } else if let dict = try? container.decode([String: String].self),
                  let name = dict["function"] {
            self = .specific(name: name)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid tool choice format"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode("auto")
        case .none:
            try container.encode("none")
        case .any:
            try container.encode("any")
        case .required:
            try container.encode("required")
        case .specific(let name):
            try container.encode(["function": name])
        }
    }
}

// MARK: - Request

/// Request to Mistral chat completions API
public struct MistralRequest: Codable, Sendable {
    public let model: String
    public let messages: [MistralMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let stream: Bool?
    public let safePrompt: Bool?
    public let randomSeed: Int?
    public let stop: [String]?
    public let responseFormat: ResponseFormat?
    public let tools: [MistralToolDefinition]?
    public let toolChoice: MistralToolChoice?
    public let frequencyPenalty: Double?
    public let presencePenalty: Double?

    public struct ResponseFormat: Codable, Sendable {
        public let type: String

        public init(type: String) {
            self.type = type
        }
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case stream
        case safePrompt = "safe_prompt"
        case randomSeed = "random_seed"
        case stop
        case responseFormat = "response_format"
        case tools
        case toolChoice = "tool_choice"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
    }

    public init(
        model: String,
        messages: [MistralMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        stream: Bool? = nil,
        safePrompt: Bool? = nil,
        randomSeed: Int? = nil,
        stop: [String]? = nil,
        responseFormat: ResponseFormat? = nil,
        tools: [MistralToolDefinition]? = nil,
        toolChoice: MistralToolChoice? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stream = stream
        self.safePrompt = safePrompt
        self.randomSeed = randomSeed
        self.stop = stop
        self.responseFormat = responseFormat
        self.tools = tools
        self.toolChoice = toolChoice
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
    }
}

// MARK: - Response

/// Response from Mistral chat completions API
public struct MistralResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage

    public struct Choice: Codable, Sendable {
        public let index: Int
        public let message: MistralMessage
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }

        public init(index: Int, message: MistralMessage, finishReason: String? = nil) {
            self.index = index
            self.message = message
            self.finishReason = finishReason
        }
    }

    public struct Usage: Codable, Sendable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }

        public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
        }
    }

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        choices: [Choice],
        usage: Usage
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
    }
}

// MARK: - Stream Chunk

/// Streaming chunk from Mistral chat completions API
public struct MistralStreamChunk: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [StreamChoice]
    public let usage: Usage?

    public struct StreamChoice: Codable, Sendable {
        public let index: Int
        public let delta: Delta
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }

        public init(index: Int, delta: Delta, finishReason: String? = nil) {
            self.index = index
            self.delta = delta
            self.finishReason = finishReason
        }
    }

    public struct Delta: Codable, Sendable {
        public let role: String?
        public let content: String?
        public let toolCalls: [MistralToolCall]?

        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }

        public init(role: String? = nil, content: String? = nil, toolCalls: [MistralToolCall]? = nil) {
            self.role = role
            self.content = content
            self.toolCalls = toolCalls
        }
    }

    public struct Usage: Codable, Sendable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }

        public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
        }
    }

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        choices: [StreamChoice],
        usage: Usage? = nil
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
    }
}

// MARK: - Error Response

/// Error response from Mistral API
public struct MistralErrorResponse: Codable, Sendable {
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let type: String
        public let code: String?

        public init(message: String, type: String, code: String? = nil) {
            self.message = message
            self.type = type
            self.code = code
        }
    }

    public init(error: ErrorDetail) {
        self.error = error
    }
}

// MARK: - Mistral-Specific Options

/// Options specific to Mistral AI models
public struct MistralOptions: Codable, Sendable {
    /// Enable safety prompt injection to prevent prompt attacks
    public let safePrompt: Bool?

    /// Random seed for deterministic sampling
    public let randomSeed: Int?

    /// Enable reasoning mode for chain-of-thought (Magistral models only)
    public let promptMode: String?

    enum CodingKeys: String, CodingKey {
        case safePrompt = "safe_prompt"
        case randomSeed = "random_seed"
        case promptMode = "prompt_mode"
    }

    public init(
        safePrompt: Bool? = nil,
        randomSeed: Int? = nil,
        promptMode: String? = nil
    ) {
        self.safePrompt = safePrompt
        self.randomSeed = randomSeed
        self.promptMode = promptMode
    }
}
