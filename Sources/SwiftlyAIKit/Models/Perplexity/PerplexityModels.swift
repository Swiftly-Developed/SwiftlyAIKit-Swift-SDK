import Foundation

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
