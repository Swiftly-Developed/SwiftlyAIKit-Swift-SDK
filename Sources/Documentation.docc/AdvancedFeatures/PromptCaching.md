# Prompt Caching

Reduce costs by up to 90% with prompt caching.

## Overview

Prompt caching lets you reuse parts of your prompts across multiple requests, dramatically reducing costs:
- **90% cost reduction** on cached portions
- **Faster responses** (cached content loads instantly)
- **Perfect for:** Large system prompts, documents, context

**Supported providers:**
- Anthropic Claude (explicit caching)
- DeepSeek (explicit caching)
- xAI Grok (automatic caching)

## How It Works

### Traditional Approach (No Caching)

```swift
// Request 1: Pay full price for 20K token system prompt
let request1 = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: largeSystemPrompt, // 20,000 tokens
    messages: [.user("Question 1")]
)
// Cost: $0.06 ($3/M × 20K tokens)

// Request 2: Pay full price AGAIN for same system prompt
let request2 = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: largeSystemPrompt, // Same 20,000 tokens
    messages: [.user("Question 2")]
)
// Cost: $0.06 (total: $0.12)
```

### With Caching

```swift
// Request 1: Pay full price, but cache the system prompt
let request1 = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: largeSystemPrompt,
    messages: [.user("Question 1")],
    cacheControl: .enabled
)
// Cost: $0.06 (writes to cache)

// Request 2: Pay only 10% for cached system prompt!
let request2 = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: largeSystemPrompt, // Cached!
    messages: [.user("Question 2")],
    cacheControl: .enabled
)
// Cost: $0.006 (90% discount!)
// Total savings: $0.054 per subsequent request
```

## Anthropic Claude Caching

### Enable Caching

```swift
// 1. Enable beta feature
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    betaFeatures: [
        .anthropic: ["prompt-caching-2024-07-31"]
    ]
)
let gateway = AIGateway(configuration: config)

// 2. Use cacheControl in requests
let request = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: largeContext,
    messages: [.user("Your question")],
    cacheControl: .enabled
)
```

### Cache Strategy

```swift
class CachedChatService {
    let gateway: AIGateway
    let systemPrompt: String // Large, reused context

    init(gateway: AIGateway, systemPrompt: String) {
        self.gateway = gateway
        self.systemPrompt = systemPrompt
    }

    func ask(_ question: String) async throws -> String {
        let request = AIRequest(
            model: .claude(.sonnet4_5),
            systemPrompt: systemPrompt, // Reused across all requests
            messages: [.user(question)],
            cacheControl: .enabled
        )

        let response = try await gateway.sendMessage(request, to: .anthropic)

        // Check cache usage
        if let cacheRead = response.usage?.cacheReadTokens {
            print("Read \(cacheRead) tokens from cache (90% discount)")
        }
        if let cacheWrite = response.usage?.cacheWriteTokens {
            print("Wrote \(cacheWrite) tokens to cache")
        }

        return response.message.content
    }
}

// Usage
let chatbot = CachedChatService(
    gateway: gateway,
    systemPrompt: """
    You are a customer support AI for Acme Corp.
    [... 15,000 tokens of product info, policies, FAQs ...]
    """
)

// First request: Pays full price + cache write
let answer1 = try await chatbot.ask("What's your return policy?")
// Cost: ~$0.045

// Subsequent requests: 90% discount on cached system prompt
let answer2 = try await chatbot.ask("Do you ship internationally?")
// Cost: ~$0.0045 (10x cheaper!)
```

## DeepSeek Caching

```swift
let request = AIRequest(
    model: .custom("deepseek-chat"),
    systemPrompt: largeContext, // Will be cached
    messages: [.user("Question")],
    cacheControl: .enabled
)

let response = try await gateway.sendMessage(request, to: .deepseek)
```

## xAI Grok (Automatic)

Grok caches automatically - no configuration needed:

```swift
// First request
let request1 = AIRequest(
    model: .custom("grok-4"),
    systemPrompt: systemInstructions,
    messages: [.user("Question 1")]
)
let response1 = try await gateway.sendMessage(request1, to: .grok)

// Second request - automatically cached!
let request2 = AIRequest(
    model: .custom("grok-4"),
    systemPrompt: systemInstructions, // Same prompt
    messages: [.user("Question 2")]
)
let response2 = try await gateway.sendMessage(request2, to: .grok)

// Check cached tokens
if let cached = response2.usage?.cachedTokens {
    print("Grok automatically cached \(cached) tokens")
}
```

## Cost Analysis

### Anthropic Claude Pricing

**Without caching:**
- Input: $3.00 per million tokens
- Output: $15.00 per million tokens

**With caching:**
- Cache write: $3.75 per million tokens (25% more than input)
- Cache read: $0.30 per million tokens (90% discount!)
- Output: $15.00 per million tokens (unchanged)

### Example Savings

```swift
// Scenario: 10,000 token system prompt, 100 requests

// Without caching:
let costWithout = 100 * (10_000 * 0.000003) // $3.00
// Total: $3.00

// With caching:
let cacheWrite = 10_000 * 0.00000375           // $0.0375 (first request)
let cacheReads = 99 * (10_000 * 0.0000003)     // $0.297 (99 requests)
let costWith = cacheWrite + cacheReads         // $0.3345
// Total: $0.3345

// Savings: $2.67 (89% reduction!)
```

## Best Practices

### ✅ Do

**1. Cache large, reused context:**
```swift
// Good: Large system prompt used many times
let systemPrompt = """
[15,000 tokens of product catalog, company policies, etc.]
"""
```

**2. Keep prompts identical for cache hits:**
```swift
// ✅ Same prompt = cache hit
let prompt = "You are a helpful assistant"
// Use this exact string for all requests
```

**3. Monitor cache usage:**
```swift
if let usage = response.usage {
    print("Cache read: \(usage.cacheReadTokens ?? 0)")
    print("Cache write: \(usage.cacheWriteTokens ?? 0)")
}
```

### ❌ Don't

**1. Don't cache small prompts:**
```swift
// ❌ Bad: Tiny prompt, caching overhead not worth it
let systemPrompt = "Be helpful" // 2 tokens
```

**2. Don't modify cached prompts:**
```swift
// ❌ Bad: Each variation is a cache miss
let prompt1 = "You are assistant A"
let prompt2 = "You are assistant B"
// These won't share cache
```

**3. Don't cache frequently changing content:**
```swift
// ❌ Bad: Timestamp changes every request
let prompt = "Current time: \(Date()). You are an assistant."
// Cache miss every time
```

## Cache Invalidation

### TTL (Time to Live)

**Anthropic:** Cache entries last 5 minutes
**DeepSeek:** Cache duration varies
**Grok:** Automatic cache management

```swift
// Cache expires after 5 minutes of inactivity
// Make requests within 5 minutes to maintain cache
```

### Force Cache Refresh

```swift
// Disable caching to force fresh processing
let request = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: updatedPrompt,
    messages: [.user("Question")],
    cacheControl: .disabled // Force fresh processing
)
```

## Advanced Patterns

### Multi-Level Caching

```swift
// Cache both system prompt AND conversation history
let request = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: largeSystemPrompt,     // Cache level 1
    messages: previousMessages + [.user(newQuestion)], // Cache level 2
    cacheControl: .enabled
)
```

### Conditional Caching

```swift
func sendWithCaching(_ question: String, useCache: Bool) async throws -> AIResponse {
    let request = AIRequest(
        model: .claude(.sonnet4_5),
        systemPrompt: systemContext,
        messages: [.user(question)],
        cacheControl: useCache ? .enabled : .disabled
    )

    return try await gateway.sendMessage(request, to: .anthropic)
}
```

## Monitoring

### Track Cache Effectiveness

```swift
actor CacheMonitor {
    private var totalRequests = 0
    private var cacheHits = 0
    private var totalSavings: Double = 0

    func recordRequest(usage: AIUsage) {
        totalRequests += 1

        if let cacheRead = usage.cacheReadTokens, cacheRead > 0 {
            cacheHits += 1

            // Calculate savings (90% discount)
            let savings = Double(cacheRead) * 0.000003 * 0.9
            totalSavings += savings
        }
    }

    func getStats() -> (hitRate: Double, savings: Double) {
        let hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
        return (hitRate, totalSavings)
    }
}

let monitor = CacheMonitor()

let response = try await gateway.sendMessage(request, to: .anthropic)
if let usage = response.usage {
    await monitor.recordRequest(usage: usage)
}

let stats = await monitor.getStats()
print("Cache hit rate: \(Int(stats.hitRate * 100))%")
print("Total savings: $\(String(format: "%.2f", stats.savings))")
```

## See Also

- <doc:AnthropicGuide>
- <doc:DeepSeekGuide>
- <doc:GrokGuide>
- <doc:PerformanceOptimization>
- ``AIRequest``
- ``AIUsage``
