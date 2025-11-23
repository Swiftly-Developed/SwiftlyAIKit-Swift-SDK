import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for PerplexityOptions helper structure
@Suite("PerplexityOptions Tests")
struct PerplexityOptionsTests {
    // MARK: - Initialization Tests

    @Test("Initialize with all options")
    func testInitializeWithAllOptions() {
        let responseFormat = ResponseFormat(
            type: "json_schema",
            jsonSchema: JSONSchema(
                name: "test_schema",
                schema: ["type": AnyCodable("object")]
            )
        )

        let options = PerplexityOptions(
            searchDomainFilter: ["arxiv.org", "github.com"],
            searchRecencyFilter: .week,
            returnCitations: true,
            returnImages: true,
            responseFormat: responseFormat
        )

        #expect(options.searchDomainFilter == ["arxiv.org", "github.com"])
        #expect(options.searchRecencyFilter == .week)
        #expect(options.returnCitations == true)
        #expect(options.returnImages == true)
        #expect(options.responseFormat != nil)
    }

    @Test("Initialize with no options")
    func testInitializeWithNoOptions() {
        let options = PerplexityOptions()

        #expect(options.searchDomainFilter == nil)
        #expect(options.searchRecencyFilter == nil)
        #expect(options.returnCitations == nil)
        #expect(options.returnImages == nil)
        #expect(options.responseFormat == nil)
    }

    @Test("Initialize with only search domain filter")
    func testInitializeWithOnlyDomainFilter() {
        let options = PerplexityOptions(
            searchDomainFilter: ["example.com"]
        )

        #expect(options.searchDomainFilter == ["example.com"])
        #expect(options.searchRecencyFilter == nil)
        #expect(options.returnCitations == nil)
    }

    @Test("Initialize with only recency filter")
    func testInitializeWithOnlyRecencyFilter() {
        let options = PerplexityOptions(
            searchRecencyFilter: .day
        )

        #expect(options.searchDomainFilter == nil)
        #expect(options.searchRecencyFilter == .day)
        #expect(options.returnCitations == nil)
    }

    // MARK: - Conversion Tests

    @Test("Convert all options to provider options")
    func testConvertAllOptions() {
        let options = PerplexityOptions(
            searchDomainFilter: ["arxiv.org"],
            searchRecencyFilter: .month,
            returnCitations: true,
            returnImages: false
        )

        let providerOptions = options.toProviderOptions()
        #expect(providerOptions != nil)
        #expect(providerOptions?.count == 4)

        // Verify domain filter
        if let domains = providerOptions?["search_domain_filter"]?.value as? [String] {
            #expect(domains == ["arxiv.org"])
        } else {
            Issue.record("search_domain_filter not found or wrong type")
        }

        // Verify recency filter
        if let recency = providerOptions?["search_recency_filter"]?.value as? String {
            #expect(recency == "month")
        } else {
            Issue.record("search_recency_filter not found or wrong type")
        }

        // Verify citations
        if let citations = providerOptions?["return_citations"]?.value as? Bool {
            #expect(citations == true)
        } else {
            Issue.record("return_citations not found or wrong type")
        }

        // Verify images
        if let images = providerOptions?["return_images"]?.value as? Bool {
            #expect(images == false)
        } else {
            Issue.record("return_images not found or wrong type")
        }
    }

    @Test("Convert empty options returns nil")
    func testConvertEmptyOptions() {
        let options = PerplexityOptions()
        let providerOptions = options.toProviderOptions()

        #expect(providerOptions == nil)
    }

    @Test("Convert only domain filter")
    func testConvertOnlyDomainFilter() {
        let options = PerplexityOptions(
            searchDomainFilter: ["github.com", "arxiv.org"]
        )

        let providerOptions = options.toProviderOptions()
        #expect(providerOptions != nil)
        #expect(providerOptions?.count == 1)

        if let domains = providerOptions?["search_domain_filter"]?.value as? [String] {
            #expect(domains == ["github.com", "arxiv.org"])
        } else {
            Issue.record("search_domain_filter not found")
        }
    }

    @Test("Convert response format with JSON schema")
    func testConvertResponseFormat() {
        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "name": ["type": "string"],
                "age": ["type": "integer"]
            ])
        ]

        let responseFormat = ResponseFormat(
            type: "json_schema",
            jsonSchema: JSONSchema(name: "person", schema: schema)
        )

        let options = PerplexityOptions(responseFormat: responseFormat)
        let providerOptions = options.toProviderOptions()

        #expect(providerOptions != nil)
        #expect(providerOptions?["response_format"] != nil)

        // Verify it's a dictionary
        if let formatDict = providerOptions?["response_format"]?.value as? [String: Any] {
            #expect(formatDict["type"] as? String == "json_schema")
            #expect(formatDict["json_schema"] != nil)
        } else {
            Issue.record("response_format not found or wrong type")
        }
    }

    // MARK: - Convenience Initializer Tests

    @Test("webSearch convenience initializer with all parameters")
    func testWebSearchConvenience() {
        let options = PerplexityOptions.webSearch(
            domains: ["arxiv.org", "github.com"],
            recency: .week,
            includeCitations: true,
            includeImages: true
        )

        #expect(options.searchDomainFilter == ["arxiv.org", "github.com"])
        #expect(options.searchRecencyFilter == .week)
        #expect(options.returnCitations == true)
        #expect(options.returnImages == true)
        #expect(options.responseFormat == nil)
    }

    @Test("webSearch convenience initializer with defaults")
    func testWebSearchConvenienceDefaults() {
        let options = PerplexityOptions.webSearch()

        #expect(options.searchDomainFilter == nil)
        #expect(options.searchRecencyFilter == nil)
        #expect(options.returnCitations == true) // default
        #expect(options.returnImages == false) // default
    }

    @Test("webSearch convenience initializer with only domains")
    func testWebSearchConvenienceOnlyDomains() {
        let options = PerplexityOptions.webSearch(
            domains: ["example.com"]
        )

        #expect(options.searchDomainFilter == ["example.com"])
        #expect(options.returnCitations == true) // default
    }

    @Test("webSearch convenience initializer with only recency")
    func testWebSearchConvenienceOnlyRecency() {
        let options = PerplexityOptions.webSearch(
            recency: .day
        )

        #expect(options.searchRecencyFilter == .day)
        #expect(options.returnCitations == true) // default
    }

    @Test("jsonSchema convenience initializer")
    func testJsonSchemaConvenience() {
        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable(["name": ["type": "string"]])
        ]

        let options = PerplexityOptions.jsonSchema(
            name: "test_schema",
            schema: schema,
            includeCitations: true
        )

        #expect(options.responseFormat != nil)
        #expect(options.responseFormat?.type == "json_schema")
        #expect(options.responseFormat?.jsonSchema?.name == "test_schema")
        #expect(options.returnCitations == true)
        #expect(options.searchDomainFilter == nil)
    }

    @Test("jsonSchema convenience initializer with default citations")
    func testJsonSchemaConvenienceDefaultCitations() {
        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object")
        ]

        let options = PerplexityOptions.jsonSchema(
            name: "simple_schema",
            schema: schema
        )

        #expect(options.responseFormat != nil)
        #expect(options.returnCitations == false) // default
    }

    // MARK: - RecencyFilter Tests

    @Test("All RecencyFilter cases have correct raw values")
    func testRecencyFilterRawValues() {
        #expect(RecencyFilter.day.rawValue == "day")
        #expect(RecencyFilter.week.rawValue == "week")
        #expect(RecencyFilter.month.rawValue == "month")
        #expect(RecencyFilter.year.rawValue == "year")
    }

    @Test("RecencyFilter is Sendable")
    func testRecencyFilterSendable() async {
        let filter = RecencyFilter.week

        await Task {
            _ = filter.rawValue
        }.value
    }

    // MARK: - Integration with AIRequest Tests

    @Test("PerplexityOptions integrates with AIRequest")
    func testIntegrationWithAIRequest() {
        let options = PerplexityOptions(
            searchDomainFilter: ["arxiv.org"],
            returnCitations: true
        )

        let request = AIRequest(
            model: "sonar-pro",
            messages: [
                AIMessage(role: .user, content: [.text("What's new in AI?")])
            ],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.model == "sonar-pro")
        #expect(request.providerOptions != nil)
        #expect(request.providerOptions?.count == 2)
    }

    @Test("Empty PerplexityOptions with AIRequest")
    func testEmptyOptionsWithAIRequest() {
        let options = PerplexityOptions()

        let request = AIRequest(
            model: "sonar",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions == nil)
    }

    // MARK: - Real-World Scenarios

    @Test("Scenario: Academic research query with domain filtering")
    func testAcademicResearchScenario() {
        let options = PerplexityOptions.webSearch(
            domains: ["arxiv.org", "scholar.google.com", "pubmed.ncbi.nlm.nih.gov"],
            recency: .year,
            includeCitations: true
        )

        let providerOptions = options.toProviderOptions()
        #expect(providerOptions != nil)

        if let domains = providerOptions?["search_domain_filter"]?.value as? [String] {
            #expect(domains.count == 3)
            #expect(domains.contains("arxiv.org"))
        } else {
            Issue.record("Domain filter not properly set")
        }
    }

    @Test("Scenario: Recent news query")
    func testRecentNewsScenario() {
        let options = PerplexityOptions.webSearch(
            domains: ["techcrunch.com", "theverge.com", "wired.com"],
            recency: .day,
            includeCitations: true,
            includeImages: true
        )

        #expect(options.searchRecencyFilter == .day)
        #expect(options.returnImages == true)

        let providerOptions = options.toProviderOptions()
        #expect(providerOptions?.count == 4)
    }

    @Test("Scenario: Structured data extraction with JSON schema")
    func testStructuredDataScenario() {
        let personSchema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "name": ["type": "string"],
                "email": ["type": "string"],
                "age": ["type": "integer"]
            ]),
            "required": AnyCodable(["name", "email"])
        ]

        let options = PerplexityOptions.jsonSchema(
            name: "person_info",
            schema: personSchema
        )

        let request = AIRequest(
            model: "sonar-reasoning",
            messages: [
                AIMessage(role: .user, content: [.text("Extract person info from this text: John Doe, john@example.com, 30 years old")])
            ],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions?["response_format"] != nil)
    }

    @Test("Scenario: Multi-domain search with citation tracking")
    func testMultiDomainSearchScenario() {
        let techDomains = [
            "github.com",
            "stackoverflow.com",
            "dev.to",
            "medium.com"
        ]

        let options = PerplexityOptions(
            searchDomainFilter: techDomains,
            searchRecencyFilter: .month,
            returnCitations: true
        )

        let providerOptions = options.toProviderOptions()

        if let domains = providerOptions?["search_domain_filter"]?.value as? [String] {
            #expect(domains.count == 4)
        } else {
            Issue.record("Multi-domain filter not working")
        }

        if let recency = providerOptions?["search_recency_filter"]?.value as? String {
            #expect(recency == "month")
        } else {
            Issue.record("Recency filter not working")
        }
    }

    @Test("Scenario: Simple query without special options")
    func testSimpleQueryScenario() {
        // Most basic use case - no special options
        let options = PerplexityOptions()

        let request = AIRequest(
            model: "sonar",
            messages: [
                AIMessage(role: .user, content: [.text("What is Swift?")])
            ],
            providerOptions: options.toProviderOptions()
        )

        // Should work fine with nil providerOptions
        #expect(request.providerOptions == nil)
        #expect(request.model == "sonar")
    }

    // MARK: - Edge Cases

    @Test("Empty domain filter array")
    func testEmptyDomainArray() {
        let options = PerplexityOptions(
            searchDomainFilter: []
        )

        let providerOptions = options.toProviderOptions()
        #expect(providerOptions != nil)

        if let domains = providerOptions?["search_domain_filter"]?.value as? [String] {
            #expect(domains.isEmpty)
        } else {
            Issue.record("Empty array should still be included")
        }
    }

    @Test("Single domain filter")
    func testSingleDomain() {
        let options = PerplexityOptions(
            searchDomainFilter: ["example.com"]
        )

        let providerOptions = options.toProviderOptions()

        if let domains = providerOptions?["search_domain_filter"]?.value as? [String] {
            #expect(domains.count == 1)
            #expect(domains.first == "example.com")
        } else {
            Issue.record("Single domain not working")
        }
    }

    @Test("Boolean flags set to false are included")
    func testBooleanFalseIncluded() {
        let options = PerplexityOptions(
            returnCitations: false,
            returnImages: false
        )

        let providerOptions = options.toProviderOptions()
        #expect(providerOptions != nil)
        #expect(providerOptions?.count == 2)

        // False values should be included
        if let citations = providerOptions?["return_citations"]?.value as? Bool {
            #expect(citations == false)
        } else {
            Issue.record("False boolean not included")
        }
    }

    @Test("ResponseFormat without JSON schema")
    func testResponseFormatWithoutSchema() {
        let responseFormat = ResponseFormat(type: "text")

        let options = PerplexityOptions(
            responseFormat: responseFormat
        )

        let providerOptions = options.toProviderOptions()
        #expect(providerOptions != nil)

        if let formatDict = providerOptions?["response_format"]?.value as? [String: Any] {
            #expect(formatDict["type"] as? String == "text")
            #expect(formatDict["json_schema"] == nil)
        } else {
            Issue.record("Response format without schema not working")
        }
    }

    @Test("PerplexityOptions is Sendable")
    func testPerplexityOptionsIsSendable() async {
        let options = PerplexityOptions(
            searchDomainFilter: ["example.com"],
            returnCitations: true
        )

        await Task {
            let providerOptions = options.toProviderOptions()
            #expect(providerOptions != nil)
        }.value
    }
}
