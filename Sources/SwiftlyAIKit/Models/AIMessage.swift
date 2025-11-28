import Foundation

/// Represents a message role in the conversation
public enum AIMessageRole: String, Codable, Sendable {
    /// User message
    case user

    /// Assistant/AI response
    case assistant

    /// System message (instructions)
    case system
}

/// Represents a content part in a message
public enum AIMessageContent: Codable, Sendable, Equatable {
    /// Plain text content
    case text(String)

    /// Image content (base64 or URL)
    case image(source: ImageSource, mediaType: String?)

    /// Document content (PDF, etc.)
    case document(data: Data, mediaType: String, filename: String?)

    /// Tool/function call
    case toolCall(AIToolCall)

    /// Tool/function result
    case toolResult(id: String, result: String)

    /// Custom/provider-specific content
    case custom(data: [String: AnyCodable])

    public enum ImageSource: Codable, Sendable, Equatable {
        case base64(String)
        case url(String)
    }
}

/// Helper for encoding arbitrary JSON
public struct AnyCodable: Codable, @unchecked Sendable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.value = arrayValue.map(\.value)
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.value = dictValue.mapValues(\.value)
        } else {
            self.value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unable to encode value"
                )
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple equality check - can be improved
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
}

/// Represents a message in the conversation
///
/// Messages are the primary way to communicate with AI models. Each message
/// has a role (user, assistant, or system) and can contain multiple content parts
/// (text, images, documents, tool calls).
///
/// ## Overview
///
/// `AIMessage` supports multimodal content:
/// - Text messages
/// - Images (URLs or base64)
/// - Documents (PDFs)
/// - Tool calls and results
///
/// ## Simple Text Message
///
/// ```swift
/// let message = AIMessage(role: .user, text: "Hello!")
/// ```
///
/// ## Multimodal Message
///
/// ```swift
/// let message = AIMessage(role: .user, content: [
///     .text("What's in this image?"),
///     .image(url: "https://example.com/photo.jpg")
/// ])
/// ```
///
/// ## Convenience Constructors
///
/// ```swift
/// // User message
/// let user = AIMessage.user("Your question")
///
/// // Assistant message
/// let assistant = AIMessage.assistant("AI response")
///
/// // System message
/// let system = AIMessage.system("You are a helpful assistant")
/// ```
///
/// ## Topics
///
/// ### Creating Messages
/// - ``init(role:text:metadata:)``
/// - ``init(role:content:metadata:)``
///
/// ### Message Properties
/// - ``role``
/// - ``content``
/// - ``metadata``
/// - ``textContent``
///
/// ### Related Types
/// - ``AIMessageRole``
/// - ``AIMessageContent``
/// - ``AIRequest``
/// - ``AIResponse``
///
/// ## See Also
/// - ``AIRequest``
/// - ``AIMessageContent``
/// - <doc:VisionAndImageAnalysis>
public struct AIMessage: Codable, Sendable, Equatable {
    /// The role of the message sender
    public let role: AIMessageRole

    /// The content of the message (can be multiple parts)
    public let content: [AIMessageContent]

    /// Optional metadata
    public let metadata: [String: String]?

    /// Initialize a message with text content
    ///
    /// - Parameters:
    ///   - role: The role of the message sender
    ///   - text: The text content
    ///   - metadata: Optional metadata
    public init(role: AIMessageRole, text: String, metadata: [String: String]? = nil) {
        self.role = role
        self.content = [.text(text)]
        self.metadata = metadata
    }

    /// Initialize a message with multiple content parts
    ///
    /// - Parameters:
    ///   - role: The role of the message sender
    ///   - content: Array of content parts
    ///   - metadata: Optional metadata
    public init(role: AIMessageRole, content: [AIMessageContent], metadata: [String: String]? = nil) {
        self.role = role
        self.content = content
        self.metadata = metadata
    }

    /// Get all text content concatenated
    public var textContent: String {
        content.compactMap {
            if case .text(let text) = $0 {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }
}
