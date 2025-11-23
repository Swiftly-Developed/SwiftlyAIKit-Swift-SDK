# Perplexity AI API Implementation Plan (v0.4.0)

## Executive Summary

This document outlines the implementation plan for adding **Perplexity AI API** support to SwiftlyAIKit. Perplexity is unique among AI providers in that it performs **real-time web searches** and provides **cited, factual responses** with up-to-date information. This implementation will add approximately **~1,200 lines** of code (models + provider + tests).

### Key Differentiators
- **Real-time web search**: Unlike GPT/Claude/Gemini which use static training data, Perplexity searches the web in real-time
- **Citations**: Every response includes numbered citations with source URLs
- **Search results**: Detailed metadata (title, URL, date, snippet) for each source
- **Domain filtering**: Ability to restrict searches to specific domains
- **Recency filtering**: Filter results by time period (day, week, month, year)
- **Structured outputs**: JSON schema support for structured responses

## Research Sources

This implementation plan is based on official Perplexity AI documentation and research:

### Official Documentation
- [Perplexity API Docs](https://docs.perplexity.ai/)
- [Quickstart Guide](https://docs.perplexity.ai/getting-started/quickstart)
- [API Platform](https://www.perplexity.ai/api-platform)
- [Pricing Information](https://docs.perplexity.ai/getting-started/pricing)
- [Rate Limits](https://docs.perplexity.ai/docs/rate-limits)

### Model Information
- [Sonar Pro Model](https://docs.perplexity.ai/getting-started/models/models/sonar-pro)
- [Meet New Sonar Blog](https://www.perplexity.ai/hub/blog/meet-new-sonar)
- [Sonar Pro API Announcement](https://www.perplexity.ai/hub/blog/introducing-the-sonar-pro-api)
- [All Perplexity Models 2025](https://www.datastudios.org/post/all-perplexity-models-available-in-2025-complete-list-with-sonar-family-gpt-5-claude-gemini-and)

### Additional Resources
- [Perplexity API Guide (Zuplo)](https://zuplo.com/learning-center/perplexity-api)
- [Context Window Information](https://www.datastudios.org/post/perplexity-ai-context-window-token-limits-memory-policy-and-2025-rules)
- [Pricing Details (PricePerToken)](https://pricepertoken.com/pricing-page/provider/perplexity)

## API Overview

### Base URL
```
https://api.perplexity.ai
```

### Authentication
Bearer token via `Authorization` header:
```
Authorization: Bearer YOUR_API_KEY
```

### Primary Endpoints
1. **Chat Completions**: `/chat/completions` (OpenAI-compatible)
2. **Search**: `/search` (standalone search functionality)

### Key Features
- OpenAI-compatible chat completions format
- Real-time web search integration
- Citation tracking with source URLs
- Domain and recency filtering
- Streaming support
- JSON schema for structured outputs

## Available Models

### Sonar (Standard)
- **Model ID**: `sonar`
- **Base Model**: Llama 3.3 70B
- **Context Window**: 128K tokens
- **Speed**: 10x faster than Gemini 2.0 Flash (via Cerebras)
- **Use Cases**: Fast, cost-effective search and Q&A
- **Pricing**:
  - Input: $0.20 per 1M tokens
  - Output: $0.20 per 1M tokens
  - Searches: $5 per 1K searches
- **Rate Limit**: 20 requests/min

### Sonar Pro (Advanced)
- **Model ID**: `sonar-pro`
- **Context Window**: 200K tokens
- **Features**:
  - 2x more search results than standard Sonar
  - Enhanced content understanding
  - Better for complex, multi-step queries
  - Best factuality (F-score: 0.858 on SimpleQA)
- **Pricing**:
  - Input: $3 per 1M tokens
  - Output: $15 per 1M tokens
  - Searches: $5 per 1K searches
- **Rate Limit**: 20 requests/min

### Sonar Reasoning (Future)
- **Model ID**: `sonar-reasoning` (mentioned in research, may not be API-ready yet)
- **Context Window**: 128K tokens
- **Features**: Chain-of-Thought capabilities for logical reasoning

## Request Format

### Basic Chat Completion

```json
{
  "model": "sonar-pro",
  "messages": [
    {
      "role": "system",
      "content": "Be precise and concise."
    },
    {
      "role": "user",
      "content": "What are the latest developments in quantum computing?"
    }
  ],
  "max_tokens": 1024,
  "temperature": 0.7,
  "top_p": 0.9,
  "stream": false
}
```

### With Search Options

```json
{
  "model": "sonar-pro",
  "messages": [
    {
      "role": "user",
      "content": "Latest climate change research"
    }
  ],
  "search_domain_filter": ["nature.com", "science.org"],
  "search_recency_filter": "month",
  "return_citations": true,
  "return_images": false
}
```

### Structured Output (JSON Schema)

```json
{
  "model": "sonar-pro",
  "messages": [
    {
      "role": "user",
      "content": "Find top 3 AI companies and their market cap"
    }
  ],
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "ai_companies",
      "schema": {
        "type": "object",
        "properties": {
          "companies": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "name": {"type": "string"},
                "market_cap": {"type": "string"}
              }
            }
          }
        }
      }
    }
  }
}
```

## Response Format

### Standard Response

```json
{
  "id": "abc123",
  "model": "sonar-pro",
  "created": 1701388800,
  "usage": {
    "prompt_tokens": 50,
    "completion_tokens": 200,
    "total_tokens": 250
  },
  "citations": [
    "https://nature.com/article1",
    "https://science.org/paper2"
  ],
  "object": "chat.completion",
  "choices": [
    {
      "index": 0,
      "finish_reason": "stop",
      "message": {
        "role": "assistant",
        "content": "Recent developments in quantum computing include [1] breakthrough in error correction and [2] new qubit stability techniques..."
      },
      "delta": {
        "role": "assistant",
        "content": ""
      }
    }
  ]
}
```

### With Search Results

```json
{
  "id": "abc123",
  "model": "sonar-pro",
  "choices": [...],
  "citations": [
    "https://nature.com/quantum-computing-2025",
    "https://science.org/qubit-stability"
  ],
  "search_results": [
    {
      "title": "Quantum Computing Breakthrough 2025",
      "url": "https://nature.com/quantum-computing-2025",
      "published_date": "2025-01-15",
      "last_updated": "2025-01-16",
      "snippet": "Scientists achieve 99.9% qubit stability..."
    },
    {
      "title": "New Error Correction Method",
      "url": "https://science.org/qubit-stability",
      "published_date": "2025-01-10",
      "snippet": "Novel approach reduces quantum errors by 50%..."
    }
  ]
}
```

### Streaming Response

```
data: {"id":"abc","choices":[{"delta":{"role":"assistant","content":"Recent"}}]}

data: {"id":"abc","choices":[{"delta":{"content":" developments"}}]}

data: {"id":"abc","choices":[{"delta":{"content":" include"}}]}

data: [DONE]
```

## Implementation Structure

### Phase 1: Models (~600 lines)
**File**: `Sources/SwiftlyAIKit/Models/Perplexity/PerplexityModels.swift`

#### Core Types
```swift
// Message and content
public struct PerplexityMessage: Codable, Sendable, Equatable
public enum PerplexityRole: String, Codable, Sendable

// Search options
public struct PerplexitySearchOptions: Codable, Sendable, Equatable {
    public let searchDomainFilter: [String]?
    public let searchRecencyFilter: RecencyFilter?
    public let returnCitations: Bool?
    public let returnImages: Bool?

    public enum RecencyFilter: String, Codable, Sendable {
        case day, week, month, year
    }
}

// Request
public struct PerplexityRequest: Codable, Sendable {
    public let model: String
    public let messages: [PerplexityMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let stream: Bool?
    public let searchDomainFilter: [String]?
    public let searchRecencyFilter: String?
    public let returnCitations: Bool?
    public let returnImages: Bool?
    public let responseFormat: ResponseFormat?
}

// Response format (JSON schema)
public struct ResponseFormat: Codable, Sendable, Equatable {
    public let type: String
    public let jsonSchema: JSONSchema?
}

public struct JSONSchema: Codable, Sendable, Equatable {
    public let name: String
    public let schema: [String: AnyCodable]
}

// Response
public struct PerplexityResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let created: Int
    public let usage: Usage
    public let citations: [String]?
    public let searchResults: [SearchResult]?
    public let object: String
    public let choices: [Choice]
}

// Choice and message
public struct Choice: Codable, Sendable {
    public let index: Int
    public let finishReason: String?
    public let message: Message
    public let delta: Delta?
}

public struct Message: Codable, Sendable {
    public let role: String
    public let content: String
}

// Usage
public struct Usage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
}

// Search result
public struct SearchResult: Codable, Sendable, Equatable {
    public let title: String
    public let url: String
    public let publishedDate: String?
    public let lastUpdated: String?
    public let snippet: String
}

// Streaming
public struct PerplexityStreamChunk: Codable, Sendable {
    public let id: String
    public let choices: [StreamChoice]
}

public struct StreamChoice: Codable, Sendable {
    public let index: Int
    public let delta: Delta
    public let finishReason: String?
}

public struct Delta: Codable, Sendable {
    public let role: String?
    public let content: String?
}

// Error response
public struct PerplexityErrorResponse: Codable, Sendable {
    public let error: PerplexityError
}

public struct PerplexityError: Codable, Sendable {
    public let message: String
    public let type: String?
    public let code: String?
}
```

### Phase 2: Provider (~400 lines)
**File**: `Sources/SwiftlyAIKit/Providers/PerplexityProvider.swift`

```swift
public struct PerplexityProvider: ProviderProtocol {
    public let providerType: ProviderType = .perplexity

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    // Initializers
    public init(
        baseURL: String = "https://api.perplexity.ai",
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    )

    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "https://api.perplexity.ai",
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    )

    // ProviderProtocol implementation
    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse
    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error>
    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int?

    // Private helpers
    private func buildHeaders(apiKey: String, stream: Bool) -> [(String, String)]
    private func mapToPerplexityRequest(_ request: AIRequest) throws -> PerplexityRequest
    private func mapToAIResponse(_ response: PerplexityResponse) -> AIResponse
    private func mapFinishReason(_ reason: String) -> AIStopReason
}
```

**Key Implementation Notes:**
- Map `AIRequest.searchOptions` (new field) to Perplexity search parameters
- Store `citations` and `searchResults` in `AIResponse.metadata`
- Handle streaming with SSE format (same as OpenAI/Gemini)
- Map temperature, topP, maxTokens to Perplexity format

### Phase 3: Model Registration (~50 lines)
**File**: `Sources/SwiftlyAIKit/Models/ModelProvider.swift`

```swift
public enum ModelProvider: String, Codable, Sendable, CaseIterable {
    // ... existing models ...

    // MARK: - Perplexity Sonar Models

    /// Sonar - Fast, cost-effective search model (Llama 3.3 70B)
    case sonar = "sonar"

    /// Sonar Pro - Advanced search with 2x citations
    case sonarPro = "sonar-pro"

    /// Sonar Reasoning - Chain-of-Thought capabilities
    case sonarReasoning = "sonar-reasoning"
}
```

**Add to `providerType` switch:**
```swift
case .sonar, .sonarPro, .sonarReasoning:
    return .perplexity
```

**Add capabilities:**
- `supportsSearch`: true (all Perplexity models)
- `supportsCitations`: true (all Perplexity models)
- `supportsVision`: false (text-only)
- `supportsPDF`: false
- `supportsPromptCaching`: false
- `maxInputTokens`: 128K (sonar), 200K (sonar-pro)
- `maxOutputTokens`: 4K (estimated)

### Phase 4: Provider Type Update
**File**: `Sources/SwiftlyAIKit/Models/ProviderType.swift`

```swift
public enum ProviderType: String, Codable, Sendable, CaseIterable {
    case anthropic = "anthropic"
    case openai = "openai"
    case google = "google"
    case perplexity = "perplexity"  // NEW
    case cohere = "cohere"
    case mistral = "mistral"
}
```

Update `baseURL`:
```swift
case .perplexity:
    return "https://api.perplexity.ai"
```

### Phase 5: Extend AIRequest (~50 lines)
**File**: `Sources/SwiftlyAIKit/Models/AIRequest.swift`

Add optional search parameters:
```swift
public struct AIRequest: Codable, Sendable {
    // ... existing fields ...

    // Perplexity-specific search options
    public let searchDomainFilter: [String]?
    public let searchRecencyFilter: String?
    public let returnCitations: Bool?
    public let returnImages: Bool?
}
```

### Phase 6: Extend AIResponse (~30 lines)
**File**: `Sources/SwiftlyAIKit/Models/AIResponse.swift`

Add citations and search results to metadata:
```swift
public struct AIResponse: Codable, Sendable {
    // ... existing fields ...

    // Citations from Perplexity responses
    public let citations: [String]?

    // Search results with metadata
    public let searchResults: [SearchResultMetadata]?
}

public struct SearchResultMetadata: Codable, Sendable, Equatable {
    public let title: String
    public let url: String
    public let publishedDate: String?
    public let snippet: String
}
```

## Testing Strategy (~600 lines)

### MockPerplexityAPI.swift (~300 lines)
**File**: `Tests/SwiftlyAIKitTests/Mocks/MockPerplexityAPI.swift`

Sample responses:
```swift
public enum MockPerplexityAPI {
    // Standard responses
    public static let standardResponse: String
    public static let responseWithCitations: String
    public static let responseWithSearchResults: String

    // Streaming
    public static let streamEvents: [String]

    // Structured output
    public static let jsonSchemaResponse: String

    // Errors
    public static let rateLimitError: String
    public static let authError: String
    public static let invalidModelError: String
}
```

### PerplexityProviderTests.swift (~250 lines)
**File**: `Tests/SwiftlyAIKitTests/ProviderTests/PerplexityProviderTests.swift`

Test coverage:
1. **Initialization** (3 tests)
   - Default initialization
   - Custom baseURL
   - Custom HTTP client

2. **Request Mapping** (8 tests)
   - Basic text messages
   - System prompts
   - Search domain filtering
   - Recency filtering
   - Citation options
   - Image options
   - JSON schema structured output
   - Generation config (temperature, topP, maxTokens)

3. **Response Mapping** (6 tests)
   - Standard response
   - Response with citations
   - Response with search results
   - Finish reasons
   - Usage metadata
   - Empty responses

4. **Error Handling** (5 tests)
   - 401 Unauthorized
   - 429 Rate limit (20 req/min)
   - 400 Bad request
   - 500 Server error
   - Invalid model

5. **Citations & Search** (5 tests)
   - Citations array parsing
   - Search results parsing
   - Domain filtering
   - Recency filtering
   - Citation numbering in content

6. **Structured Output** (3 tests)
   - JSON schema request format
   - JSON schema response parsing
   - Schema validation

7. **Streaming** (3 tests)
   - SSE event parsing
   - Text accumulation
   - Citations in streaming

8. **Model Support** (3 tests)
   - Sonar model properties
   - Sonar Pro model properties
   - All models use Perplexity provider

**Total: ~36 tests**

### ModelProviderTests Updates (~50 lines)
**File**: `Tests/SwiftlyAIKitTests/CoreTests/ModelProviderTests.swift`

Add tests for:
- Perplexity model count (3 new models)
- Provider type mapping
- Display names
- Search support
- Citations support
- Context windows
- Output limits

## Implementation Checklist

### Phase 1: Models (4 commits)
- [ ] Create `Models/Perplexity/` directory
- [ ] Implement message and request models
- [ ] Implement response and choice models
- [ ] Implement search result models
- [ ] Implement streaming models
- [ ] Implement error models

### Phase 2: Provider (2 commits)
- [ ] Implement `PerplexityProvider` struct
- [ ] Implement `sendMessage()` method
- [ ] Implement `streamMessage()` method
- [ ] Implement `countTokens()` stub (returns nil)
- [ ] Implement request mapping
- [ ] Implement response mapping
- [ ] Handle citations and search results

### Phase 3: Model Registration (1 commit)
- [ ] Add 3 Perplexity models to `ModelProvider` enum
- [ ] Update provider type switches
- [ ] Add display names
- [ ] Add model capabilities (search, citations)
- [ ] Add context windows and token limits

### Phase 4: Core Model Updates (1 commit)
- [ ] Add `ProviderType.perplexity`
- [ ] Update `AIRequest` with search options
- [ ] Update `AIResponse` with citations/search results
- [ ] Update base URL mapping

### Phase 5: Testing (3 commits)
- [ ] Create `MockPerplexityAPI` with sample responses
- [ ] Implement `PerplexityProviderTests` (36 tests)
- [ ] Update `ModelProviderTests` for Perplexity models
- [ ] Run all tests and verify 100% pass rate

### Phase 6: Documentation (2 commits)
- [ ] Update `CHANGELOG.md` with v0.4.0 entry
- [ ] Update `CLAUDE.md` with Perplexity implementation status
- [ ] Update `TESTING.md` with new test coverage
- [ ] Update `README.md` with Perplexity usage examples

### Phase 7: Release (1 commit)
- [ ] Create git tag `v0.4.0`
- [ ] Push to GitHub with tags

**Total Estimated Commits:** 14

## Unique Perplexity Features

### 1. Real-Time Web Search
Unlike other providers, Perplexity searches the web in real-time for every query:
```swift
let request = AIRequest(
    model: "sonar-pro",
    messages: [
        AIMessage(role: .user, content: [.text("Latest news about AI regulation")])
    ],
    searchRecencyFilter: "week"  // Only search last week
)
let response = try await req.ai.sendMessage(request)
```

### 2. Citations
Every response includes numbered citations:
```swift
let response = try await req.ai.sendMessage(request)
// response.message.content contains "[1] Citation text [2] More info..."
// response.citations = ["https://source1.com", "https://source2.com"]
```

### 3. Search Results Metadata
Detailed information about each source:
```swift
for result in response.searchResults ?? [] {
    print("Title: \(result.title)")
    print("URL: \(result.url)")
    print("Date: \(result.publishedDate ?? "N/A")")
    print("Snippet: \(result.snippet)")
}
```

### 4. Domain Filtering
Restrict searches to specific domains:
```swift
let request = AIRequest(
    model: "sonar-pro",
    messages: [...],
    searchDomainFilter: ["wikipedia.org", "britannica.com"]
)
```

### 5. Recency Filtering
Filter by time period:
```swift
let request = AIRequest(
    model: "sonar-pro",
    messages: [...],
    searchRecencyFilter: "month"  // day, week, month, year
)
```

### 6. Structured Output
Force JSON responses with schema validation:
```swift
let request = AIRequest(
    model: "sonar-pro",
    messages: [...],
    responseFormat: ResponseFormat(
        type: "json_schema",
        jsonSchema: JSONSchema(
            name: "companies",
            schema: [
                "type": "object",
                "properties": [...]
            ]
        )
    )
)
```

## Usage Examples

### Basic Search Query
```swift
import SwiftlyAIKit

// Initialize
app.ai.initialize(with: Configuration.withCompanyKey("pplx-..."))

// Simple search
let request = AIRequest(
    model: "sonar",
    messages: [
        AIMessage(role: .user, content: [.text("What's the weather in SF?")])
    ],
    returnCitations: true
)

let response = try await req.ai.sendMessage(request)
print(response.message.textContent)
// "The current weather in San Francisco is 62°F with partly cloudy skies [1]."

print(response.citations ?? [])
// ["https://weather.gov/sf/current"]
```

### Advanced Search with Filters
```swift
let request = AIRequest(
    model: "sonar-pro",
    messages: [
        AIMessage(role: .system, content: [.text("You are a research assistant.")]),
        AIMessage(role: .user, content: [.text("Find recent AI research papers")])
    ],
    searchDomainFilter: ["arxiv.org", "openreview.net"],
    searchRecencyFilter: "week",
    returnCitations: true
)

let response = try await req.ai.sendMessage(request)

// Access search results
for result in response.searchResults ?? [] {
    print("\(result.title) - \(result.url)")
}
```

### Streaming with Citations
```swift
let request = AIRequest(
    model: "sonar-pro",
    messages: [
        AIMessage(role: .user, content: [.text("Explain quantum entanglement")])
    ]
)

for try await chunk in req.ai.streamMessage(request) {
    if let text = chunk.message.textContent {
        print(text, terminator: "")
    }

    // Citations available in final chunk
    if let citations = chunk.citations {
        print("\nSources:", citations)
    }
}
```

## Error Handling

Perplexity-specific errors to handle:

### Rate Limiting
```swift
// 20 requests/min limit
catch AIError.rateLimitExceeded(let retryAfter) {
    print("Rate limited. Retry after \(retryAfter)s")
}
```

### Search Errors
```swift
// Domain filter errors
catch AIError.validationError(let message) where message.contains("domain") {
    print("Invalid domain filter")
}
```

### Invalid Model
```swift
catch AIError.invalidModel {
    print("Model not available")
}
```

## Performance Characteristics

### Speed Comparison (based on research)
- **Sonar**: 10x faster than Gemini 2.0 Flash (via Cerebras inference)
- **Sonar Pro**: Optimized for accuracy over speed, but still fast

### Pricing Comparison
| Provider | Input (per 1M tokens) | Output (per 1M tokens) | Extra Cost |
|----------|----------------------|------------------------|------------|
| Sonar | $0.20 | $0.20 | $5 per 1K searches |
| Sonar Pro | $3.00 | $15.00 | $5 per 1K searches |
| GPT-4o | $2.50 | $10.00 | None |
| Claude Sonnet 4 | $3.00 | $15.00 | None |
| Gemini 2.5 Pro | $1.25 | $5.00 | None |

**Note:** Perplexity charges for both tokens AND searches, but provides real-time web data.

### Context Windows
- **Sonar**: 128K tokens
- **Sonar Pro**: 200K tokens (largest among Sonar models)
- **Sonar Reasoning**: 128K tokens

## Estimated Timeline

### Implementation Phases
1. **Models** (~600 lines): 3-4 hours
2. **Provider** (~400 lines): 2-3 hours
3. **Core Updates** (~130 lines): 1 hour
4. **Testing** (~600 lines): 3-4 hours
5. **Documentation**: 1-2 hours

**Total Estimated Time:** 10-14 hours
**Total Estimated Lines:** ~1,730 lines (code + tests)

## Commit Strategy

Following project guidelines for small, focused commits:

1. `Add Perplexity message and request models`
2. `Add Perplexity response and choice models`
3. `Add Perplexity search result models`
4. `Add Perplexity streaming and error models`
5. `Implement PerplexityProvider core functionality`
6. `Add citation and search result handling`
7. `Add Perplexity models to ModelProvider enum`
8. `Update core models for Perplexity support (AIRequest/AIResponse)`
9. `Create MockPerplexityAPI with sample responses`
10. `Add comprehensive PerplexityProvider tests`
11. `Update ModelProviderTests for Perplexity models`
12. `Update CHANGELOG.md with Perplexity implementation`
13. `Update CLAUDE.md and TESTING.md`
14. `Release version 0.4.0 with Perplexity support`

## Version 0.4.0 Release Notes (Draft)

### Added
- **Complete Perplexity AI API integration** (~1,200 lines)
  - Real-time web search capabilities
  - Citation tracking with source URLs
  - Search result metadata (title, URL, date, snippet)
  - Domain and recency filtering
  - Structured output with JSON schema
  - Support for Sonar, Sonar Pro, and Sonar Reasoning models
  - Context windows up to 200K tokens (Sonar Pro)
- **Comprehensive test coverage** (36+ tests)
  - MockPerplexityAPI with sample responses
  - PerplexityProviderTests covering all features
  - ModelProviderTests updates

### Changed
- Extended `AIRequest` with search options (domain filter, recency filter, citations)
- Extended `AIResponse` with citations and search results
- Added `ProviderType.perplexity` to framework
- Updated `ModelProvider` enum with 3 Perplexity models

## Future Enhancements

### Potential Future Features
1. **Image Search**: When `returnImages: true` is supported by API
2. **Search API**: Implement standalone `/search` endpoint
3. **Batch Processing**: If Perplexity adds batch support
4. **Sonar Deep Research**: When available via API

### Integration with Existing Features
- Use Perplexity for fact-checking responses from GPT/Claude/Gemini
- Combine Perplexity search with other providers' generation
- Multi-provider workflows (research with Perplexity, generate with Claude)

## Conclusion

This implementation will add Perplexity AI as the **4th fully-supported provider** in SwiftlyAIKit, bringing unique real-time web search capabilities with citations. The implementation follows established patterns from Anthropic, OpenAI, and Gemini integrations while accommodating Perplexity's unique features.

**Total Addition:**
- **Implementation**: ~1,200 lines
- **Tests**: ~600 lines
- **Models**: 3 (Sonar, Sonar Pro, Sonar Reasoning)
- **Providers**: 4 total (Anthropic, OpenAI, Gemini, Perplexity)
- **Total Models**: 38 (22 Claude + 8 GPT + 5 Gemini + 3 Perplexity)

The implementation prioritizes:
✅ Real-time web search integration
✅ Citation and source tracking
✅ Domain and recency filtering
✅ Structured output support
✅ OpenAI-compatible API format
✅ Comprehensive test coverage
✅ Clear documentation
