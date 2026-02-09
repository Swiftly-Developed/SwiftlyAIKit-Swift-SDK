# Perplexity Guide

Complete guide to using Perplexity AI models with SwiftlyAIKit.

## Overview

Perplexity AI is the search-first AI provider:
- **Real-time web search** - Always current information
- **Automatic citations** - Sources included
- **Domain filtering** - Search specific sites
- **Recency filtering** - Recent results only
- **Sonar models** - Optimized for search + reasoning

Perfect for apps that need current information, research, or fact-checking.

## Getting Started

### Get an API Key

1. Visit [perplexity.ai/settings/api](https://perplexity.ai/settings/api)
2. Create an account
3. Click **Generate API Key**
4. Copy your key (starts with `pplx-`)

### Basic Usage

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("pplx-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .custom("sonar-pro"),
    prompt: "What are the latest developments in AI?"
)

let response = try await gateway.sendMessage(request, to: .perplexity)
print(response.message.content)
```

## Available Models

| Model | Context | Speed | Search Quality | Pricing |
|-------|---------|-------|----------------|---------|
| **sonar-pro** | 200K | Fast | Best | $3/$15 per M |
| **sonar** | 127K | Fast | Good | $1/$5 per M |
| **sonar-reasoning** | 127K | Slower | Best | $1/$5 per M |

## Web Search with Citations

The killer feature - every response includes sources:

```swift
let request = AIRequest(
    model: .custom("sonar-pro"),
    prompt: "What happened at CES 2025?"
)

let response = try await gateway.sendMessage(request, to: .perplexity)

print(response.message.content)
// "At CES 2025, several major announcements were made..."

if let citations = response.citations {
    print("\nSources:")
    for citation in citations {
        print("- \(citation.title): \(citation.url)")
    }
}
```

**Example output:**
```
At CES 2025, NVIDIA announced new GPUs, Samsung revealed foldable displays...

Sources:
- The Verge: CES 2025 highlights
  https://theverge.com/ces-2025
- TechCrunch: NVIDIA's CES announcement
  https://techcrunch.com/nvidia-ces
```

## Domain Filtering

Search specific websites only:

```swift
import SwiftlyAIKit

let options = PerplexityOptions(
    searchDomainFilter: [
        "arxiv.org",
        "wikipedia.org",
        "github.com"
    ]
)

let request = AIRequest(
    model: .custom("sonar-pro"),
    prompt: "Latest research on quantum computing",
    providerOptions: options.toJSON()
)

let response = try await gateway.sendMessage(request, to: .perplexity)
// Only searches academic and technical sites
```

## Recency Filtering

Get only recent results:

```swift
let options = PerplexityOptions(
    searchRecencyFilter: .week // Last 7 days only
)

let request = AIRequest(
    model: .custom("sonar-pro"),
    prompt: "Latest news about SpaceX",
    providerOptions: options.toJSON()
)

let response = try await gateway.sendMessage(request, to: .perplexity)
// Only includes results from the past week
```

**Recency options:**
- `.day` - Last 24 hours
- `.week` - Last 7 days
- `.month` - Last 30 days
- `.year` - Last 365 days

## Return Citations

Control whether citations are included:

```swift
let options = PerplexityOptions(
    returnCitations: true,
    returnImages: true,
    returnRelatedQuestions: true
)

let request = AIRequest(
    model: .custom("sonar-pro"),
    prompt: "History of the Roman Empire",
    providerOptions: options.toJSON()
)

let response = try await gateway.sendMessage(request, to: .perplexity)

// Access rich metadata
if let metadata = response.metadata {
    if let citations = metadata["citations"] {
        print("Citations: \(citations)")
    }
    if let related = metadata["related_questions"] {
        print("Related questions: \(related)")
    }
}
```

## Streaming with Search

```swift
let request = AIRequest(
    model: .custom("sonar-pro"),
    prompt: "What's happening in tech today?"
)

let stream = try await gateway.streamMessage(request, to: .perplexity)

for try await chunk in stream {
    print(chunk.message.content, terminator: "")
}

// Citations appear at the end
```

## JSON Mode

Get structured responses:

```swift
let request = AIRequest(
    model: .custom("sonar-pro"),
    messages: [.user("List top 3 AI companies with their market cap as JSON")],
    responseFormat: .json
)

let response = try await gateway.sendMessage(request, to: .perplexity)
let json = try JSONDecoder().decode(CompanyList.self, from: response.message.content.data(using: .utf8)!)
```

## Use Cases

### Research Assistant

```swift
func research(_ topic: String) async throws -> ResearchResult {
    let options = PerplexityOptions(
        searchDomainFilter: ["arxiv.org", "scholar.google.com", "pubmed.gov"],
        searchRecencyFilter: .year,
        returnCitations: true
    )

    let request = AIRequest(
        model: .custom("sonar-pro"),
        prompt: "Research paper summary on: \(topic)",
        providerOptions: options.toJSON()
    )

    let response = try await gateway.sendMessage(request, to: .perplexity)

    return ResearchResult(
        summary: response.message.content,
        citations: response.citations ?? []
    )
}
```

### News Aggregator

```swift
func getLatestNews(category: String) async throws -> String {
    let options = PerplexityOptions(
        searchRecencyFilter: .day,
        returnCitations: true
    )

    let request = AIRequest(
        model: .custom("sonar"),
        prompt: "Summarize today's top news in \(category)",
        providerOptions: options.toJSON()
    )

    return try await gateway.sendMessage(request, to: .perplexity).message.content
}
```

### Fact Checker

```swift
func factCheck(_ claim: String) async throws -> FactCheckResult {
    let options = PerplexityOptions(
        returnCitations: true,
        returnRelatedQuestions: true
    )

    let request = AIRequest(
        model: .custom("sonar-pro"),
        prompt: "Fact check this claim and provide sources: \(claim)",
        providerOptions: options.toJSON()
    )

    let response = try await gateway.sendMessage(request, to: .perplexity)

    return FactCheckResult(
        verdict: response.message.content,
        sources: response.citations ?? []
    )
}
```

## Pricing

| Model | Input ($/M) | Output ($/M) | Best For |
|-------|-------------|--------------|----------|
| Sonar Pro | $3.00 | $15.00 | High-quality search |
| Sonar | $1.00 | $5.00 | Standard search |
| Sonar Reasoning | $1.00 | $5.00 | Complex queries |

## Best Practices

### ✅ Do

- Use domain filtering to improve result quality
- Request citations for verifiable information
- Use recency filters for time-sensitive queries
- Leverage sonar-pro for important searches
- Cache responses when appropriate

### ❌ Don't

- Use for tasks that don't need web search (wastes money)
- Expect tool calling support (not available)
- Send images (vision not supported)
- Ignore citations (defeats the purpose)

## Limitations

Perplexity does NOT support:
- Tool/function calling
- Vision/image analysis
- Batch processing
- Prompt caching

For these features, use Anthropic, OpenAI, or Gemini.

## See Also

- ``PerplexityProvider``
- ``PerplexityOptions``
- <doc:ProvidersOverview>
- [Perplexity Documentation](https://docs.perplexity.ai)
