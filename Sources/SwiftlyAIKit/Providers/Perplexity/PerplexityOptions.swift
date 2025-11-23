import Foundation

/// Type-safe helper for Perplexity-specific provider options
///
/// Use this structure to create provider-specific options for Perplexity AI requests.
/// The options are converted to `[String: AnyCodable]` format for use in `AIRequest.providerOptions`.
///
/// Example usage:
/// ```swift
/// let options = PerplexityOptions(
///     searchDomainFilter: ["arxiv.org", "github.com"],
///     searchRecencyFilter: .week,
///     returnCitations: true
/// )
///
/// let request = AIRequest(
///     model: "sonar-pro",
///     messages: [AIMessage(role: .user, content: "Latest AI research?")],
///     providerOptions: options.toProviderOptions()
/// )
/// ```
public struct PerplexityOptions: Sendable {
    /// Filter search results to specific domains
    public let searchDomainFilter: [String]?

    /// Filter search results by recency
    public let searchRecencyFilter: RecencyFilter?

    /// Return citations with the response
    public let returnCitations: Bool?

    /// Return images with the response
    public let returnImages: Bool?

    /// Structured output format with optional JSON schema
    public let responseFormat: ResponseFormat?

    // MARK: - Initialization

    /// Initialize Perplexity options
    ///
    /// - Parameters:
    ///   - searchDomainFilter: Array of domains to filter search results (e.g., ["arxiv.org", "github.com"])
    ///   - searchRecencyFilter: Time-based filter for search results
    ///   - returnCitations: Whether to return citations with the response
    ///   - returnImages: Whether to return images with the response
    ///   - responseFormat: Structured output format configuration
    public init(
        searchDomainFilter: [String]? = nil,
        searchRecencyFilter: RecencyFilter? = nil,
        returnCitations: Bool? = nil,
        returnImages: Bool? = nil,
        responseFormat: ResponseFormat? = nil
    ) {
        self.searchDomainFilter = searchDomainFilter
        self.searchRecencyFilter = searchRecencyFilter
        self.returnCitations = returnCitations
        self.returnImages = returnImages
        self.responseFormat = responseFormat
    }

    // MARK: - Conversion

    /// Convert options to provider options format
    ///
    /// Transforms the type-safe structure into a `[String: AnyCodable]` dictionary
    /// suitable for use in `AIRequest.providerOptions`.
    ///
    /// - Returns: Dictionary with Perplexity-specific options, or nil if all options are nil
    public func toProviderOptions() -> [String: AnyCodable]? {
        var options: [String: AnyCodable] = [:]

        if let searchDomainFilter = searchDomainFilter {
            options["search_domain_filter"] = AnyCodable(searchDomainFilter)
        }

        if let searchRecencyFilter = searchRecencyFilter {
            options["search_recency_filter"] = AnyCodable(searchRecencyFilter.rawValue)
        }

        if let returnCitations = returnCitations {
            options["return_citations"] = AnyCodable(returnCitations)
        }

        if let returnImages = returnImages {
            options["return_images"] = AnyCodable(returnImages)
        }

        if let responseFormat = responseFormat {
            // ResponseFormat is already Codable, convert to dictionary via JSON
            if let data = try? JSONEncoder().encode(responseFormat),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                options["response_format"] = AnyCodable(dict)
            }
        }

        return options.isEmpty ? nil : options
    }

    // MARK: - Convenience Initializers

    /// Create options with web search capabilities
    ///
    /// - Parameters:
    ///   - domains: Specific domains to search (e.g., ["arxiv.org"])
    ///   - recency: How recent the results should be
    ///   - includeCitations: Whether to include citations (default: true)
    ///   - includeImages: Whether to include images (default: false)
    /// - Returns: Configured PerplexityOptions
    public static func webSearch(
        domains: [String]? = nil,
        recency: RecencyFilter? = nil,
        includeCitations: Bool = true,
        includeImages: Bool = false
    ) -> PerplexityOptions {
        return PerplexityOptions(
            searchDomainFilter: domains,
            searchRecencyFilter: recency,
            returnCitations: includeCitations,
            returnImages: includeImages
        )
    }

    /// Create options with JSON schema structured output
    ///
    /// - Parameters:
    ///   - schemaName: Name of the JSON schema
    ///   - schema: JSON Schema definition as AnyCodable dictionary
    ///   - includeCitations: Whether to include citations (default: false)
    /// - Returns: Configured PerplexityOptions
    public static func jsonSchema(
        name schemaName: String,
        schema: [String: AnyCodable],
        includeCitations: Bool = false
    ) -> PerplexityOptions {
        let responseFormat = ResponseFormat(
            type: "json_schema",
            jsonSchema: JSONSchema(name: schemaName, schema: schema)
        )

        return PerplexityOptions(
            returnCitations: includeCitations,
            responseFormat: responseFormat
        )
    }
}
