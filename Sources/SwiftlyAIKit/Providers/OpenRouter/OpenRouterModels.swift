import Foundation

/// OpenRouter API Models
///
/// Provider-specific request and response types for OpenRouter's OpenAI-compatible
/// Chat Completions API and its dynamic `GET /models` catalog.
///
/// OpenRouter is an OpenAI-compatible aggregator: the request/response/streaming/tool
/// shapes mirror ``OpenAIProvider``'s Codables exactly (explicit snake_case `CodingKeys`,
/// no `.convertFromSnakeCase`). Model ids are namespaced `"vendor/model"` (e.g.
/// `"anthropic/claude-3.5-sonnet"`) and are passed through verbatim.
///
/// ## See Also
/// - ``OpenRouterProvider``

// MARK: - Content Blocks

/// Represents different types of content that can be sent in OpenRouter messages
public enum OpenRouterContentBlock: Codable, Sendable, Equatable {
    case text(String)
    case imageUrl(url: String, detail: ImageDetail?)

    public enum ImageDetail: String, Codable, Sendable {
        case low
        case high
        case auto
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }

    private enum ContentType: String, Codable {
        case text
        case imageUrl = "image_url"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let content):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(content, forKey: .text)

        case .imageUrl(let url, let detail):
            try container.encode(ContentType.imageUrl, forKey: .type)
            var imageUrlContainer = container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            try imageUrlContainer.encode(url, forKey: .url)
            if let detail = detail {
                try imageUrlContainer.encode(detail, forKey: .detail)
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)

        switch type {
        case .text:
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)

        case .imageUrl:
            let imageUrlContainer = try container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            let url = try imageUrlContainer.decode(String.self, forKey: .url)
            let detail = try? imageUrlContainer.decode(ImageDetail.self, forKey: .detail)
            self = .imageUrl(url: url, detail: detail)
        }
    }

    private enum ImageUrlKeys: String, CodingKey {
        case url
        case detail
    }
}

// MARK: - Message Structure

/// OpenRouter message structure for chat completions
public struct OpenRouterMessage: Codable, Sendable, Equatable {
    public let role: Role
    public let content: MessageContent?
    public let name: String?
    public let toolCalls: [OpenRouterToolCall]?
    public let toolCallId: String?

    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public enum MessageContent: Codable, Sendable, Equatable {
        case text(String)
        case contentArray([OpenRouterContentBlock])

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .contentArray(let blocks):
                try container.encode(blocks)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let blocks = try? container.decode([OpenRouterContentBlock].self) {
                self = .contentArray(blocks)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Content must be either a string or an array of content blocks"
                )
            }
        }
    }

    public init(
        role: Role,
        content: MessageContent? = nil,
        name: String? = nil,
        toolCalls: [OpenRouterToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

// MARK: - Tool/Function Calling

/// Tool definition for function calling
public struct OpenRouterToolDefinition: Codable, Sendable, Equatable {
    public let type: String
    public let function: FunctionDefinition

    public struct FunctionDefinition: Codable, Sendable, Equatable {
        public let name: String
        public let description: String?
        public let parameters: [String: AnyCodable]

        public init(name: String, description: String? = nil, parameters: [String: AnyCodable]) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }

    public init(function: FunctionDefinition) {
        self.type = "function"
        self.function = function
    }
}

/// Tool choice parameter
public enum OpenRouterToolChoice: Codable, Sendable, Equatable {
    case none
    case auto
    case required
    case function(String)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .none, .auto, .required:
            var container = encoder.singleValueContainer()
            switch self {
            case .none:
                try container.encode("none")
            case .auto:
                try container.encode("auto")
            case .required:
                try container.encode("required")
            default:
                break
            }
        case .function(let name):
            // Encode as structured object
            var container = encoder.container(keyedBy: FunctionChoiceKeys.self)
            try container.encode("function", forKey: .type)
            var funcContainer = container.nestedContainer(keyedBy: FunctionKeys.self, forKey: .function)
            try funcContainer.encode(name, forKey: .name)
        }
    }

    private enum FunctionChoiceKeys: String, CodingKey {
        case type
        case function
    }

    private enum FunctionKeys: String, CodingKey {
        case name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            switch string {
            case "none":
                self = .none
            case "auto":
                self = .auto
            case "required":
                self = .required
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid tool_choice string value"
                )
            }
        } else if let dict = try? container.decode([String: [String: String]].self),
                  let functionName = dict["function"]?["name"] {
            self = .function(functionName)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid tool_choice format"
            )
        }
    }
}

/// Tool call made by the assistant
public struct OpenRouterToolCall: Codable, Sendable, Equatable {
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

// MARK: - Request Structure

/// OpenRouter chat completion request (OpenAI-compatible)
public struct OpenRouterRequest: Codable, Sendable {
    public let model: String
    public let messages: [OpenRouterMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public var stream: Bool?
    public let stop: [String]?
    public let user: String?
    public let seed: Int?
    public let tools: [OpenRouterToolDefinition]?
    public let toolChoice: OpenRouterToolChoice?

    public init(
        model: String,
        messages: [OpenRouterMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil,
        user: String? = nil,
        seed: Int? = nil,
        tools: [OpenRouterToolDefinition]? = nil,
        toolChoice: OpenRouterToolChoice? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stream = stream
        self.stop = stop
        self.user = user
        self.seed = seed
        self.tools = tools
        self.toolChoice = toolChoice
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case stream
        case stop
        case user
        case seed
        case tools
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case toolChoice = "tool_choice"
    }
}

// MARK: - Response Structure

/// OpenRouter chat completion response
public struct OpenRouterResponse: Codable, Sendable {
    public let id: String
    public let object: String?
    public let created: Int?
    public let model: String
    public let choices: [Choice]
    public let usage: Usage?

    public struct Choice: Codable, Sendable {
        public let index: Int
        public let message: OpenRouterMessage
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
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
    }
}

// MARK: - Streaming Response

/// OpenRouter streaming chunk
public struct OpenRouterStreamChunk: Codable, Sendable {
    public let id: String
    public let object: String?
    public let created: Int?
    public let model: String
    public let choices: [StreamChoice]

    public struct StreamChoice: Codable, Sendable {
        public let index: Int
        public let delta: Delta
        public let finishReason: String?

        public struct Delta: Codable, Sendable {
            public let role: String?
            public let content: String?
            public let toolCalls: [DeltaToolCall]?

            public struct DeltaToolCall: Codable, Sendable {
                public let index: Int
                public let id: String?
                public let type: String?
                public let function: DeltaFunction?

                // swiftlint:disable:next nesting
                public struct DeltaFunction: Codable, Sendable {
                    public let name: String?
                    public let arguments: String?

                    public init(name: String? = nil, arguments: String? = nil) {
                        self.name = name
                        self.arguments = arguments
                    }
                }

                public init(index: Int, id: String? = nil, type: String? = nil, function: DeltaFunction? = nil) {
                    self.index = index
                    self.id = id
                    self.type = type
                    self.function = function
                }
            }

            enum CodingKeys: String, CodingKey {
                case role
                case content
                case toolCalls = "tool_calls"
            }
        }

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }
}

// MARK: - Error Response

/// OpenRouter error response
public struct OpenRouterErrorResponse: Codable, Sendable {
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let code: Int?
    }
}

// MARK: - Models List Response

/// Response from OpenRouter's `GET /api/v1/models` endpoint.
///
/// The catalog is large and dynamic (hundreds of models across many vendors); it is the
/// authoritative source of available models. Ids are namespaced `"vendor/model"` and are
/// returned verbatim.
public struct OpenRouterModelsResponse: Codable, Sendable {
    /// Array of available models
    public let data: [OpenRouterModelInfo]

    public init(data: [OpenRouterModelInfo]) {
        self.data = data
    }
}

/// OpenRouter model information (one entry from `GET /api/v1/models`).
///
/// Only ``id`` is guaranteed; the remaining fields are optional because OpenRouter's
/// schema varies across models.
public struct OpenRouterModelInfo: Codable, Sendable {
    /// Namespaced model id, e.g. `"anthropic/claude-3.5-sonnet"`
    public let id: String
    /// Human-readable model name, e.g. `"Anthropic: Claude 3.5 Sonnet"`
    public let name: String?
    /// Maximum context length in tokens
    public let contextLength: Int?
    /// Per-token / per-request pricing (values are decimal strings)
    public let pricing: Pricing?

    /// OpenRouter pricing block — all values are decimal strings (USD).
    public struct Pricing: Codable, Sendable {
        public let prompt: String?
        public let completion: String?
        public let request: String?
        public let image: String?

        public init(prompt: String? = nil, completion: String? = nil, request: String? = nil, image: String? = nil) {
            self.prompt = prompt
            self.completion = completion
            self.request = request
            self.image = image
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pricing
        case contextLength = "context_length"
    }

    public init(id: String, name: String? = nil, contextLength: Int? = nil, pricing: Pricing? = nil) {
        self.id = id
        self.name = name
        self.contextLength = contextLength
        self.pricing = pricing
    }
}
