import Foundation

/// Represents a tool/function that can be called by the AI model
///
/// Tools allow AI models to interact with external systems by calling functions.
/// The model can decide when to call a tool based on the user's request.
///
/// ## Overview
///
/// Function calling (tool use) enables AI models to:
/// - Access real-time data (weather, stock prices, database queries)
/// - Perform actions (send emails, create records, make API calls)
/// - Use your custom logic when needed
///
/// ## Simple Tool
///
/// ```swift
/// let weatherTool = AITool(
///     name: "get_weather",
///     description: "Get the current weather for a location",
///     parameters: AIToolParameters(
///         type: "object",
///         properties: [
///             "location": AIToolProperty(
///                 type: "string",
///                 description: "City and state, e.g. San Francisco, CA"
///             ),
///             "unit": AIToolProperty(
///                 type: "string",
///                 description: "Temperature unit",
///                 enumValues: ["celsius", "fahrenheit"]
///             )
///         ],
///         required: ["location"]
///     )
/// )
/// ```
///
/// ## Using Tools
///
/// ```swift
/// let request = AIRequest(
///     model: .claude(.sonnet4_5),
///     messages: [.user("What's the weather in Tokyo?")],
///     tools: [weatherTool]
/// )
///
/// let response = try await gateway.sendMessage(request)
///
/// if let toolCalls = response.toolCalls {
///     for call in toolCalls {
///         if call.name == "get_weather" {
///             let location = call.arguments["location"] as? String
///             // Execute your function
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Tools
/// - ``init(name:description:parameters:)``
///
/// ### Tool Properties
/// - ``name``
/// - ``description``
/// - ``parameters``
///
/// ### Parameter Schemas
/// - ``AIToolParameters``
/// - ``AIToolProperty``
/// - ``AIToolChoice``
/// - ``AIToolCall``
///
/// ### Related Types
/// - ``AIRequest``
/// - ``AIResponse``
///
/// ## See Also
/// - <doc:ToolCalling>
/// - ``AIGateway``
public struct AITool: Codable, Sendable, Hashable {
    /// Unique name of the tool/function
    public let name: String

    /// Human-readable description of what the tool does
    public let description: String

    /// JSON Schema defining the parameters this tool accepts
    public let parameters: AIToolParameters

    /// Initialize a new AI tool
    ///
    /// - Parameters:
    ///   - name: Tool name (must be valid function name)
    ///   - description: What the tool does
    ///   - parameters: JSON Schema for parameters
    public init(
        name: String,
        description: String,
        parameters: AIToolParameters
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// JSON Schema definition for tool parameters
///
/// Follows JSON Schema specification for defining object properties and validation rules.
public struct AIToolParameters: Codable, Sendable, Hashable {
    /// Schema type (typically "object")
    public let type: String

    /// Property definitions for the parameters
    public let properties: [String: AIToolProperty]

    /// Required property names
    public let required: [String]?

    /// Additional properties allowed
    public let additionalProperties: Bool?

    /// Initialize tool parameters schema
    ///
    /// - Parameters:
    ///   - type: Schema type (default: "object")
    ///   - properties: Property definitions
    ///   - required: Required property names
    ///   - additionalProperties: Allow additional properties (default: false)
    public init(
        type: String = "object",
        properties: [String: AIToolProperty],
        required: [String]? = nil,
        additionalProperties: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }
}

/// Property definition within tool parameters
///
/// Defines a single parameter's type, description, and validation rules.
public struct AIToolProperty: Codable, Sendable, Hashable {
    /// Property type (string, number, integer, boolean, array, object)
    public let type: String

    /// Human-readable description of the property
    public let description: String?

    /// Allowed values for enum properties
    public let `enum`: [String]?

    /// Items schema for array properties
    public let items: AIToolPropertyItems?

    /// Minimum value for number/integer properties
    public let minimum: Double?

    /// Maximum value for number/integer properties
    public let maximum: Double?

    /// Nested property definitions for object-typed properties
    ///
    /// Present when `type == "object"`. Enables faithful representation of nested
    /// object schemas across providers. Dictionaries provide the indirection needed
    /// for this otherwise-recursive type.
    public let properties: [String: AIToolProperty]?

    /// Required nested property names (for object-typed properties)
    public let required: [String]?

    /// Initialize a tool property
    ///
    /// - Parameters:
    ///   - type: Property type
    ///   - description: Property description
    ///   - enumValues: Allowed enum values
    ///   - items: Array item schema
    ///   - minimum: Minimum numeric value
    ///   - maximum: Maximum numeric value
    ///   - properties: Nested property definitions (for object types)
    ///   - required: Required nested property names (for object types)
    public init(
        type: String,
        description: String? = nil,
        enumValues: [String]? = nil,
        items: AIToolPropertyItems? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        properties: [String: AIToolProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.items = items
        self.minimum = minimum
        self.maximum = maximum
        self.properties = properties
        self.required = required
    }

    /// Custom coding keys to handle enum keyword
    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case `enum`
        case items
        case minimum
        case maximum
        case properties
        case required
    }
}

/// Schema for array item properties
///
/// Supports arrays of primitives (type only) and arrays of objects (nested
/// `properties`/`required`).
public struct AIToolPropertyItems: Codable, Sendable, Hashable {
    /// Item type
    public let type: String

    /// Item description
    public let description: String?

    /// Nested property definitions (for arrays of objects, i.e. `type == "object"`)
    public let properties: [String: AIToolProperty]?

    /// Required nested property names (for arrays of objects)
    public let required: [String]?

    /// Initialize array items schema
    ///
    /// - Parameters:
    ///   - type: Item type
    ///   - description: Item description
    ///   - properties: Nested property definitions (for arrays of objects)
    ///   - required: Required nested property names (for arrays of objects)
    public init(
        type: String,
        description: String? = nil,
        properties: [String: AIToolProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.properties = properties
        self.required = required
    }
}

/// Controls which tools the model may call
///
/// Determines if and when the AI model should use the provided tools.
public enum AIToolChoice: Codable, Sendable, Hashable {
    /// Model decides automatically whether to use tools
    case auto

    /// Model must use one of the provided tools
    case required

    /// Model must not use any tools
    case none

    /// Model must use this specific tool
    case specific(String)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .none:
            try container.encode("none")
        case .specific(let toolName):
            let toolChoice: [String: Any] = ["type": "function", "function": ["name": toolName]]
            try container.encode(AnyCodable(toolChoice))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            switch string {
            case "auto":
                self = .auto
            case "required":
                self = .required
            case "none":
                self = .none
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown tool choice: \(string)"
                )
            }
        } else if let dict = try? container.decode([String: [String: String]].self),
                  let function = dict["function"],
                  let name = function["name"] {
            self = .specific(name)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid tool choice format"
            )
        }
    }
}

/// Represents a tool call made by the AI model
///
/// When the model decides to use a tool, it returns a tool call with the function name
/// and arguments. Your application should execute the tool and return the result.
public struct AIToolCall: Codable, Sendable, Hashable {
    /// Unique identifier for this tool call
    public let id: String

    /// Type of tool (typically "function")
    public let type: String

    /// Function/tool name
    public let name: String

    /// JSON-encoded function arguments
    public let arguments: String

    /// Initialize a tool call
    ///
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - type: Tool type
    ///   - name: Function name
    ///   - arguments: JSON arguments
    public init(id: String, type: String = "function", name: String, arguments: String) {
        self.id = id
        self.type = type
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - JSON Schema Serialization

extension AIToolProperty {
    /// Convert this property into a JSON Schema dictionary, recursing into nested
    /// object properties and array item schemas.
    ///
    /// Shared by providers that build raw JSON Schema (OpenAI, Grok, Anthropic's
    /// neutral tool path). Gemini uses its own typed schema converter.
    public func jsonSchemaDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let description { dict["description"] = description }
        if let enumValues = `enum` { dict["enum"] = enumValues }
        if let minimum { dict["minimum"] = minimum }
        if let maximum { dict["maximum"] = maximum }
        if let properties {
            dict["properties"] = properties.mapValues { $0.jsonSchemaDictionary() }
        }
        if let required { dict["required"] = required }
        if let items { dict["items"] = items.jsonSchemaDictionary() }
        return dict
    }
}

extension AIToolPropertyItems {
    /// Convert this array-items schema into a JSON Schema dictionary, recursing into
    /// nested object properties (arrays of objects).
    public func jsonSchemaDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let description { dict["description"] = description }
        if let properties {
            dict["properties"] = properties.mapValues { $0.jsonSchemaDictionary() }
        }
        if let required { dict["required"] = required }
        return dict
    }
}

extension AIToolParameters {
    /// Convert the full parameter schema into a JSON Schema dictionary.
    public func jsonSchemaDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "properties": properties.mapValues { $0.jsonSchemaDictionary() }
        ]
        if let required { dict["required"] = required }
        if let additionalProperties { dict["additionalProperties"] = additionalProperties }
        return dict
    }
}
