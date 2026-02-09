# Performance Optimization

Optimize SwiftlyAIKit for production performance and cost.

## Overview

This guide covers:
- Model selection for performance
- Request optimization
- Caching strategies
- Cost reduction techniques
- Response time improvement

## Model Selection

### Speed vs Quality Tradeoff

| Model | Speed | Quality | Cost | Best For |
|-------|-------|---------|------|----------|
| **GPT-4o Mini** | ⚡⚡⚡⚡⚡ | ⭐⭐⭐ | $ | High volume |
| **Claude Haiku** | ⚡⚡⚡⚡⚡ | ⭐⭐⭐ | $ | Quick responses |
| **Gemini Flash** | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | $ | Balanced |
| **DeepSeek** | ⚡⚡⚡⚡ | ⭐⭐⭐ | $ | Cost focus |
| **Claude Sonnet** | ⚡⚡⚡ | ⭐⭐⭐⭐⭐ | $$$ | Quality focus |
| **GPT-4o** | ⚡⚡⚡ | ⭐⭐⭐⭐ | $$ | General purpose |
| **Gemini Pro** | ⚡⚡ | ⭐⭐⭐⭐⭐ | $$$ | Long context |

### Smart Routing

Route based on complexity:

```swift
func selectOptimalModel(for prompt: String) -> ModelProvider {
    let wordCount = prompt.split(separator: " ").count

    if wordCount < 50 {
        return .claude(.haiku3_5) // Fast, cheap
    } else if wordCount < 200 {
        return .gpt4(.oMini) // Balanced
    } else {
        return .claude(.sonnet4_5) // Quality
    }
}
```

## Request Optimization

### Minimize Token Usage

```swift
// ❌ Bad: Wasteful prompt
let badPrompt = """
Hi there! I hope you're having a great day!
I was wondering if you could please help me understand
something that I've been thinking about...
What is machine learning?
"""

// ✅ Good: Concise prompt
let goodPrompt = "Explain machine learning in 2 sentences"

// Savings: ~20 tokens = ~$0.00006 (adds up at scale!)
```

### Set Max Tokens

```swift
// Control response length
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("Quick question")],
    maxTokens: 100 // Limit response size
)
```

### Use Streaming for Better UX

```swift
// Non-streaming: User waits 5 seconds
let response = try await gateway.sendMessage(request)
// Then sees entire response at once

// Streaming: User sees progress immediately
let stream = try await gateway.streamMessage(request)
for try await chunk in stream {
    // Display incrementally - feels faster!
}
```

## Caching Strategies

### Application-Level Caching

```swift
actor ResponseCache {
    private var cache: [String: CachedResponse] = [:]

    struct CachedResponse {
        let response: AIResponse
        let timestamp: Date
    }

    func get(_ key: String, maxAge: TimeInterval = 300) -> AIResponse? {
        guard let cached = cache[key] else { return nil }

        let age = Date().timeIntervalSince(cached.timestamp)
        return age < maxAge ? cached.response : nil
    }

    func set(_ key: String, response: AIResponse) {
        cache[key] = CachedResponse(response: response, timestamp: Date())
    }
}

// Usage
let cache = ResponseCache()

func askWithCache(_ prompt: String) async throws -> AIResponse {
    // Check cache first
    if let cached = await cache.get(prompt, maxAge: 3600) {
        print("Cache hit!")
        return cached
    }

    // Cache miss - call AI
    let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)
    let response = try await gateway.sendMessage(request)

    await cache.set(prompt, response: response)
    return response
}

// Save 100% of costs on repeated questions!
```

### Prompt Caching (Provider-Level)

```swift
// Use Anthropic prompt caching for 90% savings
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    betaFeatures: [.anthropic: ["prompt-caching-2024-07-31"]]
)

let request = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: largeReusedContext,
    messages: [.user(question)],
    cacheControl: .enabled
)
```

**Learn more:** <doc:PromptCaching>

## Cost Optimization

### Cascade from Cheap to Expensive

```swift
func askWithCascade(_ prompt: String) async throws -> AIResponse {
    // Try cheapest first
    let cheapRequest = AIRequest(model: .custom("deepseek-chat"), prompt: prompt)

    do {
        let response = try await gateway.sendMessage(cheapRequest, to: .deepseek)

        if isGoodQuality(response) {
            return response // DeepSeek worked! ($0.21/M vs $9/M for Claude)
        }
    } catch {
        print("DeepSeek failed, trying Claude...")
    }

    // Fall back to quality model
    let expensiveRequest = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)
    return try await gateway.sendMessage(expensiveRequest, to: .anthropic)
}

func isGoodQuality(_ response: AIResponse) -> Bool {
    // Check response quality
    response.message.content.count > 50 &&
    !response.message.content.contains("I don't know")
}
```

### Batch for Bulk Operations

```swift
// Don't do this:
for doc in documents { // 1,000 documents
    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Summarize: \(doc)")
    let response = try await gateway.sendMessage(request)
    // Cost: $9/M × 1,000 = expensive!
}

// Do this instead:
let requests = documents.map { doc in
    AIRequest(model: .claude(.sonnet4_5), prompt: "Summarize: \(doc)")
}

let batchId = try await gateway.createBatch(requests, for: .anthropic)
// Cost: $4.50/M × 1,000 = 50% savings!
```

**Learn more:** <doc:BatchProcessing>

## Parallel Requests

### Concurrent Execution

```swift
// Process multiple requests in parallel
async let response1 = gateway.sendMessage(request1)
async let response2 = gateway.sendMessage(request2)
async let response3 = gateway.sendMessage(request3)

let (r1, r2, r3) = try await (response1, response2, response3)
// All execute concurrently - 3x faster than sequential!
```

### Task Groups

```swift
let responses = try await withThrowingTaskGroup(of: AIResponse.self) { group in
    for request in requests {
        group.addTask {
            try await gateway.sendMessage(request)
        }
    }

    var results: [AIResponse] = []
    for try await response in group {
        results.append(response)
    }
    return results
}
```

## Monitoring Performance

### Track Response Times

```swift
actor PerformanceMonitor {
    private var responseTimes: [TimeInterval] = []

    func record(_ duration: TimeInterval) {
        responseTimes.append(duration)
    }

    func getStats() -> (avg: TimeInterval, p50: TimeInterval, p95: TimeInterval) {
        let sorted = responseTimes.sorted()
        let avg = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[Int(Double(sorted.count) * 0.95)]

        return (avg, p50, p95)
    }
}

let monitor = PerformanceMonitor()

let start = Date()
let response = try await gateway.sendMessage(request)
let duration = Date().timeIntervalSince(start)

await monitor.record(duration)

let stats = await monitor.getStats()
print("Avg: \(stats.avg)s, P50: \(stats.p50)s, P95: \(stats.p95)s")
```

## See Also

- <doc:PromptCaching>
- <doc:BatchProcessing>
- <doc:MonitoringAndDebugging>
- <doc:ChoosingDeploymentPattern>
