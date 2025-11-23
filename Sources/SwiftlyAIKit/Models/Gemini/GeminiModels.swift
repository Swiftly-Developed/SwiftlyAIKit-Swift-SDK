import Foundation

// MARK: - Content and Parts

/// Content part for Gemini API
public enum GeminiPart: Codable, Sendable, Equatable {
    case text(String)
    case inlineData(mimeType: String, data: String)
    case fileData(mimeType: String, fileUri: String)
    case functionCall(name: String, args: [String: AnyCodable])
    case functionResponse(name: String, response: [String: AnyCodable])

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData
        case fileData
        case functionCall
        case functionResponse
    }

    enum InlineDataKeys: String, CodingKey {
        case mimeType
        case data
    }

    enum FileDataKeys: String, CodingKey {
        case mimeType
        case fileUri
    }

    enum FunctionCallKeys: String, CodingKey {
        case name
        case args
    }

    enum FunctionResponseKeys: String, CodingKey {
        case name
        case response
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let text = try? container.decode(String.self, forKey: .text) {
            self = .text(text)
        } else if container.contains(.inlineData) {
            let dataContainer = try container.nestedContainer(keyedBy: InlineDataKeys.self, forKey: .inlineData)
            let mimeType = try dataContainer.decode(String.self, forKey: .mimeType)
            let data = try dataContainer.decode(String.self, forKey: .data)
            self = .inlineData(mimeType: mimeType, data: data)
        } else if container.contains(.fileData) {
            let dataContainer = try container.nestedContainer(keyedBy: FileDataKeys.self, forKey: .fileData)
            let mimeType = try dataContainer.decode(String.self, forKey: .mimeType)
            let fileUri = try dataContainer.decode(String.self, forKey: .fileUri)
            self = .fileData(mimeType: mimeType, fileUri: fileUri)
        } else if container.contains(.functionCall) {
            let callContainer = try container.nestedContainer(keyedBy: FunctionCallKeys.self, forKey: .functionCall)
            let name = try callContainer.decode(String.self, forKey: .name)
            let args = try callContainer.decode([String: AnyCodable].self, forKey: .args)
            self = .functionCall(name: name, args: args)
        } else if container.contains(.functionResponse) {
            let respContainer = try container.nestedContainer(keyedBy: FunctionResponseKeys.self, forKey: .functionResponse)
            let name = try respContainer.decode(String.self, forKey: .name)
            let response = try respContainer.decode([String: AnyCodable].self, forKey: .response)
            self = .functionResponse(name: name, response: response)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown part type")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)

        case .inlineData(let mimeType, let data):
            var dataContainer = container.nestedContainer(keyedBy: InlineDataKeys.self, forKey: .inlineData)
            try dataContainer.encode(mimeType, forKey: .mimeType)
            try dataContainer.encode(data, forKey: .data)

        case .fileData(let mimeType, let fileUri):
            var dataContainer = container.nestedContainer(keyedBy: FileDataKeys.self, forKey: .fileData)
            try dataContainer.encode(mimeType, forKey: .mimeType)
            try dataContainer.encode(fileUri, forKey: .fileUri)

        case .functionCall(let name, let args):
            var callContainer = container.nestedContainer(keyedBy: FunctionCallKeys.self, forKey: .functionCall)
            try callContainer.encode(name, forKey: .name)
            try callContainer.encode(args, forKey: .args)

        case .functionResponse(let name, let response):
            var respContainer = container.nestedContainer(keyedBy: FunctionResponseKeys.self, forKey: .functionResponse)
            try respContainer.encode(name, forKey: .name)
            try respContainer.encode(response, forKey: .response)
        }
    }
}

/// Content for Gemini API (message content)
public struct GeminiContent: Codable, Sendable, Equatable {
    public let role: String?
    public let parts: [GeminiPart]

    public init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

// MARK: - Function Calling

/// Function declaration for Gemini API
public struct GeminiFunctionDeclaration: Codable, Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: GeminiSchema?

    public init(name: String, description: String, parameters: GeminiSchema? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// JSON Schema for function parameters
public struct GeminiSchema: Codable, Sendable, Equatable {
    public let type: String
    public let properties: [String: GeminiSchemaProperty]?
    public let required: [String]?

    public init(type: String, properties: [String: GeminiSchemaProperty]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// Schema property definition
public struct GeminiSchemaProperty: Codable, Sendable, Equatable {
    public let type: String
    public let description: String?
    public let format: String?
    public let items: GeminiSchemaItems?
    public let `enum`: [String]?

    public init(type: String, description: String? = nil, format: String? = nil, items: GeminiSchemaItems? = nil, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.format = format
        self.items = items
        self.enum = enumValues
    }
}

/// Schema items for array types
public struct GeminiSchemaItems: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String) {
        self.type = type
    }
}

/// Tool configuration for Gemini API
public struct GeminiTool: Codable, Sendable, Equatable {
    public let functionDeclarations: [GeminiFunctionDeclaration]

    public init(functionDeclarations: [GeminiFunctionDeclaration]) {
        self.functionDeclarations = functionDeclarations
    }
}

/// Tool configuration settings
public struct GeminiToolConfig: Codable, Sendable, Equatable {
    public let functionCallingConfig: GeminiFunctionCallingConfig

    public init(functionCallingConfig: GeminiFunctionCallingConfig) {
        self.functionCallingConfig = functionCallingConfig
    }
}

/// Function calling mode configuration
public struct GeminiFunctionCallingConfig: Codable, Sendable, Equatable {
    public let mode: Mode
    public let allowedFunctionNames: [String]?

    public enum Mode: String, Codable, Sendable {
        case auto = "AUTO"
        case any = "ANY"
        case none = "NONE"
    }

    public init(mode: Mode, allowedFunctionNames: [String]? = nil) {
        self.mode = mode
        self.allowedFunctionNames = allowedFunctionNames
    }
}
