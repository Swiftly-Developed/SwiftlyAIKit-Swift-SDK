# Choosing a Provider

Find the best AI provider for your needs.

## Overview

SwiftlyAIKit supports 9 AI providers, each with unique strengths. This guide helps you choose the right one for your use case, budget, and requirements.

## Quick Recommendations

| Your Use Case | Recommended Provider | Why? |
|---------------|---------------------|------|
| **Chat Assistant** | Anthropic Claude | Best instruction following, strong reasoning |
| **Document Analysis** | Google Gemini | 2M token context window |
| **Web Search** | Perplexity | Built-in real-time search with citations |
| **RAG/Retrieval** | Cohere | Optimized for RAG, enterprise features |
| **Vision Analysis** | OpenAI GPT-4o | Best image understanding |
| **Code Generation** | Anthropic Claude | Excellent at following coding standards |
| **Cost Optimization** | DeepSeek | Lowest cost per token |
| **Reasoning Tasks** | xAI Grok | Reasoning token tracking |
| **Privacy-First** | Apple Intelligence | On-device, no network required |

## Detailed Comparison

### Context Windows

How much text can the model process at once:

| Provider | Maximum Context | Best For |
|----------|----------------|-----------|
| **Google Gemini 2.5 Pro** | 2,000,000 tokens | Entire books, massive codebases |
| **Cohere Command R+** | 256,000 tokens | Long documents with citations |
| **Anthropic Claude 3.5** | 200,000 tokens | Technical documentation |
| **Mistral Large** | 128,000 tokens | Standard long context |
| **OpenAI GPT-4 Turbo** | 128,000 tokens | Standard long context |
| **Perplexity Sonar** | 127,000 tokens | Search + long context |
| **xAI Grok** | 128,000 tokens | Real-time data + long context |
| **DeepSeek** | 64,000 tokens | Cost-effective medium context |

**Rule of thumb:** 1 token ≈ 0.75 words, so 100K tokens ≈ 75,000 words

### Pricing (Approximate)

Cost comparison for 1M input tokens:

| Provider | Model | Input | Output | Total (50/50) |
|----------|-------|-------|--------|---------------|
| **DeepSeek** | Chat | $0.14 | $0.28 | $0.21 |
| **Mistral** | Small | $0.20 | $0.60 | $0.40 |
| **Anthropic** | Haiku | $0.25 | $1.25 | $0.75 |
| **OpenAI** | GPT-4o Mini | $0.15 | $0.60 | $0.38 |
| **Cohere** | Command R | $0.15 | $0.60 | $0.38 |
| **Google** | Gemini 2.0 Flash | $0.10 | $0.40 | $0.25 |
| **Anthropic** | Sonnet 4.5 | $3.00 | $15.00 | $9.00 |
| **OpenAI** | GPT-4 Turbo | $10.00 | $30.00 | $20.00 |
| **Perplexity** | Sonar Pro | $3.00 | $15.00 | $9.00 |

*Prices as of January 2025, subject to change*

**Cost optimization tips:**
- Use smaller models for simple tasks
- Cache prompts when possible (Anthropic, DeepSeek)
- Process in batches for bulk operations
- Consider hybrid strategies (fast model first, smart model for complex cases)

### Feature Support

What each provider can do:

| Feature | Anthropic | OpenAI | Gemini | Perplexity | Mistral | Cohere | DeepSeek | Grok | Apple |
|---------|-----------|--------|--------|------------|---------|--------|----------|------|-------|
| **Streaming** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Tool Calling** | ✓ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓ | - |
| **Vision** | ✓ | ✓ | ✓ | - | ✓ | ✓ | - | ✓ | - |
| **Image Generation** | - | ✓ | - | - | - | - | - | ✓ | ✓ |
| **Web Search** | - | - | - | ✓ | - | - | - | ✓ | - |
| **RAG Optimization** | - | - | - | - | - | ✓ | - | - | - |
| **Citations** | - | - | - | ✓ | - | ✓ | - | - | - |
| **Token Counting** | - | - | ✓ | - | - | ✓ | - | ✓ | - |
| **Prompt Caching** | ✓ | - | - | - | - | - | ✓ | ✓ | - |
| **Batch Processing** | ✓ | - | - | - | - | - | - | - | - |
| **Reasoning Mode** | ✓ | - | - | - | - | - | ✓ | - | - |

## Provider Deep Dives

### Anthropic Claude

**Best for:** Complex reasoning, instruction following, coding

```swift
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Explain quantum computing")
let response = try await gateway.sendMessage(request, to: .anthropic)
```

**Strengths:**
- Excellent at following complex instructions
- Strong coding abilities
- Large context window (200K tokens)
- Prompt caching for cost savings
- Batch processing support
- Extended thinking mode for harder problems

**Weaknesses:**
- Higher cost than some alternatives
- No web search built-in

**Pricing:** $3/M input, $15/M output tokens (Sonnet 4.5)

**Learn more:** <doc:AnthropicGuide>

### OpenAI GPT

**Best for:** General purpose, wide ecosystem, vision

```swift
let request = AIRequest(model: .gpt4(.o), prompt: "What's in this image?")
let response = try await gateway.sendMessage(request, to: .openai)
```

**Strengths:**
- Most widely adopted (huge community)
- Excellent vision capabilities
- Image generation (DALL-E)
- Good for general use cases
- Reliable performance

**Weaknesses:**
- Can be expensive (GPT-4)
- Context window smaller than Gemini

**Pricing:** $2.50/M input, $10/M output tokens (GPT-4o)

**Learn more:** <doc:OpenAIGuide>

### Google Gemini

**Best for:** Massive context, multimodal, document analysis

```swift
let request = AIRequest(model: .gemini(.pro2_5), prompt: "Analyze this 500-page document")
let response = try await gateway.sendMessage(request, to: .google)
```

**Strengths:**
- Massive 2M token context window
- Token counting API
- Multimodal (text, images, audio, video)
- Cost-effective for large context
- Function calling support

**Weaknesses:**
- Newer to market (less proven)
- Image URLs not supported (base64 only)

**Pricing:** $1.25/M input, $10/M output tokens (Pro 2.5)

**Learn more:** <doc:GeminiGuide>

### Perplexity

**Best for:** Real-time web search, current information

```swift
let request = AIRequest(model: .custom("sonar-pro"), prompt: "What happened today in tech?")
let response = try await gateway.sendMessage(request, to: .perplexity)
```

**Strengths:**
- Built-in web search
- Automatic citations
- Real-time information
- Domain filtering
- Recency filtering (day/week/month)

**Weaknesses:**
- No tool calling
- No vision support
- Smaller model selection

**Pricing:** $3/M input, $15/M output tokens (Sonar Pro)

**Learn more:** <doc:PerplexityGuide>

### Mistral AI

**Best for:** EU compliance, cost-effective, coding

```swift
let request = AIRequest(model: .custom("mistral-large-2"), prompt: "Generate Python code")
let response = try await gateway.sendMessage(request, to: .mistral)
```

**Strengths:**
- EU-hosted (GDPR compliant)
- Cost-effective
- Good coding abilities
- Vision support
- Function calling

**Weaknesses:**
- Less proven than OpenAI/Anthropic
- Smaller community

**Pricing:** $2/M input, $6/M output tokens (Large 2)

**Learn more:** <doc:MistralGuide>

### Cohere

**Best for:** RAG, enterprise search, document Q&A

```swift
let documents = [/* your docs */]
let request = AIRequest(
    model: .custom("command-a-plus"),
    prompt: "Find information about X",
    documents: documents  // RAG optimization
)
let response = try await gateway.sendMessage(request, to: .cohere)
```

**Strengths:**
- Optimized for RAG
- Citations included
- Token counting
- Enterprise features
- Multiple model sizes

**Weaknesses:**
- Less well-known
- Smaller context than Gemini/Claude

**Pricing:** $3/M input, $15/M output tokens (Command A+)

**Learn more:** <doc:CohereGuide>

### DeepSeek

**Best for:** Cost optimization, reasoning tasks

```swift
let request = AIRequest(model: .custom("deepseek-chat"), prompt: "Solve this problem")
let response = try await gateway.sendMessage(request, to: .deepseek)
```

**Strengths:**
- Lowest cost per token
- Reasoning mode (DeepSeek-R1)
- Prompt caching
- Good performance/cost ratio

**Weaknesses:**
- Newer provider
- Smaller context window
- Less feature-rich

**Pricing:** $0.14/M input, $0.28/M output tokens

**Learn more:** <doc:DeepSeekGuide>

### xAI Grok

**Best for:** Real-time data, image generation, reasoning

```swift
let request = AIRequest(model: .custom("grok-4"), prompt: "What's happening right now?")
let response = try await gateway.sendMessage(request, to: .grok)
```

**Strengths:**
- Real-time web access
- Reasoning token tracking
- Image generation
- Automatic prompt caching
- Vision support

**Weaknesses:**
- Newer to market
- Limited model selection

**Pricing:** $10/M input, $30/M output tokens (Grok 4)

**Learn more:** <doc:GrokGuide>

### Apple Intelligence

**Best for:** Privacy, on-device processing, no network

```swift
let request = AIRequest(model: .appleIntelligence(.default), prompt: "Summarize this")
let response = try await gateway.sendMessage(request, to: .appleIntelligence)
```

**Strengths:**
- Completely on-device
- No network required
- Zero API costs
- Perfect privacy
- Native integration

**Weaknesses:**
- Limited capabilities vs cloud
- Device-specific (requires Apple Silicon)
- No vision, tools, or advanced features

**Pricing:** Free (on-device)

**Learn more:** <doc:AppleIntelligenceGuide>

## Switching Between Providers

The beauty of SwiftlyAIKit is that switching is trivial:

```swift
// Same request works with any provider
let request = AIRequest(model: .custom("any-model"), prompt: "Hello")

// Just change the provider parameter
let anthropicResponse = try await gateway.sendMessage(request, to: .anthropic)
let openaiResponse = try await gateway.sendMessage(request, to: .openai)
let geminiResponse = try await gateway.sendMessage(request, to: .google)
```

## Multi-Provider Strategies

### Fallback Pattern

Try expensive model first, fall back to cheaper:

```swift
func askWithFallback(_ prompt: String) async throws -> AIResponse {
    let request = AIRequest(model: .custom("primary-model"), prompt: prompt)

    do {
        // Try premium provider first
        return try await gateway.sendMessage(request, to: .anthropic)
    } catch {
        // Fall back to budget provider
        return try await gateway.sendMessage(request, to: .deepseek)
    }
}
```

### Smart Routing

Route based on task complexity:

```swift
func smartAsk(_ prompt: String) async throws -> AIResponse {
    let isComplex = prompt.count > 500 || prompt.contains("analyze")

    let provider: ProviderType = isComplex ? .anthropic : .deepseek
    let request = AIRequest(model: .custom("model"), prompt: prompt)

    return try await gateway.sendMessage(request, to: provider)
}
```

### Load Balancing

Distribute requests across providers:

```swift
let providers: [ProviderType] = [.anthropic, .openai, .mistral]
let selectedProvider = providers.randomElement()!

let response = try await gateway.sendMessage(request, to: selectedProvider)
```

## Decision Flowchart

```
Start
  │
  ├─ Need web search? ─[Yes]→ Perplexity
  │
  ├─ Need massive context (>200K)? ─[Yes]→ Gemini
  │
  ├─ Budget constrained? ─[Yes]→ DeepSeek
  │
  ├─ Privacy critical? ─[Yes]→ Apple Intelligence
  │
  ├─ EU compliance required? ─[Yes]→ Mistral
  │
  ├─ RAG/Document Q&A? ─[Yes]→ Cohere
  │
  ├─ Image generation? ─[Yes]→ OpenAI or Grok
  │
  └─ General purpose? → Anthropic or OpenAI
```

## See Also

- <doc:ProvidersOverview>
- <doc:PerformanceOptimization>
- <doc:ChoosingDeploymentPattern>
- Individual provider guides:
  - <doc:AnthropicGuide>
  - <doc:OpenAIGuide>
  - <doc:GeminiGuide>
  - <doc:PerplexityGuide>
  - <doc:MistralGuide>
  - <doc:CohereGuide>
  - <doc:DeepSeekGuide>
  - <doc:GrokGuide>
  - <doc:AppleIntelligenceGuide>
