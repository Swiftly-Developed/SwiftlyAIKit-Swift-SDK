import Foundation

/// Perplexity **Agent API** models (the OpenAI *Responses*-API shape).
///
/// Perplexity's Sonar Chat Completions endpoint (`/chat/completions`, see
/// ``PerplexityRequest``/``PerplexityResponse``) has no function/tool calling. Custom function
/// calling lives on the separate **Agent API** (`POST /v1/agent`, alias `POST /v1/responses`),
/// which is fully compatible with OpenAI's Responses API: an `input` item list, a flattened
/// `tools` array, and an `output` item list carrying `message` and `function_call` items.
///
/// These wire types back ``PerplexityProvider``'s tool-calling path. Request types are
/// `Encodable` only (requests are never decoded); response/stream types are `Codable`.
///
/// ## See Also
/// - ``PerplexityProvider``
/// - <doc:PerplexityGuide>

// MARK: - Request

/// A single item in the Agent API `input` array.
///
/// The Responses shape accepts a heterogeneous input list: plain conversation messages, replayed
/// `function_call` items the model previously emitted, and `function_call_output` items carrying
/// your tool results. `call_id` is the correlation key tying a `function_call` to its output.
public enum PerplexityAgentInputItem: Encodable, Sendable, Equatable {
    /// A conversation message (`{"role": ..., "content": ...}`).
    case message(role: String, content: String)

    /// A tool call the model previously emitted, replayed on a follow-up turn
    /// (`{"type": "function_call", "call_id": ..., "name": ..., "arguments": ...}`).
    case functionCall(callID: String, name: String, arguments: String)

    /// A tool result fed back to the model (`{"type": "function_call_output", "call_id": ..., "output": ...}`).
    case functionCallOutput(callID: String, output: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
        case callID = "call_id"
        case name
        case arguments
        case output
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .message(role, content):
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        case let .functionCall(callID, name, arguments):
            try container.encode("function_call", forKey: .type)
            try container.encode(callID, forKey: .callID)
            try container.encode(name, forKey: .name)
            try container.encode(arguments, forKey: .arguments)
        case let .functionCallOutput(callID, output):
            try container.encode("function_call_output", forKey: .type)
            try container.encode(callID, forKey: .callID)
            try container.encode(output, forKey: .output)
        }
    }
}

/// A custom function tool in the Agent API `tools` array.
///
/// The Responses shape flattens the function definition to the top level
/// (`type`/`name`/`description`/`parameters`), unlike Chat Completions which nests it under a
/// `function` object.
public struct PerplexityAgentTool: Encodable, Sendable {
    public let type: String
    public let name: String
    public let description: String
    public let parameters: [String: AnyCodable]

    public init(name: String, description: String, parameters: [String: AnyCodable]) {
        self.type = "function"
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Controls which tools the Agent API model may call (`tool_choice`).
///
/// A specific-function choice is the flattened Responses form `{"type": "function", "name": ...}`
/// (not the Chat Completions `{"type": "function", "function": {"name": ...}}`).
public enum PerplexityAgentToolChoice: Encodable, Sendable, Equatable {
    case auto
    case required
    case none
    case function(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case name
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .auto:
            var container = encoder.singleValueContainer()
            try container.encode("auto")
        case .required:
            var container = encoder.singleValueContainer()
            try container.encode("required")
        case .none:
            var container = encoder.singleValueContainer()
            try container.encode("none")
        case let .function(name):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("function", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
}

/// An Agent API request (`POST /v1/responses`).
public struct PerplexityAgentRequest: Encodable, Sendable {
    public let model: String
    public let input: [PerplexityAgentInputItem]
    public let instructions: String?
    public let maxOutputTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let stream: Bool?
    public let tools: [PerplexityAgentTool]?
    public let toolChoice: PerplexityAgentToolChoice?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case instructions
        case maxOutputTokens = "max_output_tokens"
        case temperature
        case topP = "top_p"
        case stream
        case tools
        case toolChoice = "tool_choice"
    }

    public init(
        model: String,
        input: [PerplexityAgentInputItem],
        instructions: String? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        stream: Bool? = nil,
        tools: [PerplexityAgentTool]? = nil,
        toolChoice: PerplexityAgentToolChoice? = nil
    ) {
        self.model = model
        self.input = input
        self.instructions = instructions
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.topP = topP
        self.stream = stream
        self.tools = tools
        self.toolChoice = toolChoice
    }
}

// MARK: - Response

/// A content part inside an Agent API `message` output item (`{"type": "output_text", "text": ...}`).
public struct PerplexityAgentContentPart: Codable, Sendable {
    public let type: String
    public let text: String?

    public init(type: String, text: String? = nil) {
        self.type = type
        self.text = text
    }
}

/// An item in the Agent API response `output` array.
///
/// Either a `message` (assistant text in `content[].text`) or a `function_call` (a tool invocation
/// with `id`/`call_id`/`name`/`arguments`). Fields are optional because each item type populates
/// only the ones relevant to it.
public struct PerplexityAgentOutputItem: Codable, Sendable {
    public let type: String
    public let role: String?
    public let content: [PerplexityAgentContentPart]?
    public let id: String?
    public let callID: String?
    public let name: String?
    public let arguments: String?

    enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
        case id
        case callID = "call_id"
        case name
        case arguments
    }

    public init(
        type: String,
        role: String? = nil,
        content: [PerplexityAgentContentPart]? = nil,
        id: String? = nil,
        callID: String? = nil,
        name: String? = nil,
        arguments: String? = nil
    ) {
        self.type = type
        self.role = role
        self.content = content
        self.id = id
        self.callID = callID
        self.name = name
        self.arguments = arguments
    }
}

/// Token usage for an Agent API response (`input_tokens`/`output_tokens`).
public struct PerplexityAgentUsage: Codable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    public init(inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// An Agent API response (`POST /v1/responses`).
public struct PerplexityAgentResponse: Codable, Sendable {
    public let id: String
    public let model: String?
    public let status: String?
    public let output: [PerplexityAgentOutputItem]
    public let usage: PerplexityAgentUsage?

    public init(
        id: String,
        model: String? = nil,
        status: String? = nil,
        output: [PerplexityAgentOutputItem],
        usage: PerplexityAgentUsage? = nil
    ) {
        self.id = id
        self.model = model
        self.status = status
        self.output = output
        self.usage = usage
    }
}

// MARK: - Streaming

/// A single Server-Sent Event from an Agent API streaming run.
///
/// Events are typed (`response.output_text.delta`, `response.output_item.added`,
/// `response.function_call_arguments.delta`/`.done`, `response.completed`, …). Fields are optional
/// because each event type populates only the ones relevant to it; `response.completed` carries the
/// full terminal ``PerplexityAgentResponse`` under `response`.
public struct PerplexityAgentStreamEvent: Codable, Sendable {
    public let type: String
    public let delta: String?
    public let itemID: String?
    public let outputIndex: Int?
    public let item: PerplexityAgentOutputItem?
    public let arguments: String?
    public let response: PerplexityAgentResponse?

    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case itemID = "item_id"
        case outputIndex = "output_index"
        case item
        case arguments
        case response
    }

    public init(
        type: String,
        delta: String? = nil,
        itemID: String? = nil,
        outputIndex: Int? = nil,
        item: PerplexityAgentOutputItem? = nil,
        arguments: String? = nil,
        response: PerplexityAgentResponse? = nil
    ) {
        self.type = type
        self.delta = delta
        self.itemID = itemID
        self.outputIndex = outputIndex
        self.item = item
        self.arguments = arguments
        self.response = response
    }
}
