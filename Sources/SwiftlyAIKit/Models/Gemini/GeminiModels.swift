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
