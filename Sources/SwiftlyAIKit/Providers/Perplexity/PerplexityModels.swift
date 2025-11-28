import Foundation

/// Perplexity AI API Models
///
/// Provider-specific types for Perplexity's Chat Completions API with web search.
///
/// ## See Also
/// - ``PerplexityProvider``
/// - <doc:PerplexityGuide>

// MARK: - Message and Content

/// Message role for Perplexity API
public enum PerplexityRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

/// Message for Perplexity API
public struct PerplexityMessage: Codable, Sendable, Equatable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Search Options

/// Recency filter for search results
public enum RecencyFilter: String, Codable, Sendable {
    case day
    case week
    case month
    case year
}

// MARK: - Response Format (JSON Schema)

/// Response format for structured outputs
public struct ResponseFormat: Codable, Sendable, Equatable {
    public let type: String
    public let jsonSchema: JSONSchema?

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }

    public init(type: String, jsonSchema: JSONSchema? = nil) {
        self.type = type
        self.jsonSchema = jsonSchema
    }
}

/// JSON Schema for structured outputs
public struct JSONSchema: Codable, Sendable, Equatable {
    public let name: String
    public let schema: [String: AnyCodable]

    public init(name: String, schema: [String: AnyCodable]) {
        self.name = name
        self.schema = schema
    }
}

// MARK: - Request

/// Perplexity API request
public struct PerplexityRequest: Codable, Sendable {
    public let model: String
    public let messages: [PerplexityMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let stream: Bool?
    public let searchDomainFilter: [String]?
    public let searchRecencyFilter: String?
    public let returnCitations: Bool?
    public let returnImages: Bool?
    public let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stream
        case searchDomainFilter = "search_domain_filter"
        case searchRecencyFilter = "search_recency_filter"
        case returnCitations = "return_citations"
        case returnImages = "return_images"
        case responseFormat = "response_format"
    }

    public init(
        model: String,
        messages: [PerplexityMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stream: Bool? = nil,
        searchDomainFilter: [String]? = nil,
        searchRecencyFilter: String? = nil,
        returnCitations: Bool? = nil,
        returnImages: Bool? = nil,
        responseFormat: ResponseFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stream = stream
        self.searchDomainFilter = searchDomainFilter
        self.searchRecencyFilter = searchRecencyFilter
        self.returnCitations = returnCitations
        self.returnImages = returnImages
        self.responseFormat = responseFormat
    }
}

// MARK: - Response

/// Usage metadata for token counts
public struct Usage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }

    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

/// Message in response
public struct Message: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Delta for streaming responses
public struct Delta: Codable, Sendable {
    public let role: String?
    public let content: String?

    public init(role: String? = nil, content: String? = nil) {
        self.role = role
        self.content = content
    }
}

/// Choice in response
public struct Choice: Codable, Sendable {
    public let index: Int
    public let finishReason: String?
    public let message: Message
    public let delta: Delta?

    enum CodingKeys: String, CodingKey {
        case index
        case finishReason = "finish_reason"
        case message
        case delta
    }

    public init(index: Int, finishReason: String? = nil, message: Message, delta: Delta? = nil) {
        self.index = index
        self.finishReason = finishReason
        self.message = message
        self.delta = delta
    }
}

/// Perplexity API response
public struct PerplexityResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let created: Int
    public let usage: Usage
    public let citations: [String]?
    public let object: String
    public let choices: [Choice]

    public init(
        id: String,
        model: String,
        created: Int,
        usage: Usage,
        citations: [String]? = nil,
        object: String,
        choices: [Choice]
    ) {
        self.id = id
        self.model = model
        self.created = created
        self.usage = usage
        self.citations = citations
        self.object = object
        self.choices = choices
    }
}

// MARK: - Search Results

/// Search result metadata from Perplexity
public struct SearchResult: Codable, Sendable {
    public let title: String
    public let url: String
    public let publishedDate: String?
    public let author: String?
    public let score: Double?

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case publishedDate = "published_date"
        case author
        case score
    }

    public init(
        title: String,
        url: String,
        publishedDate: String? = nil,
        author: String? = nil,
        score: Double? = nil
    ) {
        self.title = title
        self.url = url
        self.publishedDate = publishedDate
        self.author = author
        self.score = score
    }
}

// MARK: - Streaming

/// Stream choice for Perplexity streaming responses
public struct StreamChoice: Codable, Sendable {
    public let index: Int
    public let delta: Delta
    public let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case delta
        case finishReason = "finish_reason"
    }

    public init(index: Int, delta: Delta, finishReason: String? = nil) {
        self.index = index
        self.delta = delta
        self.finishReason = finishReason
    }
}

/// Stream chunk for Perplexity streaming responses
public struct PerplexityStreamChunk: Codable, Sendable {
    public let id: String
    public let model: String
    public let created: Int
    public let object: String
    public let choices: [StreamChoice]

    public init(
        id: String,
        model: String,
        created: Int,
        object: String,
        choices: [StreamChoice]
    ) {
        self.id = id
        self.model = model
        self.created = created
        self.object = object
        self.choices = choices
    }
}

// MARK: - Error Response

/// Perplexity API error detail
public struct PerplexityError: Codable, Sendable {
    public let message: String
    public let type: String?
    public let code: String?

    public init(message: String, type: String? = nil, code: String? = nil) {
        self.message = message
        self.type = type
        self.code = code
    }
}

/// Perplexity API error response
public struct PerplexityErrorResponse: Codable, Sendable {
    public let error: PerplexityError

    public init(error: PerplexityError) {
        self.error = error
    }
}
