import Foundation

/// Anthropic Claude API Models
///
/// Provider-specific request and response types for Anthropic's Messages API.
///
/// ## See Also
/// - ``AnthropicProvider``
/// - <doc:AnthropicGuide>

// MARK: - Content Blocks

/// Represents different types of content blocks in Anthropic messages
public enum AnthropicContentBlock: Codable, Sendable, Equatable {
    /// Plain text content
    case text(String)

    /// Image content
    case image(source: ImageSource)

    /// Document content (PDF, etc.)
    case document(source: DocumentSource)

    /// Tool use request
    case toolUse(id: String, name: String, input: [String: AnyCodable])

    /// Tool use result
    case toolResult(toolUseId: String, content: String, isError: Bool)

    /// Thinking content (extended thinking)
    case thinking(String)

    public enum ImageSource: Codable, Sendable, Equatable {
        case base64(data: String, mediaType: String)
        case url(String)

        enum CodingKeys: String, CodingKey {
            case type, data, mediaType = "media_type", url
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "base64":
                let data = try container.decode(String.self, forKey: .data)
                let mediaType = try container.decode(String.self, forKey: .mediaType)
                self = .base64(data: data, mediaType: mediaType)
            case "url":
                let url = try container.decode(String.self, forKey: .url)
                self = .url(url)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown image source type: \(type)"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .base64(let data, let mediaType):
                try container.encode("base64", forKey: .type)
                try container.encode(data, forKey: .data)
                try container.encode(mediaType, forKey: .mediaType)
            case .url(let url):
                try container.encode("url", forKey: .type)
                try container.encode(url, forKey: .url)
            }
        }
    }

    public struct DocumentSource: Codable, Sendable, Equatable {
        public let type: String
        public let mediaType: String
        public let data: String

        enum CodingKeys: String, CodingKey {
            case type, mediaType = "media_type", data
        }

        public init(type: String = "base64", mediaType: String, data: String) {
            self.type = type
            self.mediaType = mediaType
            self.data = data
        }
    }

    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input, toolUseId = "tool_use_id", content, isError = "is_error"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let source = try container.decode(ImageSource.self, forKey: .source)
            self = .image(source: source)
        case "document":
            let source = try container.decode(DocumentSource.self, forKey: .source)
            self = .document(source: source)
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decode([String: AnyCodable].self, forKey: .input)
            self = .toolUse(id: id, name: name, input: input)
        case "tool_result":
            let toolUseId = try container.decode(String.self, forKey: .toolUseId)
            let content = try container.decode(String.self, forKey: .content)
            let isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
            self = .toolResult(toolUseId: toolUseId, content: content, isError: isError)
        case "thinking":
            let text = try container.decode(String.self, forKey: .text)
            self = .thinking(text)
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
        case .image(let source):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
        case .document(let source):
            try container.encode("document", forKey: .type)
            try container.encode(source, forKey: .source)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseId, let content, let isError):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseId, forKey: .toolUseId)
            try container.encode(content, forKey: .content)
            try container.encode(isError, forKey: .isError)
        case .thinking(let text):
            try container.encode("thinking", forKey: .type)
            try container.encode(text, forKey: .text)
        }
    }
}

// MARK: - Tool Definitions

/// Tool definition for function calling
public struct AnthropicToolDefinition: Codable, Sendable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: ToolInputSchema

    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema = "input_schema"
    }

    public init(name: String, description: String, inputSchema: ToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// JSON Schema for tool input
public struct ToolInputSchema: Codable, Sendable, Equatable {
    public let type: String
    public let properties: [String: AnyCodable]?
    public let required: [String]?

    public init(type: String = "object", properties: [String: AnyCodable]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// Tool choice configuration
public enum AnthropicToolChoice: Codable, Sendable, Equatable {
    case auto
    case any
    case tool(String)

    enum CodingKeys: String, CodingKey {
        case type, name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "auto":
            self = .auto
        case "any":
            self = .any
        case "tool":
            let name = try container.decode(String.self, forKey: .name)
            self = .tool(name)
        default:
            self = .auto
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .auto:
            try container.encode("auto", forKey: .type)
        case .any:
            try container.encode("any", forKey: .type)
        case .tool(let name):
            try container.encode("tool", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
}

// MARK: - Prompt Caching

/// Cache control for prompt caching
public struct AnthropicCacheControl: Codable, Sendable, Equatable {
    public let type: String
    public let ttl: String?

    public init(type: String = "ephemeral", ttl: String? = nil) {
        self.type = type
        self.ttl = ttl
    }
}

// MARK: - Extended Thinking

/// Extended thinking configuration
public struct AnthropicThinkingConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let budgetTokens: Int?

    enum CodingKeys: String, CodingKey {
        case enabled, budgetTokens = "budget_tokens"
    }

    public init(enabled: Bool, budgetTokens: Int? = nil) {
        self.enabled = enabled
        self.budgetTokens = budgetTokens
    }
}

// MARK: - Messages

/// Anthropic message structure
public struct AnthropicMessage: Codable, Sendable, Equatable {
    public let role: String
    public let content: [AnthropicContentBlock]

    public init(role: String, content: [AnthropicContentBlock]) {
        self.role = role
        self.content = content
    }

    public init(role: String, text: String) {
        self.role = role
        self.content = [.text(text)]
    }
}

/// System prompt (can be string or array)
public enum AnthropicSystemPrompt: Codable, Sendable, Equatable {
    case text(String)
    case blocks([SystemBlock])

    public struct SystemBlock: Codable, Sendable, Equatable {
        public let type: String
        public let text: String
        public let cacheControl: AnthropicCacheControl?

        enum CodingKeys: String, CodingKey {
            case type, text, cacheControl = "cache_control"
        }

        public init(type: String = "text", text: String, cacheControl: AnthropicCacheControl? = nil) {
            self.type = type
            self.text = text
            self.cacheControl = cacheControl
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let blocks = try? container.decode([SystemBlock].self) {
            self = .blocks(blocks)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Could not decode system prompt"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .text(let text):
            try container.encode(text)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }
}

/// Metadata for request tracking
public struct AnthropicMetadata: Codable, Sendable, Equatable {
    public let userId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }

    public init(userId: String? = nil) {
        self.userId = userId
    }
}

// MARK: - Request

/// Complete Anthropic API request
public struct AnthropicRequest: Codable, Sendable {
    public let model: String
    public let messages: [AnthropicMessage]
    public let maxTokens: Int
    public let system: AnthropicSystemPrompt?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let stopSequences: [String]?
    public let metadata: AnthropicMetadata?
    public let stream: Bool?
    public let tools: [AnthropicToolDefinition]?
    public let toolChoice: AnthropicToolChoice?
    public let thinking: AnthropicThinkingConfig?

    enum CodingKeys: String, CodingKey {
        case model, messages, maxTokens = "max_tokens", system, temperature
        case topP = "top_p", topK = "top_k", stopSequences = "stop_sequences"
        case metadata, stream, tools, toolChoice = "tool_choice", thinking
    }

    public init(
        model: String,
        messages: [AnthropicMessage],
        maxTokens: Int,
        system: AnthropicSystemPrompt? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String]? = nil,
        metadata: AnthropicMetadata? = nil,
        stream: Bool? = nil,
        tools: [AnthropicToolDefinition]? = nil,
        toolChoice: AnthropicToolChoice? = nil,
        thinking: AnthropicThinkingConfig? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.system = system
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
        self.metadata = metadata
        self.stream = stream
        self.tools = tools
        self.toolChoice = toolChoice
        self.thinking = thinking
    }
}

// MARK: - Response

/// Token usage information
public struct AnthropicUsage: Codable, Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }
}

/// Stop reason for response
public enum AnthropicStopReason: String, Codable, Sendable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"
    case pauseTurn = "pause_turn"
    case refusal = "refusal"
}

/// Complete Anthropic API response
public struct AnthropicResponse: Codable, Sendable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [AnthropicContentBlock]
    public let model: String
    public let stopReason: AnthropicStopReason?
    public let stopSequence: String?
    public let usage: AnthropicUsage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }

    public init(
        id: String,
        type: String,
        role: String,
        content: [AnthropicContentBlock],
        model: String,
        stopReason: AnthropicStopReason?,
        stopSequence: String?,
        usage: AnthropicUsage
    ) {
        self.id = id
        self.type = type
        self.role = role
        self.content = content
        self.model = model
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
    }
}

// MARK: - Streaming Events

/// Server-Sent Events for streaming
public enum AnthropicStreamEvent: Codable, Sendable {
    case messageStart(AnthropicStreamMessageStart)
    case contentBlockStart(AnthropicStreamContentBlockStart)
    case contentBlockDelta(AnthropicStreamContentBlockDelta)
    case contentBlockStop(AnthropicStreamContentBlockStop)
    case messageDelta(AnthropicStreamMessageDelta)
    case messageStop
    case ping
    case error(AnthropicStreamError)

    public struct AnthropicStreamMessageStart: Codable, Sendable {
        public let type: String
        public let message: PartialMessage

        public struct PartialMessage: Codable, Sendable {
            public let id: String
            public let type: String
            public let role: String
            public let content: [AnthropicContentBlock]
            public let model: String
            public let stopReason: AnthropicStopReason?
            public let usage: StreamUsage
            // Note: No CodingKeys needed - decoder uses convertFromSnakeCase
        }

        /// Usage info in streaming - fields are optional since they may not be present initially
        public struct StreamUsage: Codable, Sendable {
            public let inputTokens: Int?
            public let outputTokens: Int?
            public let cacheCreationInputTokens: Int?
            public let cacheReadInputTokens: Int?
            // Note: No CodingKeys needed - decoder uses convertFromSnakeCase
        }
    }

    public struct AnthropicStreamContentBlockStart: Codable, Sendable {
        public let type: String
        public let index: Int
        public let contentBlock: AnthropicContentBlock
        // Note: No CodingKeys needed - decoder uses convertFromSnakeCase
    }

    public struct AnthropicStreamContentBlockDelta: Codable, Sendable {
        public let type: String
        public let index: Int
        public let delta: Delta

        public struct Delta: Codable, Sendable {
            public let type: String
            public let text: String?
            public let partialJson: String?

            public init(type: String, text: String?, partialJson: String? = nil) {
                self.type = type
                self.text = text
                self.partialJson = partialJson
            }
        }
    }

    public struct AnthropicStreamContentBlockStop: Codable, Sendable {
        public let type: String
        public let index: Int
    }

    public struct AnthropicStreamMessageDelta: Codable, Sendable {
        public let type: String
        public let delta: Delta
        public let usage: StreamDeltaUsage?

        public struct Delta: Codable, Sendable {
            public let stopReason: AnthropicStopReason?
            public let stopSequence: String?
            // Note: No CodingKeys needed - decoder uses convertFromSnakeCase
        }

        /// Usage info in message_delta - all fields optional for flexibility
        public struct StreamDeltaUsage: Codable, Sendable {
            public let inputTokens: Int?
            public let outputTokens: Int?
            public let cacheCreationInputTokens: Int?
            public let cacheReadInputTokens: Int?
            // Note: No CodingKeys needed - decoder uses convertFromSnakeCase
        }
    }

    public struct AnthropicStreamError: Codable, Sendable {
        public let type: String
        public let error: ErrorDetail

        public struct ErrorDetail: Codable, Sendable {
            public let type: String
            public let message: String
        }
    }
}

// MARK: - Batch API

/// Batch request item
public struct AnthropicBatchRequest: Codable, Sendable {
    public let customId: String
    public let params: AnthropicRequest

    enum CodingKeys: String, CodingKey {
        case customId = "custom_id"
        case params
    }

    public init(customId: String, params: AnthropicRequest) {
        self.customId = customId
        self.params = params
    }
}

/// Batch status
public enum AnthropicBatchStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case canceling = "canceling"
    case canceled = "canceled"
}

/// Request counts in batch
public struct AnthropicBatchRequestCounts: Codable, Sendable {
    public let processing: Int
    public let succeeded: Int
    public let errored: Int
    public let canceled: Int
    public let expired: Int

    public init(processing: Int, succeeded: Int, errored: Int, canceled: Int, expired: Int) {
        self.processing = processing
        self.succeeded = succeeded
        self.errored = errored
        self.canceled = canceled
        self.expired = expired
    }
}

/// Batch response
public struct AnthropicBatch: Codable, Sendable {
    public let id: String
    public let type: String
    public let processingStatus: AnthropicBatchStatus
    public let requestCounts: AnthropicBatchRequestCounts
    public let endedAt: String?
    public let createdAt: String
    public let expiresAt: String
    public let archivedAt: String?
    public let cancelInitiatedAt: String?
    public let resultsUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, type
        case processingStatus = "processing_status"
        case requestCounts = "request_counts"
        case endedAt = "ended_at"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case archivedAt = "archived_at"
        case cancelInitiatedAt = "cancel_initiated_at"
        case resultsUrl = "results_url"
    }
}

/// Batch result
public struct AnthropicBatchResult: Codable, Sendable {
    public let customId: String
    public let result: BatchResultType

    enum CodingKeys: String, CodingKey {
        case customId = "custom_id"
        case result
    }

    public enum BatchResultType: Codable, Sendable {
        case success(AnthropicResponse)
        case error(BatchError)

        public struct BatchError: Codable, Sendable {
            public let type: String
            public let message: String
        }
    }
}

/// Token count response
public struct AnthropicTokenCountResponse: Codable, Sendable {
    public let inputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
    }

    public init(inputTokens: Int) {
        self.inputTokens = inputTokens
    }
}

// MARK: - Error Response

/// Anthropic API error response
public struct AnthropicErrorResponse: Codable, Sendable {
    public let type: String
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let type: String
        public let message: String
    }
}
