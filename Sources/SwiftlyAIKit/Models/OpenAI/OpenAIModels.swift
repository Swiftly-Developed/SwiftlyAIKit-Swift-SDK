import Foundation

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

// MARK: - Tool Call (Forward Declaration)

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
