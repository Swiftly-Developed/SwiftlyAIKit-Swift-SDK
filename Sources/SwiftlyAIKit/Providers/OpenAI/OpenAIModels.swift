import Foundation

/// OpenAI API Models
///
/// Provider-specific request and response types for OpenAI's Chat Completions and Images API.
///
/// ## See Also
/// - ``OpenAIProvider``
/// - <doc:OpenAIGuide>

// MARK: - Content Blocks

/// Represents different types of content that can be sent in OpenAI messages
public enum OpenAIContentBlock: Codable, Sendable, Equatable {
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

/// OpenAI message structure for chat completions
public struct OpenAIMessage: Codable, Sendable, Equatable {
    public let role: Role
    public let content: MessageContent?
    public let name: String?
    public let toolCalls: [OpenAIToolCall]?
    public let toolCallId: String?

    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public enum MessageContent: Codable, Sendable, Equatable {
        case text(String)
        case contentArray([OpenAIContentBlock])

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
            } else if let blocks = try? container.decode([OpenAIContentBlock].self) {
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
        toolCalls: [OpenAIToolCall]? = nil,
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
public struct OpenAIToolDefinition: Codable, Sendable, Equatable {
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
public enum OpenAIToolChoice: Codable, Sendable, Equatable {
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
public struct OpenAIToolCall: Codable, Sendable, Equatable {
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

/// OpenAI chat completion request
public struct OpenAIRequest: Codable, Sendable {
    public let model: String
    public let messages: [OpenAIMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let n: Int?
    public var stream: Bool?
    public let stop: [String]?
    public let presencePenalty: Double?
    public let frequencyPenalty: Double?
    public let logitBias: [String: Double]?
    public let user: String?
    public let responseFormat: ResponseFormat?
    public let seed: Int?
    public let tools: [OpenAIToolDefinition]?
    public let toolChoice: OpenAIToolChoice?

    public struct ResponseFormat: Codable, Sendable, Equatable {
        public let type: String

        public init(type: String) {
            self.type = type
        }

        public static let text = ResponseFormat(type: "text")
        public static let jsonObject = ResponseFormat(type: "json_object")
    }

    public init(
        model: String,
        messages: [OpenAIMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        logitBias: [String: Double]? = nil,
        user: String? = nil,
        responseFormat: ResponseFormat? = nil,
        seed: Int? = nil,
        tools: [OpenAIToolDefinition]? = nil,
        toolChoice: OpenAIToolChoice? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.n = n
        self.stream = stream
        self.stop = stop
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.logitBias = logitBias
        self.user = user
        self.responseFormat = responseFormat
        self.seed = seed
        self.tools = tools
        self.toolChoice = toolChoice
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case n
        case stream
        case stop
        case user
        case seed
        case tools
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
        case logitBias = "logit_bias"
        case responseFormat = "response_format"
        case toolChoice = "tool_choice"
    }
}

// MARK: - Response Structure

/// OpenAI chat completion response
public struct OpenAIResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage
    public let systemFingerprint: String?

    public struct Choice: Codable, Sendable {
        public let index: Int
        public let message: OpenAIMessage
        public let finishReason: String?
        public let logprobs: LogProbs?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case logprobs
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

    public struct LogProbs: Codable, Sendable {
        // Optional: Implementation for token probability information
        // Can be added in future if needed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case model
        case choices
        case usage
        case systemFingerprint = "system_fingerprint"
    }
}

// MARK: - Streaming Response

/// OpenAI streaming chunk
public struct OpenAIStreamChunk: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [StreamChoice]
    public let systemFingerprint: String?

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

                public struct DeltaFunction: Codable, Sendable {
                    public let name: String?
                    public let arguments: String?
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

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case model
        case choices
        case systemFingerprint = "system_fingerprint"
    }
}

// MARK: - Batch API Models

/// OpenAI batch status
public struct OpenAIBatch: Codable, Sendable {
    public let id: String
    public let object: String
    public let endpoint: String
    public let errors: BatchErrors?
    public let inputFileId: String
    public let completionWindow: String
    public let status: BatchStatus
    public let outputFileId: String?
    public let errorFileId: String?
    public let createdAt: Int
    public let inProgressAt: Int?
    public let expiresAt: Int?
    public let completedAt: Int?
    public let failedAt: Int?
    public let expiredAt: Int?
    public let cancellingAt: Int?
    public let cancelledAt: Int?
    public let requestCounts: RequestCounts?
    public let metadata: [String: String]?

    public enum BatchStatus: String, Codable, Sendable {
        case validating
        case failed
        case inProgress = "in_progress"
        case finalizing
        case completed
        case expired
        case cancelling
        case cancelled
    }

    public struct BatchErrors: Codable, Sendable {
        public let object: String
        public let data: [ErrorData]

        public struct ErrorData: Codable, Sendable {
            public let code: String
            public let message: String
            public let param: String?
            public let line: Int?
        }
    }

    public struct RequestCounts: Codable, Sendable {
        public let total: Int
        public let completed: Int
        public let failed: Int
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case endpoint
        case errors
        case status
        case metadata
        case inputFileId = "input_file_id"
        case completionWindow = "completion_window"
        case outputFileId = "output_file_id"
        case errorFileId = "error_file_id"
        case createdAt = "created_at"
        case inProgressAt = "in_progress_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case failedAt = "failed_at"
        case expiredAt = "expired_at"
        case cancellingAt = "cancelling_at"
        case cancelledAt = "cancelled_at"
        case requestCounts = "request_counts"
    }
}

/// Batch request item (for JSONL file)
public struct OpenAIBatchRequest: Codable, Sendable {
    public let customId: String
    public let method: String
    public let url: String
    public let body: OpenAIRequest

    public init(customId: String, method: String = "POST", url: String = "/v1/chat/completions", body: OpenAIRequest) {
        self.customId = customId
        self.method = method
        self.url = url
        self.body = body
    }

    enum CodingKeys: String, CodingKey {
        case method
        case url
        case body
        case customId = "custom_id"
    }
}

/// Batch result item
public struct OpenAIBatchResult: Codable, Sendable {
    public let id: String
    public let customId: String
    public let response: BatchResponse?
    public let error: BatchError?

    public struct BatchResponse: Codable, Sendable {
        public let statusCode: Int
        public let requestId: String?
        public let body: OpenAIResponse

        enum CodingKeys: String, CodingKey {
            case body
            case statusCode = "status_code"
            case requestId = "request_id"
        }
    }

    public struct BatchError: Codable, Sendable {
        public let code: String?
        public let message: String
    }

    enum CodingKeys: String, CodingKey {
        case id
        case error
        case response
        case customId = "custom_id"
    }
}

/// Batch creation request
public struct OpenAICreateBatchRequest: Codable, Sendable {
    public let inputFileId: String
    public let endpoint: String
    public let completionWindow: String
    public let metadata: [String: String]?

    public init(
        inputFileId: String,
        endpoint: String = "/v1/chat/completions",
        completionWindow: String = "24h",
        metadata: [String: String]? = nil
    ) {
        self.inputFileId = inputFileId
        self.endpoint = endpoint
        self.completionWindow = completionWindow
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case endpoint
        case metadata
        case inputFileId = "input_file_id"
        case completionWindow = "completion_window"
    }
}

/// List batches response
public struct OpenAIBatchList: Codable, Sendable {
    public let object: String
    public let data: [OpenAIBatch]
    public let firstId: String?
    public let lastId: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case object
        case data
        case firstId = "first_id"
        case lastId = "last_id"
        case hasMore = "has_more"
    }
}

// MARK: - Error Response

/// OpenAI error response
public struct OpenAIErrorResponse: Codable, Sendable {
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let type: String
        public let param: String?
        public let code: String?
    }
}

// MARK: - Image Generation Models

/// OpenAI image generation request for DALL-E
public struct OpenAIImageRequest: Codable, Sendable {
    /// The text prompt describing the desired image
    public let prompt: String

    /// The model to use (dall-e-3 or dall-e-2)
    public let model: String

    /// Number of images to generate (1-10 for DALL-E 2, always 1 for DALL-E 3)
    public let n: Int?

    /// Size of the generated image
    /// DALL-E 3: 1024x1024, 1792x1024, 1024x1792
    /// DALL-E 2: 256x256, 512x512, 1024x1024
    public let size: String?

    /// Quality of the image (standard or hd, DALL-E 3 only)
    public let quality: String?

    /// Style of the generated image (vivid or natural, DALL-E 3 only)
    public let style: String?

    /// Response format (url or b64_json)
    public let responseFormat: String?

    /// Optional user identifier for abuse detection
    public let user: String?

    public init(
        prompt: String,
        model: String = "dall-e-3",
        n: Int? = nil,
        size: String? = nil,
        quality: String? = nil,
        style: String? = nil,
        responseFormat: String? = nil,
        user: String? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.n = n
        self.size = size
        self.quality = quality
        self.style = style
        self.responseFormat = responseFormat
        self.user = user
    }

    enum CodingKeys: String, CodingKey {
        case prompt
        case model
        case n
        case size
        case quality
        case style
        case user
        case responseFormat = "response_format"
    }
}

/// OpenAI image generation response
public struct OpenAIImageResponse: Codable, Sendable {
    /// Unix timestamp of when the images were created
    public let created: Int

    /// Array of generated images
    public let data: [OpenAIGeneratedImage]
}

/// A single generated image from OpenAI
public struct OpenAIGeneratedImage: Codable, Sendable {
    /// URL to the generated image (when response_format is url)
    /// URLs expire after 1 hour
    public let url: String?

    /// Base64-encoded image data (when response_format is b64_json)
    public let b64Json: String?

    /// The prompt as revised by DALL-E 3 (may differ from input prompt)
    public let revisedPrompt: String?

    enum CodingKeys: String, CodingKey {
        case url
        case revisedPrompt = "revised_prompt"
        case b64Json = "b64_json"
    }
}
