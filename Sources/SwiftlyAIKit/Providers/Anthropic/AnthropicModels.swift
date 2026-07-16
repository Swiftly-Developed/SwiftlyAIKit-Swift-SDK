import Foundation

/// Anthropic Claude API Models
///
/// Provider-specific request and response types for Anthropic's Messages API.
///
/// ## See Also
/// - ``AnthropicProvider``
/// - <doc:AnthropicGuide>

// MARK: - Dynamic Coding Key

/// A coding key that accepts any string, used to capture arbitrary/unknown JSON keys
/// for byte-faithful round-tripping of native Anthropic blocks and tool definitions.
struct AnthropicDynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Decode the entire current object as a raw `[String: AnyCodable]` dictionary.
/// Used to preserve every field of server-tool / unknown blocks that the typed
/// model does not otherwise capture (e.g. `encrypted_content`, `tool_use_id`).
func anthropicDecodeRawObject(from decoder: Decoder) throws -> AnyCodable {
    let container = try decoder.container(keyedBy: AnthropicDynamicKey.self)
    var dict: [String: Any] = [:]
    for key in container.allKeys {
        // Store fully-unwrapped values so consumers see plain [String: Any] trees
        // (not nested AnyCodable), consistent with the rest of providerData.
        dict[key.stringValue] = try container.decode(AnyCodable.self, forKey: key).value
    }
    return AnyCodable(dict)
}

// MARK: - Content Blocks

/// Represents different types of content blocks in Anthropic messages
public enum AnthropicContentBlock: Codable, Sendable, Equatable {
    /// Plain text content
    case text(String)

    /// Plain text content carrying an ephemeral cache_control marker (prompt caching).
    /// Only produced on the request side; decodes back to `.text`.
    case textWithCacheControl(String, AnthropicCacheControl)

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

    /// Server-initiated tool use (e.g. web_search handled by Anthropic)
    case serverToolUse(id: String, name: String)

    /// Web search tool result returned by Anthropic's native web search
    case webSearchToolResult(rawJSON: AnyCodable)

    /// Catch-all for unknown/future content block types — preserves raw JSON
    case unknown(type: String, rawJSON: AnyCodable)

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
        case cacheControl = "cache_control"
        case thinking
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
            // Anthropic sends reasoning under the "thinking" key (not "text").
            let text = try container.decode(String.self, forKey: .thinking)
            self = .thinking(text)
        case "server_tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            self = .serverToolUse(id: id, name: name)
        case "web_search_tool_result":
            // Capture the ENTIRE block (type, tool_use_id, content with urls/text/
            // encrypted_content) so citations can be relayed and the block re-sent faithfully.
            self = .webSearchToolResult(rawJSON: try anthropicDecodeRawObject(from: decoder))
        default:
            // Lenient fallback: preserve the full raw block for unknown/future types
            // (e.g. AI19's tool_search_tool_result) instead of discarding it.
            self = .unknown(type: type, rawJSON: try anthropicDecodeRawObject(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        // Native server-tool / unknown blocks round-trip byte-faithfully via their captured
        // raw JSON (the whole object, including type + any fields the typed model omits).
        switch self {
        case .webSearchToolResult(let rawJSON):
            try rawJSON.encode(to: encoder)
            return
        case .unknown(_, let rawJSON):
            try rawJSON.encode(to: encoder)
            return
        default:
            break
        }

        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .textWithCacheControl(let text, let cacheControl):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encode(cacheControl, forKey: .cacheControl)
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
            try container.encode(text, forKey: .thinking)
        case .serverToolUse(let id, let name):
            try container.encode("server_tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
        case .webSearchToolResult, .unknown:
            break // handled above via raw-JSON passthrough
        }
    }
}

// MARK: - Tool Definitions

/// Tool definition for function calling
///
/// Supports both regular custom tools (name + description + inputSchema)
/// and Anthropic native tools like web_search (type + name, no description/schema).
public struct AnthropicToolDefinition: Sendable, Equatable {
    /// Tool type — e.g. "web_search_20250305" for native tools, nil for custom tools
    public let type: String?
    public let name: String?
    public let description: String?
    public let inputSchema: ToolInputSchema?
    /// Optional ephemeral cache_control marker (prompt caching)
    public let cacheControl: AnthropicCacheControl?
    /// Deferred loading flag (Anthropic tool-search hot/cold set, `defer_loading`).
    public let deferLoading: Bool?
    /// Any additional tool fields not modelled explicitly, preserved for byte-faithful
    /// round-tripping of `rawToolsJSON` (e.g. future / native tool parameters).
    public let extras: [String: AnyCodable]?

    /// Full memberwise initializer
    public init(
        type: String?,
        name: String?,
        description: String?,
        inputSchema: ToolInputSchema?,
        cacheControl: AnthropicCacheControl? = nil,
        deferLoading: Bool? = nil,
        extras: [String: AnyCodable]? = nil
    ) {
        self.type = type
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.extras = extras
    }

    public init(name: String, description: String, inputSchema: ToolInputSchema) {
        self.init(type: nil, name: name, description: description, inputSchema: inputSchema)
    }

    /// Initializer for native Anthropic tools (e.g. web_search)
    public init(type: String, name: String) {
        self.init(type: type, name: name, description: nil, inputSchema: nil)
    }

    /// Return a copy of this tool definition with the given cache_control applied.
    public func withCacheControl(_ cacheControl: AnthropicCacheControl?) -> AnthropicToolDefinition {
        AnthropicToolDefinition(
            type: type,
            name: name,
            description: description,
            inputSchema: inputSchema,
            cacheControl: cacheControl,
            deferLoading: deferLoading,
            extras: extras
        )
    }
}

extension AnthropicToolDefinition: Codable {
    enum CodingKeys: String, CodingKey {
        case type, name, description, inputSchema = "input_schema", cacheControl = "cache_control"
        case deferLoading = "defer_loading"
    }

    /// Keys handled explicitly; everything else is captured into `extras`.
    private static let knownKeys: Set<String> = [
        "type", "name", "description", "input_schema", "cache_control", "defer_loading"
    ]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.inputSchema = try container.decodeIfPresent(ToolInputSchema.self, forKey: .inputSchema)
        self.cacheControl = try container.decodeIfPresent(AnthropicCacheControl.self, forKey: .cacheControl)
        self.deferLoading = try container.decodeIfPresent(Bool.self, forKey: .deferLoading)

        // Capture any additional keys so rawToolsJSON round-trips byte-faithfully.
        let dynamic = try decoder.container(keyedBy: AnthropicDynamicKey.self)
        var extras: [String: AnyCodable] = [:]
        for key in dynamic.allKeys where !Self.knownKeys.contains(key.stringValue) {
            extras[key.stringValue] = try dynamic.decode(AnyCodable.self, forKey: key)
        }
        self.extras = extras.isEmpty ? nil : extras
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(inputSchema, forKey: .inputSchema)
        try container.encodeIfPresent(cacheControl, forKey: .cacheControl)
        try container.encodeIfPresent(deferLoading, forKey: .deferLoading)

        if let extras {
            var dynamic = encoder.container(keyedBy: AnthropicDynamicKey.self)
            for (key, value) in extras {
                guard let codingKey = AnthropicDynamicKey(stringValue: key) else { continue }
                try dynamic.encode(value, forKey: codingKey)
            }
        }
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
///
/// Encodes to Anthropic's wire format `{"type": "enabled", "budget_tokens": N}` while
/// exposing a friendly `enabled` Bool in Swift. When disabled, only `{"type": "disabled"}`
/// is emitted.
public struct AnthropicThinkingConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let budgetTokens: Int?

    enum CodingKeys: String, CodingKey {
        case type, budgetTokens = "budget_tokens"
    }

    public init(enabled: Bool, budgetTokens: Int? = nil) {
        self.enabled = enabled
        self.budgetTokens = budgetTokens
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? "disabled"
        self.enabled = (type == "enabled")
        self.budgetTokens = try container.decodeIfPresent(Int.self, forKey: .budgetTokens)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled ? "enabled" : "disabled", forKey: .type)
        // Anthropic requires budget_tokens only when thinking is enabled.
        if enabled, let budgetTokens {
            try container.encode(budgetTokens, forKey: .budgetTokens)
        }
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
    /// When set, these raw message objects are emitted verbatim for the `messages`
    /// wire field instead of the typed `messages`. Preserves native content blocks
    /// (server_tool_use, web_search_tool_result with encrypted_content, etc.) that the
    /// typed model cannot represent losslessly. Not part of the decoded wire form.
    public let rawMessages: [AnyCodable]?

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
        thinking: AnthropicThinkingConfig? = nil,
        rawMessages: [AnyCodable]? = nil
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
        self.rawMessages = rawMessages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decode(String.self, forKey: .model)
        self.messages = try container.decode([AnthropicMessage].self, forKey: .messages)
        self.maxTokens = try container.decode(Int.self, forKey: .maxTokens)
        self.system = try container.decodeIfPresent(AnthropicSystemPrompt.self, forKey: .system)
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        self.topP = try container.decodeIfPresent(Double.self, forKey: .topP)
        self.topK = try container.decodeIfPresent(Int.self, forKey: .topK)
        self.stopSequences = try container.decodeIfPresent([String].self, forKey: .stopSequences)
        self.metadata = try container.decodeIfPresent(AnthropicMetadata.self, forKey: .metadata)
        self.stream = try container.decodeIfPresent(Bool.self, forKey: .stream)
        self.tools = try container.decodeIfPresent([AnthropicToolDefinition].self, forKey: .tools)
        self.toolChoice = try container.decodeIfPresent(AnthropicToolChoice.self, forKey: .toolChoice)
        self.thinking = try container.decodeIfPresent(AnthropicThinkingConfig.self, forKey: .thinking)
        self.rawMessages = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        // Emit raw message objects verbatim when provided; otherwise the typed messages.
        if let rawMessages {
            try container.encode(rawMessages, forKey: .messages)
        } else {
            try container.encode(messages, forKey: .messages)
        }
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(system, forKey: .system)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(topP, forKey: .topP)
        try container.encodeIfPresent(topK, forKey: .topK)
        try container.encodeIfPresent(stopSequences, forKey: .stopSequences)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(stream, forKey: .stream)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(toolChoice, forKey: .toolChoice)
        try container.encodeIfPresent(thinking, forKey: .thinking)
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

            enum CodingKeys: String, CodingKey {
                case id, type, role, content, model
                case stopReason = "stop_reason"
                case usage
            }
        }

        /// Usage info in streaming - fields are optional since they may not be present initially
        public struct StreamUsage: Codable, Sendable {
            public let inputTokens: Int?
            public let outputTokens: Int?
            public let cacheCreationInputTokens: Int?
            public let cacheReadInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }
    }

    public struct AnthropicStreamContentBlockStart: Codable, Sendable {
        public let type: String
        public let index: Int
        public let contentBlock: AnthropicContentBlock

        enum CodingKeys: String, CodingKey {
            case type, index
            case contentBlock = "content_block"
        }
    }

    public struct AnthropicStreamContentBlockDelta: Codable, Sendable {
        public let type: String
        public let index: Int
        public let delta: Delta

        public struct Delta: Codable, Sendable {
            public let type: String
            public let text: String?
            public let partialJson: String?

            enum CodingKeys: String, CodingKey {
                case type, text
                case partialJson = "partial_json"
            }

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

            enum CodingKeys: String, CodingKey {
                case stopReason = "stop_reason"
                case stopSequence = "stop_sequence"
            }
        }

        /// Usage info in message_delta - all fields optional for flexibility
        public struct StreamDeltaUsage: Codable, Sendable {
            public let inputTokens: Int?
            public let outputTokens: Int?
            public let cacheCreationInputTokens: Int?
            public let cacheReadInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
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

// MARK: - Models List Response

/// Anthropic models list response
public struct AnthropicModelsResponse: Codable, Sendable {
    /// Array of available models
    public let data: [AnthropicModelInfo]

    /// Whether there are more results beyond this page
    public let hasMore: Bool

    /// ID of the first model in this page (for pagination)
    public let firstId: String?

    /// ID of the last model in this page (for pagination)
    public let lastId: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }

    public init(data: [AnthropicModelInfo], hasMore: Bool = false, firstId: String? = nil, lastId: String? = nil) {
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
    }
}

/// Anthropic model information
public struct AnthropicModelInfo: Codable, Sendable {
    /// Object type (always "model")
    public let type: String

    /// Model ID
    public let id: String

    /// Human-readable display name
    public let displayName: String

    /// RFC 3339 timestamp of model release
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case type, id
        case displayName = "display_name"
        case createdAt = "created_at"
    }

    public init(type: String = "model", id: String, displayName: String, createdAt: String) {
        self.type = type
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
