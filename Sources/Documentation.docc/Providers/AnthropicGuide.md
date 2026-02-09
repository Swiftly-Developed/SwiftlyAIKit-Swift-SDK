# Anthropic Claude Guide

Complete guide to using Anthropic Claude models with SwiftlyAIKit.

## Overview

Anthropic Claude is known for:
- **Excellent instruction following** - Does what you ask
- **Strong reasoning** - Complex problem solving
- **Long context** - 200K token window
- **Coding expertise** - Best-in-class code generation
- **Safety focus** - Constitutional AI approach

SwiftlyAIKit provides full support for:
- Messages API (create, stream)
- Batch API (async bulk processing)
- Prompt caching (90% cost reduction)
- Extended thinking mode
- Tool calling
- Vision (images, PDFs)

## Getting Started

### Get an API Key

1. Visit [console.anthropic.com](https://console.anthropic.com)
2. Create an account
3. Navigate to **API Keys**
4. Click **Create Key**
5. Copy your key (starts with `sk-ant-api03-`)

### Basic Usage

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-ant-api03-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .claude(.sonnet4_5),
    prompt: "Explain quantum computing in simple terms"
)

let response = try await gateway.sendMessage(request)
print(response.message.content)
```

## Available Models

SwiftlyAIKit supports all Claude models:

### Claude 3.5 Sonnet (Recommended)

**Model:** `.claude(.sonnet4_5)`

```swift
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Your prompt")
```

**Specifications:**
- **Context:** 200,000 tokens input, 8,192 tokens output
- **Pricing:** $3/M input, $15/M output tokens
- **Speed:** Medium (1-3 seconds for short responses)
- **Quality:** Highest quality, best reasoning

**Best for:**
- Complex reasoning tasks
- Code generation
- Long conversations
- Following detailed instructions

### Claude 3.5 Haiku (Fast & Cheap)

**Model:** `.claude(.haiku3_5)`

```swift
let request = AIRequest(model: .claude(.haiku3_5), prompt: "Quick question")
```

**Specifications:**
- **Context:** 200,000 tokens input, 8,192 tokens output
- **Pricing:** $0.25/M input, $1.25/M output tokens
- **Speed:** Fast (< 1 second for short responses)
- **Quality:** Good for most tasks

**Best for:**
- Quick responses
- High-volume applications
- Cost-sensitive use cases
- Simple questions

### Claude 3 Opus (Most Capable)

**Model:** `.claude(.opus3)`

```swift
let request = AIRequest(model: .claude(.opus3), prompt: "Complex analysis needed")
```

**Specifications:**
- **Context:** 200,000 tokens input, 4,096 tokens output
- **Pricing:** $15/M input, $75/M output tokens
- **Speed:** Slower (3-5 seconds for short responses)
- **Quality:** Highest capability

**Best for:**
- Very complex tasks
- Research and analysis
- When quality is paramount
- Budget is not a concern

## Streaming Responses

Get real-time responses as Claude generates them:

```swift
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Write a story")

let stream = try await gateway.streamMessage(request, to: .anthropic)

for try await chunk in stream {
    print(chunk.message.content, terminator: "")
}
print() // New line
```

**Streaming Behavior:**
- Claude streams complete words/phrases
- Average: 8-10 chunks per second
- First chunk: ~300ms latency
- Smooth, natural flow

## Tool Calling (Function Calling)

Give Claude access to your functions:

```swift
// Define your tools
let tools = [
    AITool(
        name: "get_weather",
        description: "Get current weather for a location",
        parameters: [
            "location": .string(description: "City name", required: true),
            "unit": .string(description: "celsius or fahrenheit", required: false)
        ]
    ),
    AITool(
        name: "search_database",
        description: "Search the customer database",
        parameters: [
            "query": .string(description: "Search query", required: true)
        ]
    )
]

// Send request with tools
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("What's the weather in Tokyo?")],
    tools: tools
)

let response = try await gateway.sendMessage(request, to: .anthropic)

// Handle tool calls
if let toolCalls = response.toolCalls {
    for toolCall in toolCalls {
        switch toolCall.name {
        case "get_weather":
            let location = toolCall.arguments["location"] as? String
            let weather = await getWeather(for: location ?? "Tokyo")
            // Send result back to Claude...

        case "search_database":
            let query = toolCall.arguments["query"] as? String
            let results = await searchDB(query ?? "")
            // Send result back to Claude...

        default:
            print("Unknown tool: \(toolCall.name)")
        }
    }
}
```

**Learn more:** <doc:ToolCalling>

## Vision (Image Analysis)

Claude can analyze images:

```swift
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [
        .user([
            .text("What's in this image?"),
            .image(url: "https://example.com/photo.jpg")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .anthropic)
print(response.message.content) // "The image shows..."
```

**Supported formats:**
- JPEG, PNG, GIF, WebP
- Base64 encoded data
- Image URLs
- Multiple images per request

**PDF Support:**

```swift
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [
        .user([
            .text("Summarize this PDF"),
            .document(base64: pdfBase64, mediaType: "application/pdf")
        ])
    ]
)
```

**Learn more:** <doc:VisionAndImageAnalysis>

## Prompt Caching

Reduce costs by up to 90% for repeated context:

### What is Prompt Caching?

Anthropic caches parts of your prompt (system instructions, documents) to reduce costs:
- **First request:** Normal pricing
- **Subsequent requests:** 90% discount on cached portions

### How to Enable

```swift
// Requires beta feature flag
let provider = AnthropicProvider(
    enableBetaFeatures: ["prompt-caching-2024-07-31"]
)

// Register with gateway
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    betaFeatures: [.anthropic: ["prompt-caching-2024-07-31"]]
)
let gateway = AIGateway(configuration: config)
```

### Usage Pattern

```swift
// Large system prompt (will be cached)
let systemPrompt = """
You are a helpful coding assistant. You follow these guidelines:
[... 5,000 tokens of instructions ...]
"""

let request = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: systemPrompt,
    messages: [.user("Write a Python function to sort a list")],
    cacheControl: .enabled
)

// First call: Full cost for system prompt
let response1 = try await gateway.sendMessage(request)

// Second call: 90% discount on cached system prompt
let request2 = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: systemPrompt, // Same prompt - cached!
    messages: [.user("Write a JavaScript function to reverse a string")],
    cacheControl: .enabled
)
let response2 = try await gateway.sendMessage(request2)
```

**Cost savings:**
- System prompt: 5,000 tokens
- First request: $0.015 (full price)
- Second request: $0.0015 (90% discount)
- **Savings: $0.0135 per request**

**Learn more:** <doc:PromptCaching>

## Extended Thinking Mode

Let Claude "think" before responding:

```swift
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("Solve this complex math problem: ...")],
    thinkingOptions: ThinkingOptions(
        type: .enabled,
        budget: 10000 // Max thinking tokens
    )
)

let response = try await gateway.sendMessage(request, to: .anthropic)

// Check thinking content
if let thinking = response.thinking {
    print("Claude's thought process: \(thinking)")
}

print("Final answer: \(response.message.content)")
```

**When to use:**
- Complex reasoning tasks
- Math problems
- Code debugging
- Strategic planning

**Cost:** Thinking tokens count toward output tokens

## Batch Processing

Process large volumes asynchronously with cost savings:

### Create a Batch

```swift
let requests = [
    AIRequest(model: .claude(.sonnet4_5), prompt: "Summarize doc 1"),
    AIRequest(model: .claude(.sonnet4_5), prompt: "Summarize doc 2"),
    AIRequest(model: .claude(.sonnet4_5), prompt: "Summarize doc 3")
    // ... up to 10,000 requests
]

let batchId = try await gateway.createBatch(requests, for: .anthropic)
print("Batch created: \(batchId)")
```

### Monitor Batch Status

```swift
let status = try await gateway.retrieveBatch(batchId, from: .anthropic)

print("Status: \(status.status)") // "processing", "completed", "failed"
print("Processed: \(status.requestsProcessed)/\(status.requestsTotal)")
```

### Retrieve Results

```swift
let results = try await gateway.getBatchResults(batchId, from: .anthropic)

for try await result in results {
    if let response = result.response {
        print("Result \(result.customId): \(response.message.content)")
    } else if let error = result.error {
        print("Error \(result.customId): \(error)")
    }
}
```

**Pricing:**
- 50% discount compared to standard API
- 24-hour processing window

**Learn more:** <doc:BatchProcessing>

## Advanced Configuration

### Beta Features

```swift
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    betaFeatures: [
        .anthropic: [
            "prompt-caching-2024-07-31",
            "extended-thinking-2024-12-12"
        ]
    ]
)
```

**Available beta features:**
- `prompt-caching-2024-07-31` - Enable prompt caching
- `extended-thinking-2024-12-12` - Enable extended thinking
- Check Anthropic docs for latest features

### Custom Base URL

```swift
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    customBaseURLs: [
        .anthropic: "https://api.anthropic.com/v1"
    ]
)
```

### Temperature and Sampling

```swift
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("Be creative!")],
    temperature: 1.0,      // Higher = more creative (0.0-1.0)
    topP: 0.9,             // Nucleus sampling
    topK: 40               // Top-K sampling
)
```

**Recommendations:**
- **Creative writing:** temperature 0.7-1.0
- **Code generation:** temperature 0.0-0.3
- **General chat:** temperature 0.5-0.7

## Best Practices

### ✅ Do

- Use prompt caching for repeated context
- Set appropriate temperature for task
- Use Haiku for simple/frequent tasks
- Use Sonnet for complex reasoning
- Monitor token usage for cost control
- Implement tool calling for dynamic data
- Use batch processing for bulk operations

### ❌ Don't

- Use Opus unless absolutely necessary (very expensive)
- Forget to enable beta features for caching
- Ignore streaming for better UX
- Set temperature too high for factual tasks
- Process large batches synchronously

## Common Patterns

### Long-Running Conversations

```swift
class ClaudeConversation {
    private var history: [AIMessage] = []
    private let gateway: AIGateway

    init(gateway: AIGateway) {
        self.gateway = gateway
    }

    func ask(_ question: String) async throws -> String {
        history.append(.user(question))

        let request = AIRequest(
            model: .claude(.sonnet4_5),
            messages: history,
            systemPrompt: "You are a helpful assistant"
        )

        let response = try await gateway.sendMessage(request, to: .anthropic)

        history.append(.assistant(response.message.content))

        return response.message.content
    }
}
```

### Cost-Optimized Workflow

```swift
func costEffectiveWorkflow(_ task: Task) async throws -> AIResponse {
    switch task.complexity {
    case .simple:
        // Use Haiku for 95% cost savings
        let request = AIRequest(model: .claude(.haiku3_5), messages: task.messages)
        return try await gateway.sendMessage(request, to: .anthropic)

    case .complex:
        // Use Sonnet with caching
        let request = AIRequest(
            model: .claude(.sonnet4_5),
            messages: task.messages,
            systemPrompt: task.cachedContext,
            cacheControl: .enabled
        )
        return try await gateway.sendMessage(request, to: .anthropic)

    case .critical:
        // Use Opus only when necessary
        let request = AIRequest(model: .claude(.opus3), messages: task.messages)
        return try await gateway.sendMessage(request, to: .anthropic)
    }
}
```

## Error Handling

### Anthropic-Specific Errors

```swift
do {
    let response = try await gateway.sendMessage(request, to: .anthropic)
} catch AIError.rateLimitExceeded(let retryAfter) {
    print("Hit rate limit. Retry after \(retryAfter)s")
    // Anthropic rate limits: 50 requests/min (Tier 1)
} catch AIError.validationError(let message) {
    if message.contains("prompt_too_long") {
        print("Reduce prompt size or use Opus for 200K context")
    }
} catch {
    print("Error: \(error)")
}
```

### Rate Limits by Tier

| Tier | Requests/Min | Tokens/Min | Tokens/Day |
|------|-------------|------------|------------|
| **1** | 50 | 40,000 | 1,000,000 |
| **2** | 1,000 | 80,000 | 2,500,000 |
| **3** | 2,000 | 160,000 | 5,000,000 |
| **4** | 4,000 | 400,000 | 10,000,000 |

Check your tier at [console.anthropic.com](https://console.anthropic.com)

## Pricing Details

### Input vs Output Costs

```swift
let response = try await gateway.sendMessage(request, to: .anthropic)

if let usage = response.usage {
    let inputCost = Double(usage.inputTokens) * 0.000003  // $3/M
    let outputCost = Double(usage.outputTokens) * 0.000015 // $15/M
    let totalCost = inputCost + outputCost

    print("Request cost: $\(String(format: "%.6f", totalCost))")
    print("  Input: \(usage.inputTokens) tokens ($\(String(format: "%.6f", inputCost)))")
    print("  Output: \(usage.outputTokens) tokens ($\(String(format: "%.6f", outputCost)))")
}
```

### Caching Discounts

```swift
// With prompt caching enabled
if let cacheRead = response.usage?.cacheReadTokens {
    let cacheSavings = Double(cacheRead) * 0.000003 * 0.9
    print("Cache savings: $\(String(format: "%.6f", cacheSavings))")
}
```

## Migration from Anthropic SDK

### Before (Official SDK)

```swift
import Anthropic

let client = Anthropic(apiKey: "sk-ant-...")

let message = try await client.messages.create(
    model: "claude-3-5-sonnet-20241022",
    messages: [.init(role: .user, content: "Hello")],
    maxTokens: 1024
)
```

### After (SwiftlyAIKit)

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-ant-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("Hello")],
    maxTokens: 1024
)

let response = try await gateway.sendMessage(request, to: .anthropic)
```

**Benefits of switching:**
- Support for multiple providers
- Unified API across all providers
- Server integration (SwiftlyAIServerKit)
- Better error handling

## Best Practices

### System Prompts

Claude responds well to clear system prompts:

```swift
let systemPrompt = """
You are a Python coding assistant. When writing code:
- Use type hints
- Add docstrings
- Follow PEP 8 style
- Include error handling
- Add usage examples
"""

let request = AIRequest(
    model: .claude(.sonnet4_5),
    systemPrompt: systemPrompt,
    messages: [.user("Write a function to parse JSON")]
)
```

### Few-Shot Examples

Improve quality with examples:

```swift
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [
        .user("Extract the product name: 'I love my iPhone 15 Pro'"),
        .assistant("iPhone 15 Pro"),
        .user("Extract the product name: 'My MacBook Air is amazing'"),
        .assistant("MacBook Air"),
        .user("Extract the product name: 'Just bought a new Tesla Model 3'")
    ]
)
```

### Context Management

For long conversations, summarize periodically:

```swift
if history.count > 50 {
    // Summarize old messages
    let summaryRequest = AIRequest(
        model: .claude(.haiku3_5), // Cheap model for summarization
        messages: Array(history.prefix(30)),
        prompt: "Summarize this conversation in 3 sentences"
    )

    let summary = try await gateway.sendMessage(summaryRequest, to: .anthropic)

    // Replace old messages with summary
    history = [.assistant(summary.message.content)] + Array(history.suffix(20))
}
```

## Production Tips

### Monitor Costs

```swift
actor CostTracker {
    private var totalInputTokens = 0
    private var totalOutputTokens = 0

    func recordUsage(_ usage: AIUsage) {
        totalInputTokens += usage.inputTokens
        totalOutputTokens += usage.outputTokens
    }

    func getCost() -> Double {
        let inputCost = Double(totalInputTokens) * 0.000003
        let outputCost = Double(totalOutputTokens) * 0.000015
        return inputCost + outputCost
    }
}

let tracker = CostTracker()

let response = try await gateway.sendMessage(request, to: .anthropic)
if let usage = response.usage {
    await tracker.recordUsage(usage)
}

let totalCost = await tracker.getCost()
print("Total API cost: $\(totalCost)")
```

### Implement Rate Limit Handling

```swift
func sendWithRateLimit(_ request: AIRequest) async throws -> AIResponse {
    do {
        return try await gateway.sendMessage(request, to: .anthropic)
    } catch AIError.rateLimitExceeded(let retryAfter) {
        print("Rate limited. Waiting \(retryAfter)s...")

        try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)

        return try await gateway.sendMessage(request, to: .anthropic)
    }
}
```

### Set Appropriate Timeouts

```swift
// For long tasks (document analysis)
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    timeout: 120 // 2 minutes
)

// For quick responses
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    timeout: 30  // 30 seconds
)
```

## Troubleshooting

### "overloaded_error" - System Overload

**Solution:** Retry with exponential backoff

```swift
var retries = 0
while retries < 3 {
    do {
        return try await gateway.sendMessage(request, to: .anthropic)
    } catch AIError.providerError(let status, let message) where message.contains("overloaded") {
        retries += 1
        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retries))) * 1_000_000_000)
    }
}
```

### "prompt_too_long" - Context Exceeded

**Solution:** Reduce context or use summarization

```swift
// Check token count before sending
if let tokenCount = try await gateway.countTokens(request, for: .anthropic),
   tokenCount > 190_000 { // Leave buffer
    // Trim or summarize
    request = trimRequest(request)
}
```

## See Also

- ``AnthropicProvider``
- <doc:ProvidersOverview>
- <doc:ToolCalling>
- <doc:VisionAndImageAnalysis>
- <doc:PromptCaching>
- <doc:BatchProcessing>
- [Anthropic Documentation](https://docs.anthropic.com)
