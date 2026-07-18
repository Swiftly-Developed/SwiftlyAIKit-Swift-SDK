import Foundation

/// Cohere API Models
///
/// Provider-specific types for Cohere's Chat API v2 with RAG support.
///
/// ## See Also
/// - ``CohereProvider``
/// - <doc:CohereGuide>

// MARK: - Content Blocks

/// Content block for Cohere messages supporting text and images
public enum CohereContentBlock: Codable, Sendable, Equatable {
    case text(String)
    case image(url: String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let url = try container.decode(String.self, forKey: .url)
            self = .image(url: url)
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
        case .image(let url):
            try container.encode("image", forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
}

// MARK: - Message Structure

/// Message in a Cohere conversation
public struct CohereMessage: Codable, Sendable, Equatable {
    public let role: Role
    public let content: MessageContent?
    public let toolCalls: [CohereToolCall]?
    public let toolCallId: String?

    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public enum MessageContent: Codable, Sendable, Equatable {
        case text(String)
        case contentArray([CohereContentBlock])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let array = try? container.decode([CohereContentBlock].self) {
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
            case .contentArray(let array):
                try container.encode(array)
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    public init(role: Role, content: MessageContent?, toolCalls: [CohereToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

// MARK: - Tool Definitions

/// Tool definition for function calling
public struct CohereTool: Codable, Sendable, Equatable {
    public let type: String
    public let function: ToolFunction

    public struct ToolFunction: Codable, Sendable, Equatable {
        public let name: String
        public let description: String
        public let parameters: [String: AnyCodable]

        public init(name: String, description: String, parameters: [String: AnyCodable]) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }

    public init(type: String = "function", function: ToolFunction) {
        self.type = type
        self.function = function
    }
}

/// Tool call made by the model
public struct CohereToolCall: Codable, Sendable, Equatable {
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

// MARK: - Document Structure for RAG

/// Document for Retrieval Augmented Generation
public struct CohereDocument: Codable, Sendable, Equatable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

/// Citation from document
public struct CohereCitation: Codable, Sendable, Equatable {
    public let start: Int
    public let end: Int
    public let text: String
    public let documentIds: [String]

    enum CodingKeys: String, CodingKey {
        case start
        case end
        case text
        case documentIds = "document_ids"
    }

    public init(start: Int, end: Int, text: String, documentIds: [String]) {
        self.start = start
        self.end = end
        self.text = text
        self.documentIds = documentIds
    }
}

// MARK: - Response Format

/// Response format configuration
public struct CohereResponseFormat: Codable, Sendable, Equatable {
    public let type: FormatType
    public let schema: [String: AnyCodable]?

    public enum FormatType: String, Codable, Sendable {
        case text
        case jsonObject = "json_object"
    }

    public init(type: FormatType, schema: [String: AnyCodable]? = nil) {
        self.type = type
        self.schema = schema
    }
}

// MARK: - Request

/// Chat request to Cohere API
public struct CohereRequest: Codable, Sendable {
    public let model: String
    public let messages: [CohereMessage]
    public let stream: Bool?
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let frequencyPenalty: Double?
    public let presencePenalty: Double?
    public let stopSequences: [String]?
    public let documents: [CohereDocument]?
    public let tools: [CohereTool]?
    public let responseFormat: CohereResponseFormat?
    public let safetyMode: SafetyMode?

    public enum SafetyMode: String, Codable, Sendable {
        case none = "NONE"
        case contextual = "CONTEXTUAL"
        case strict = "STRICT"
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case stopSequences = "stop_sequences"
        case documents
        case tools
        case responseFormat = "response_format"
        case safetyMode = "safety_mode"
    }

    public init(
        model: String,
        messages: [CohereMessage],
        stream: Bool? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stopSequences: [String]? = nil,
        documents: [CohereDocument]? = nil,
        tools: [CohereTool]? = nil,
        responseFormat: CohereResponseFormat? = nil,
        safetyMode: SafetyMode? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
        self.documents = documents
        self.tools = tools
        self.responseFormat = responseFormat
        self.safetyMode = safetyMode
    }
}

// MARK: - Response

/// Chat response from Cohere API
public struct CohereResponse: Codable, Sendable {
    public let id: String?
    public let finishReason: String?
    public let message: ResponseMessage
    public let usage: Usage?
    public let citations: [CohereCitation]?

    public struct ResponseMessage: Codable, Sendable {
        public let role: String
        public let content: [CohereContentBlock]?
        public let toolCalls: [CohereToolCall]?

        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }

    public struct Usage: Codable, Sendable {
        public let billedUnits: BilledUnits?
        public let tokens: Tokens?

        public struct BilledUnits: Codable, Sendable {
            public let inputTokens: Int?
            public let outputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }

        public struct Tokens: Codable, Sendable {
            public let inputTokens: Int?
            public let outputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }

        enum CodingKeys: String, CodingKey {
            case billedUnits = "billed_units"
            case tokens
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case finishReason = "finish_reason"
        case message
        case usage
        case citations
    }
}

// MARK: - Stream Events

/// Base streaming event
public struct CohereStreamEvent: Codable, Sendable {
    public let type: String
    public let index: Int?
    public let id: String?
    public let contentBlock: ContentBlock?
    public let delta: Delta?
    public let citation: CohereCitation?
    public let toolCall: CohereToolCall?

    public struct ContentBlock: Codable, Sendable {
        public let type: String
        public let text: String?
    }

    public struct Delta: Codable, Sendable {
        public let message: DeltaMessage?
        public let finishReason: String?
        public let usage: CohereResponse.Usage?
        public let toolCall: ToolCallDelta?

        public struct DeltaMessage: Codable, Sendable {
            public let content: ContentDelta?
            public let toolPlan: String?

            public struct ContentDelta: Codable, Sendable {
                public let text: String?
            }

            enum CodingKeys: String, CodingKey {
                case content
                case toolPlan = "tool_plan"
            }
        }

        public struct ToolCallDelta: Codable, Sendable {
            public let function: FunctionDelta?

            public struct FunctionDelta: Codable, Sendable {
                public let arguments: String?
            }
        }

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
            case usage
            case toolCall = "tool_call"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case index
        case id
        case contentBlock = "content_block"
        case delta
        case citation
        case toolCall = "tool_call"
    }
}

// MARK: - Tokenize Request/Response

/// Tokenize request
public struct CohereTokenizeRequest: Codable, Sendable {
    public let text: String
    public let model: String

    public init(text: String, model: String) {
        self.text = text
        self.model = model
    }
}

/// Tokenize response
public struct CohereTokenizeResponse: Codable, Sendable {
    public let tokens: [Int]
    public let tokenStrings: [String]

    enum CodingKeys: String, CodingKey {
        case tokens
        case tokenStrings = "token_strings"
    }
}

// MARK: - Models List Response

/// Response from Cohere's GET /models endpoint
///
/// The endpoint is paginated; `nextPageToken` carries the cursor for the next page
/// (nil / absent on the final page).
public struct CohereModelsResponse: Codable, Sendable {
    /// Array of available models
    public let models: [CohereModelInfo]
    /// Cursor for the next page of results (nil on the final page)
    public let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case models
        case nextPageToken = "next_page_token"
    }

    public init(models: [CohereModelInfo], nextPageToken: String? = nil) {
        self.models = models
        self.nextPageToken = nextPageToken
    }
}

/// Cohere model information (one entry from GET /models)
public struct CohereModelInfo: Codable, Sendable {
    /// Model name / identifier used in API requests, e.g. "command-a-03-2025"
    public let name: String
    /// API endpoints this model is compatible with, e.g. ["chat", "embed"]
    public let endpoints: [String]?
    /// Maximum number of tokens the model can process
    public let contextLength: Int?
    /// Whether the model is deprecated
    public let isDeprecated: Bool?
    /// Whether the model is a fine-tuned model
    public let finetuned: Bool?
    /// Public URL to the model's tokenizer configuration
    public let tokenizerURL: String?
    /// Default API endpoints for this model
    public let defaultEndpoints: [String]?
    /// Supported features, e.g. ["json_mode", "tools"]
    public let features: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case endpoints
        case contextLength = "context_length"
        case isDeprecated = "is_deprecated"
        case finetuned
        case tokenizerURL = "tokenizer_url"
        case defaultEndpoints = "default_endpoints"
        case features
    }

    public init(
        name: String,
        endpoints: [String]? = nil,
        contextLength: Int? = nil,
        isDeprecated: Bool? = nil,
        finetuned: Bool? = nil,
        tokenizerURL: String? = nil,
        defaultEndpoints: [String]? = nil,
        features: [String]? = nil
    ) {
        self.name = name
        self.endpoints = endpoints
        self.contextLength = contextLength
        self.isDeprecated = isDeprecated
        self.finetuned = finetuned
        self.tokenizerURL = tokenizerURL
        self.defaultEndpoints = defaultEndpoints
        self.features = features
    }
}

// MARK: - Error Response

/// Error response from Cohere API
public struct CohereErrorResponse: Codable, Sendable {
    public let message: String
    public let statusCode: Int?

    enum CodingKeys: String, CodingKey {
        case message
        case statusCode = "status_code"
    }
}
