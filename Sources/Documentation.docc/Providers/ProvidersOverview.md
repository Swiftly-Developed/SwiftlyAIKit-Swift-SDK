# Providers Overview

Compare all 9 AI providers supported by SwiftlyAIKit.

## Overview

SwiftlyAIKit provides unified access to 9 major AI providers. This guide compares their capabilities, pricing, and unique features to help you choose the right provider for your needs.

**Supported Providers:**
1. Anthropic Claude
2. OpenAI GPT
3. Google Gemini
4. Perplexity
5. Mistral AI
6. Cohere
7. DeepSeek
8. xAI Grok
9. Apple Intelligence

## Feature Comparison Matrix

| Feature | Anthropic | OpenAI | Gemini | Perplexity | Mistral | Cohere | DeepSeek | Grok | Apple |
|---------|-----------|--------|--------|------------|---------|--------|----------|------|-------|
| **Streaming** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Tool Calling** | ✓ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓ | - |
| **Vision (Images)** | ✓ | ✓ | ✓ | - | ✓ | ✓ | - | ✓ | - |
| **Image Generation** | - | ✓ | - | - | - | - | - | ✓ | ✓ |
| **Web Search** | - | - | - | ✓ | - | - | - | ✓ | - |
| **RAG Features** | - | - | - | - | - | ✓ | - | - | - |
| **Citations** | - | - | - | ✓ | - | ✓ | - | - | - |
| **Token Counting** | - | - | ✓ | - | - | ✓ | - | ✓ | - |
| **Prompt Caching** | ✓ | - | - | - | - | - | ✓ | ✓ | - |
| **Batch Processing** | ✓ | - | - | - | - | - | - | - | - |
| **Reasoning Mode** | ✓ | - | - | - | - | - | ✓ | - | - |
| **JSON Mode** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - |
| **On-Device** | - | - | - | - | - | - | - | - | ✓ |

## Context Window Comparison

Maximum tokens each provider can process:

| Provider | Model | Context Window | Output Limit |
|----------|-------|----------------|--------------|
| **Google Gemini** | 2.5 Pro | 2,000,000 | 65,536 |
| **Cohere** | Command R+ | 256,000 | 8,192 |
| **Anthropic** | Claude 3.5 | 200,000 | 8,192 |
| **Perplexity** | Sonar Pro | 200,000 | 4,096 |
| **OpenAI** | GPT-4 Turbo | 128,000 | 16,384 |
| **Mistral** | Large 2.1 | 128,000 | 8,192 |
| **xAI** | Grok 3 | 128,000 | 8,192 |
| **DeepSeek** | Chat | 64,000 | 8,192 |
| **Apple** | Intelligence | N/A | N/A |

**Rule of thumb:** 1 token ≈ 0.75 words

## Pricing Comparison (January 2025)

Cost per million tokens (input / output):

| Provider | Model | Input | Output | 50/50 Average |
|----------|-------|-------|--------|---------------|
| **Google** | Gemini 2.0 Flash | $0.10 | $0.40 | $0.25 |
| **DeepSeek** | Chat | $0.14 | $0.28 | $0.21 |
| **OpenAI** | GPT-4o Mini | $0.15 | $0.60 | $0.38 |
| **Cohere** | Command R | $0.15 | $0.60 | $0.38 |
| **Mistral** | Small | $0.20 | $0.60 | $0.40 |
| **Anthropic** | Haiku | $0.25 | $1.25 | $0.75 |
| **Google** | Gemini 2.5 Pro | $1.25 | $10.00 | $5.63 |
| **Mistral** | Large 2.1 | $2.00 | $6.00 | $4.00 |
| **Anthropic** | Sonnet 4.5 | $3.00 | $15.00 | $9.00 |
| **Perplexity** | Sonar Pro | $3.00 | $15.00 | $9.00 |
| **OpenAI** | GPT-4o | $2.50 | $10.00 | $6.25 |
| **OpenAI** | GPT-4 Turbo | $10.00 | $30.00 | $20.00 |
| **xAI** | Grok 4 | $10.00 | $30.00 | $20.00 |
| **Apple** | Intelligence | **FREE** | **FREE** | **FREE** |

*Prices subject to change. Check provider websites for current pricing.*

## Quick Recommendations

### By Use Case

| Use Case | Recommended | Alternative | Budget Option |
|----------|-------------|-------------|---------------|
| **Chat Assistant** | Anthropic Sonnet | OpenAI GPT-4o | Mistral Small |
| **Document Analysis** | Google Gemini 2.5 | Anthropic Claude | Cohere Command R |
| **Code Generation** | Anthropic Sonnet | OpenAI GPT-4o | DeepSeek Chat |
| **Web Search** | Perplexity Sonar | xAI Grok | N/A |
| **Vision Analysis** | OpenAI GPT-4o | Google Gemini | Mistral Large |
| **RAG/Retrieval** | Cohere Command A+ | Google Gemini | Mistral Large |
| **Cost Optimization** | DeepSeek Chat | Google Flash | Mistral Small |
| **Privacy** | Apple Intelligence | N/A | N/A |
| **Image Generation** | OpenAI DALL-E 3 | xAI Grok | Apple Intelligence |

### By Budget

**High Budget (Quality First):**
- Primary: Anthropic Claude Sonnet 4.5
- Vision: OpenAI GPT-4o
- Long Context: Google Gemini 2.5 Pro

**Medium Budget (Balanced):**
- Primary: OpenAI GPT-4o Mini
- Vision: Mistral Large
- Long Context: Cohere Command R+

**Low Budget (Cost Optimized):**
- Primary: DeepSeek Chat
- Vision: Mistral Small
- Long Context: Google Gemini 2.0 Flash

**Zero Budget:**
- Apple Intelligence (on-device, no API costs)

## Switching Between Providers

### Same Code, Any Provider

```swift
let request = AIRequest(model: .custom("any-model"), prompt: "Explain quantum computing")

// Try different providers with identical code
let anthropicResponse = try await gateway.sendMessage(request, to: .anthropic)
let openaiResponse = try await gateway.sendMessage(request, to: .openai)
let geminiResponse = try await gateway.sendMessage(request, to: .google)
```

### Provider-Specific Models

```swift
// Use type-safe model enums
let claudeRequest = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello")
let gptRequest = AIRequest(model: .gpt4(.o), prompt: "Hello")
let geminiRequest = AIRequest(model: .gemini(.pro2_5), prompt: "Hello")

// Or use custom strings
let customRequest = AIRequest(model: .custom("claude-3-5-sonnet-20241022"), prompt: "Hello")
```

## Multi-Provider Strategies

### Strategy 1: Fallback Chain

Try expensive model first, fall back to cheaper if it fails:

```swift
func askWithFallback(_ prompt: String) async throws -> AIResponse {
    let request = AIRequest(model: .custom("model"), prompt: prompt)
    let providers: [ProviderType] = [.anthropic, .openai, .deepseek]

    var lastError: Error?

    for provider in providers {
        do {
            return try await gateway.sendMessage(request, to: provider)
        } catch {
            lastError = error
            continue
        }
    }

    throw lastError ?? AIError.networkError("All providers failed")
}
```

### Strategy 2: Load Balancing

Distribute requests across providers to avoid rate limits:

```swift
actor ProviderBalancer {
    private var providers: [ProviderType] = [.anthropic, .openai, .mistral]
    private var index = 0

    func next() -> ProviderType {
        let provider = providers[index]
        index = (index + 1) % providers.count
        return provider
    }
}

let balancer = ProviderBalancer()

func askBalanced(_ prompt: String) async throws -> AIResponse {
    let provider = await balancer.next()
    let request = AIRequest(model: .custom("model"), prompt: prompt)
    return try await gateway.sendMessage(request, to: provider)
}
```

### Strategy 3: Cost Optimization

Route based on task complexity:

```swift
func smartRoute(_ prompt: String) async throws -> AIResponse {
    let complexity = analyzeComplexity(prompt)

    let provider: ProviderType
    switch complexity {
    case .simple:
        provider = .deepseek // Cheapest
    case .medium:
        provider = .mistral // Balanced
    case .complex:
        provider = .anthropic // Best quality
    }

    let request = AIRequest(model: .custom("model"), prompt: prompt)
    return try await gateway.sendMessage(request, to: provider)
}

enum TaskComplexity {
    case simple, medium, complex
}

func analyzeComplexity(_ prompt: String) -> TaskComplexity {
    let wordCount = prompt.split(separator: " ").count

    if wordCount < 20 {
        return .simple
    } else if wordCount < 100 {
        return .medium
    } else {
        return .complex
    }
}
```

### Strategy 4: Feature-Based Routing

Route based on required features:

```swift
func routeByFeature(_ request: AIRequest) -> ProviderType {
    // Need web search?
    if request.searchEnabled {
        return .perplexity
    }

    // Need RAG with citations?
    if request.documents != nil {
        return .cohere
    }

    // Need massive context?
    if request.messages.count > 50 {
        return .google // 2M tokens
    }

    // Need vision?
    if request.messages.contains(where: { $0.hasImages }) {
        return .openai
    }

    // Default
    return .anthropic
}
```

## Provider Capabilities Detail

### Anthropic Claude

**Best for:** Complex reasoning, coding, long conversations

**Unique features:**
- Prompt caching (reduce costs by 90% for repeated context)
- Extended thinking mode
- Batch processing (async bulk requests)
- Best-in-class instruction following

**Models:**
- Claude 3.5 Sonnet (recommended)
- Claude 3.5 Haiku (fast, cheap)
- Claude 3 Opus (most capable)

**Learn more:** <doc:AnthropicGuide>

### OpenAI GPT

**Best for:** General purpose, vision, widest ecosystem

**Unique features:**
- DALL-E integration (image generation)
- Most widely adopted (huge community)
- GPT-4o (multimodal, fast)
- Structured outputs

**Models:**
- GPT-4o (recommended)
- GPT-4o Mini (cheap, fast)
- GPT-4 Turbo (legacy)

**Learn more:** <doc:OpenAIGuide>

### Google Gemini

**Best for:** Massive context, document analysis

**Unique features:**
- 2M token context window (entire books)
- Token counting API
- Multimodal (text, images, audio, video)
- Free tier available

**Models:**
- Gemini 2.5 Pro (best quality, huge context)
- Gemini 2.0 Flash (fast, cheap)
- Gemini 1.5 Pro (legacy)

**Learn more:** <doc:GeminiGuide>

### Perplexity

**Best for:** Real-time web search, current information

**Unique features:**
- Built-in web search
- Automatic citations
- Domain filtering
- Recency filtering (day/week/month)

**Models:**
- Sonar Pro (best quality with search)
- Sonar (standard search)
- Sonar Reasoning (complex queries)

**Learn more:** <doc:PerplexityGuide>

### Mistral AI

**Best for:** EU compliance, cost-effective quality

**Unique features:**
- EU-hosted (GDPR compliant)
- Good coding abilities
- Vision support
- Competitive pricing

**Models:**
- Large 2.1 (best quality)
- Medium 3 (balanced)
- Small 3.1 (fast, cheap)

**Learn more:** <doc:MistralGuide>

### Cohere

**Best for:** RAG, enterprise search, citations

**Unique features:**
- RAG-optimized
- Automatic citations
- Token counting
- Safety modes
- Multiple model sizes

**Models:**
- Command A+ (best quality)
- Command R+ (balanced)
- Command (legacy)

**Learn more:** <doc:CohereGuide>

### DeepSeek

**Best for:** Cost optimization, reasoning

**Unique features:**
- Lowest cost per token
- Reasoning mode (DeepSeek-R1)
- Prompt caching
- Good quality/price ratio

**Models:**
- DeepSeek Chat (general)
- DeepSeek R1 (reasoning)

**Learn more:** <doc:DeepSeekGuide>

### xAI Grok

**Best for:** Real-time data, image generation

**Unique features:**
- Real-time web access
- Image generation (Grok 2 Image)
- Reasoning token tracking
- Automatic prompt caching

**Models:**
- Grok 4 (best quality)
- Grok 3 (standard)
- Grok 2 Vision (vision + generation)

**Learn more:** <doc:GrokGuide>

### Apple Intelligence

**Best for:** Privacy, on-device processing

**Unique features:**
- Completely on-device
- No network required
- No API costs
- Perfect privacy
- Native iOS/macOS integration

**Models:**
- Apple Intelligence Default

**Learn more:** <doc:AppleIntelligenceGuide>

## Technical Specifications

### Context Windows

| Provider | Max Input Tokens | Max Output Tokens |
|----------|------------------|-------------------|
| Google Gemini 2.5 Pro | 2,000,000 | 65,536 |
| Cohere Command R+ | 256,000 | 8,192 |
| Anthropic Claude 3.5 | 200,000 | 8,192 |
| Perplexity Sonar Pro | 200,000 | 4,096 |
| OpenAI GPT-4 Turbo | 128,000 | 16,384 |
| Mistral Large | 128,000 | 8,192 |
| xAI Grok 3 | 128,000 | 8,192 |
| DeepSeek Chat | 64,000 | 8,192 |

### Streaming Performance

Typical latency from request to first chunk:

| Provider | First Chunk | Average Chunk Rate |
|----------|-------------|-------------------|
| OpenAI GPT-4o | ~200ms | ~10 chunks/sec |
| Anthropic Claude | ~300ms | ~8 chunks/sec |
| Google Gemini | ~250ms | ~12 chunks/sec |
| Mistral Large | ~400ms | ~6 chunks/sec |
| DeepSeek Chat | ~300ms | ~10 chunks/sec |

*Varies by prompt complexity and server load*

### Authentication Methods

| Provider | Auth Type | Header Format |
|----------|-----------|---------------|
| Anthropic | Custom | `x-api-key: sk-ant-...` |
| OpenAI | Bearer | `Authorization: Bearer sk-...` |
| Google | Query Param | `?key=...` |
| Perplexity | Bearer | `Authorization: Bearer pplx-...` |
| Mistral | Bearer | `Authorization: Bearer ...` |
| Cohere | Bearer | `Authorization: Bearer ...` |
| DeepSeek | Bearer | `Authorization: Bearer sk-...` |
| xAI | Bearer | `Authorization: Bearer xai-...` |
| Apple | None | No key required |

## Unique Provider Features

### Anthropic: Prompt Caching

Reduce costs by up to 90% for repeated context:

```swift
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: messages,
    systemPrompt: largeSystemPrompt,
    cacheControl: .enabled // Cache the system prompt
)
```

**Learn more:** <doc:PromptCaching>

### Perplexity: Web Search

Get real-time information with citations:

```swift
let options = PerplexityOptions(
    searchDomainFilter: ["arxiv.org", "wikipedia.org"],
    searchRecencyFilter: .week
)

let request = AIRequest(
    model: .custom("sonar-pro"),
    prompt: "Latest developments in quantum computing",
    providerOptions: options.toJSON()
)

let response = try await gateway.sendMessage(request, to: .perplexity)
// Response includes citations!
```

**Learn more:** <doc:PerplexityGuide>

### Cohere: RAG Optimization

Optimized for retrieval-augmented generation:

```swift
let documents = [
    Document(id: "1", content: "Paris is the capital of France"),
    Document(id: "2", content: "London is the capital of UK")
]

let request = AIRequest(
    model: .custom("command-a-plus"),
    prompt: "What's the capital of France?",
    documents: documents
)

let response = try await gateway.sendMessage(request, to: .cohere)
// Response includes citations to documents!
```

**Learn more:** <doc:RAGOptimization>

### OpenAI: Image Generation

Generate images with DALL-E:

```swift
let request = ImageGenerationRequest.dallE3(
    prompt: "A serene mountain landscape at sunset",
    size: .square1024,
    quality: .hd
)

let response = try await gateway.generateImage(request, using: .openai)
```

**Learn more:** <doc:ImageGeneration>

### Apple Intelligence: On-Device Privacy

No network, perfect privacy:

```swift
let request = AIRequest(
    model: .appleIntelligence(.default),
    prompt: "Summarize this private document"
)

let response = try await gateway.sendMessage(request, to: .appleIntelligence)
// Processed entirely on-device, never leaves the Mac/iPhone
```

**Learn more:** <doc:AppleIntelligenceGuide>

## Code Examples

### Basic Multi-Provider App

```swift
import SwiftlyAIKit

class MultiProviderService {
    let gateway: AIGateway

    init() {
        // Set up keys for multiple providers
        let config = Configuration.withProviderKeys([
            .anthropic: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!,
            .openai: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!,
            .google: ProcessInfo.processInfo.environment["GOOGLE_API_KEY"]!
        ])
        self.gateway = AIGateway(configuration: config)
    }

    func ask(_ prompt: String, using provider: ProviderType) async throws -> String {
        let request = AIRequest(model: .custom("model"), prompt: prompt)
        let response = try await gateway.sendMessage(request, to: provider)
        return response.message.content
    }
}

// Usage
let service = MultiProviderService()

let claudeAnswer = try await service.ask("Explain recursion", using: .anthropic)
let gptAnswer = try await service.ask("Explain recursion", using: .openai)
let geminiAnswer = try await service.ask("Explain recursion", using: .google)
```

### Provider Comparison Tool

```swift
func compareProviders(prompt: String, providers: [ProviderType]) async throws {
    let request = AIRequest(model: .custom("model"), prompt: prompt)

    print("Comparing \(providers.count) providers for: '\(prompt)'\n")

    for provider in providers {
        let start = Date()

        do {
            let response = try await gateway.sendMessage(request, to: provider)
            let duration = Date().timeIntervalSince(start)

            print("\(provider):")
            print("  Time: \(String(format: "%.2f", duration))s")
            print("  Tokens: \(response.usage?.totalTokens ?? 0)")
            print("  Response: \(response.message.content.prefix(100))...")
            print()
        } catch {
            print("\(provider): Error - \(error)")
            print()
        }
    }
}

// Compare providers
try await compareProviders(
    prompt: "Explain quantum entanglement",
    providers: [.anthropic, .openai, .google, .deepseek]
)
```

## Provider Selection Decision Tree

```
Start
  │
  ├─ Need privacy/on-device? ──[Yes]──> Apple Intelligence
  │
  ├─ Need web search? ──[Yes]──> Perplexity or Grok
  │
  ├─ Context > 200K tokens? ──[Yes]──> Gemini (2M) or Cohere (256K)
  │
  ├─ Budget < $1/M tokens? ──[Yes]──> DeepSeek or Gemini Flash
  │
  ├─ Need EU compliance? ──[Yes]──> Mistral
  │
  ├─ Need RAG/citations? ──[Yes]──> Cohere
  │
  ├─ Need image generation? ──[Yes]──> OpenAI, Grok, or Apple
  │
  ├─ Need best reasoning? ──[Yes]──> Claude or DeepSeek R1
  │
  └─ General purpose? ──> Claude, GPT-4o, or Gemini
```

## Getting API Keys

### Provider Signup Links

- **Anthropic:** [console.anthropic.com](https://console.anthropic.com)
- **OpenAI:** [platform.openai.com](https://platform.openai.com)
- **Google:** [aistudio.google.com](https://aistudio.google.com)
- **Perplexity:** [perplexity.ai/settings/api](https://perplexity.ai/settings/api)
- **Mistral:** [console.mistral.ai](https://console.mistral.ai)
- **Cohere:** [dashboard.cohere.com](https://dashboard.cohere.com)
- **DeepSeek:** [platform.deepseek.com](https://platform.deepseek.com)
- **xAI:** [console.x.ai](https://console.x.ai)
- **Apple:** No key needed (on-device)

### Free Tiers

| Provider | Free Tier | Limits |
|----------|-----------|--------|
| Google Gemini | Yes | 15 requests/min, 1M tokens/day |
| Anthropic | No | Credit card required |
| OpenAI | No | Credit card required |
| Perplexity | Limited | 5 requests/month |
| Mistral | Limited | Some free credits |
| Cohere | Trial | Time-limited free tier |
| DeepSeek | Limited | Some free usage |
| xAI | No | Credit card required |
| Apple | Yes | Unlimited (on-device) |

## See Also

- <doc:ChoosingAProvider>
- Individual Provider Guides:
  - <doc:AnthropicGuide>
  - <doc:OpenAIGuide>
  - <doc:GeminiGuide>
  - <doc:PerplexityGuide>
  - <doc:MistralGuide>
  - <doc:CohereGuide>
  - <doc:DeepSeekGuide>
  - <doc:GrokGuide>
  - <doc:AppleIntelligenceGuide>
- <doc:PerformanceOptimization>
- <doc:ChoosingDeploymentPattern>
- ``ProviderType``
