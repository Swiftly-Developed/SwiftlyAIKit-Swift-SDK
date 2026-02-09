# xAI Grok Guide

Complete guide to using xAI Grok models with SwiftlyAIKit.

## Overview

xAI Grok offers unique capabilities:
- **Real-time data** - Live web search integration
- **Image generation** - Grok 2 Image model
- **Reasoning tokens** - Track thinking process
- **Automatic caching** - Built-in prompt caching
- **Vision support** - Image analysis

Perfect for: Real-time information, image generation, reasoning transparency

## Getting Started

### Get an API Key

1. Visit [console.x.ai](https://console.x.ai)
2. Create an account
3. Navigate to **API Keys**
4. Create a new key
5. Copy your key (starts with `xai-`)

### Basic Usage

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("xai-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .custom("grok-4"),
    prompt: "What's happening in AI today?"
)

let response = try await gateway.sendMessage(request, to: .grok)
print(response.message.content)
```

## Available Models

| Model | Context | Capabilities | Pricing |
|-------|---------|--------------|---------|
| **Grok 4** | 128K | Chat, reasoning | $10/$30 per M |
| **Grok 3** | 1M | Chat, long context | $5/$15 per M |
| **Grok 3 Mini** | 1M | Fast, cheap | $1/$5 per M |
| **Grok 2 Vision** | 128K | Vision, chat | $2/$10 per M |
| **Grok Code Fast** | 128K | Code generation | $1/$5 per M |
| **Grok 2 Image** | - | Image generation | $0.005/image |

## Real-Time Web Search

Grok can access current information:

```swift
let request = AIRequest(
    model: .custom("grok-4"),
    messages: [.user("What major tech events happened today?")],
    searchParameters: [
        "enabled": true,
        "max_results": 10
    ]
)

let response = try await gateway.sendMessage(request, to: .grok)
// Includes up-to-date information from the web
```

## Image Generation

Generate images with Grok 2 Image:

```swift
let request = ImageGenerationRequest(
    prompt: "A futuristic city with flying cars",
    model: "grok-2-image",
    numberOfImages: 1,
    size: .landscape16_9
)

let response = try await gateway.generateImage(request, using: .grok)

for image in response.images {
    if let url = image.url {
        print("Generated: \(url)")
    }
}
```

**Grok image features:**
- Multiple aspect ratios
- Fast generation (< 10 seconds)
- Competitive pricing ($0.005/image)

## Reasoning Token Tracking

See how much "thinking" the model does:

```swift
let request = AIRequest(
    model: .custom("grok-4"),
    messages: [.user("Solve this complex problem: ...")]
)

let response = try await gateway.sendMessage(request, to: .grok)

if let usage = response.usage {
    print("Total tokens: \(usage.totalTokens)")
    print("Reasoning tokens: \(usage.reasoningTokens ?? 0)")

    let reasoningPercentage = Double(usage.reasoningTokens ?? 0) / Double(usage.totalTokens) * 100
    print("Model spent \(Int(reasoningPercentage))% of time reasoning")
}
```

## Automatic Prompt Caching

Grok automatically caches prompts:

```swift
let systemPrompt = "You are a helpful assistant with expertise in physics"

// First request
let request1 = AIRequest(
    model: .custom("grok-4"),
    systemPrompt: systemPrompt,
    messages: [.user("Explain gravity")]
)
let response1 = try await gateway.sendMessage(request1, to: .grok)

// Second request - system prompt is automatically cached!
let request2 = AIRequest(
    model: .custom("grok-4"),
    systemPrompt: systemPrompt, // Cached
    messages: [.user("Explain relativity")]
)
let response2 = try await gateway.sendMessage(request2, to: .grok)

// Check cache usage
if let cached = response2.usage?.cachedTokens {
    print("Saved \(cached) tokens via caching")
}
```

## Vision Analysis

Grok 2 Vision can analyze images:

```swift
let request = AIRequest(
    model: .custom("grok-2-vision"),
    messages: [
        .user([
            .text("What's in this technical diagram?"),
            .image(url: "https://example.com/diagram.png")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .grok)
```

## Tool Calling

```swift
let tools = [
    AITool(
        name: "get_latest_news",
        description: "Get latest news headlines",
        parameters: [
            "category": .string(description: "News category", required: true)
        ]
    )
]

let request = AIRequest(
    model: .custom("grok-4"),
    messages: [.user("What's the latest tech news?")],
    tools: tools
)

let response = try await gateway.sendMessage(request, to: .grok)
```

## Deferred Completions

For long-running requests:

```swift
let request = AIRequest(
    model: .custom("grok-4"),
    messages: [.user("Analyze this 100-page document")],
    deferred: true
)

// Returns immediately with job ID
let jobId = try await gateway.submitDeferredRequest(request, to: .grok)

// Poll for results
var result: AIResponse?
while result == nil {
    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
    result = try await gateway.checkDeferredResult(jobId, from: .grok)
}
```

## Best Practices

### Use Grok 3 for Long Context

```swift
// For large documents, use Grok 3 (1M tokens)
let largeRequest = AIRequest(
    model: .custom("grok-3"),
    messages: [.user("Analyze this 200-page document: \(document)")]
)
```

### Monitor Reasoning Costs

```swift
func trackReasoningCosts(_ response: AIResponse) {
    if let usage = response.usage,
       let reasoning = usage.reasoningTokens {
        let reasoningCost = Double(reasoning) * 0.00003 // $30/M output
        print("Reasoning cost: $\(String(format: "%.6f", reasoningCost))")

        if reasoning > 1000 {
            print("Warning: High reasoning token usage!")
        }
    }
}
```

## See Also

- ``GrokProvider``
- <doc:ProvidersOverview>
- <doc:ImageGeneration>
- <doc:VisionAndImageAnalysis>
- [xAI Documentation](https://docs.x.ai)
