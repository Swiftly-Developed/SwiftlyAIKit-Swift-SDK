# OpenAI GPT Guide

Complete guide to using OpenAI GPT models and DALL-E with SwiftlyAIKit.

## Overview

OpenAI is the creator of ChatGPT and DALL-E, offering:
- **GPT-4o** - Fast multimodal model
- **GPT-4 Turbo** - Advanced reasoning
- **DALL-E 3** - Image generation
- **Widest adoption** - Huge community and ecosystem

SwiftlyAIKit provides full support for:
- Chat Completions API
- Streaming responses
- Vision (image analysis)
- Tool/function calling
- DALL-E image generation

## Getting Started

### Get an API Key

1. Visit [platform.openai.com](https://platform.openai.com)
2. Create an account
3. Navigate to **API Keys**
4. Click **Create new secret key**
5. Copy your key (starts with `sk-`)

### Basic Usage

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .gpt4(.o),
    prompt: "Explain machine learning"
)

let response = try await gateway.sendMessage(request, to: .openai)
print(response.message.content)
```

## Available Models

### GPT-4o (Recommended)

**Model:** `.gpt4(.o)`

```swift
let request = AIRequest(model: .gpt4(.o), prompt: "Your question")
```

**Specifications:**
- **Context:** 128,000 tokens input, 16,384 tokens output
- **Pricing:** $2.50/M input, $10.00/M output tokens
- **Speed:** Fast (< 1 second for short responses)
- **Vision:** Supported
- **Quality:** Excellent for most tasks

**Best for:**
- General purpose chat
- Vision analysis
- Balanced cost/quality
- Multimodal tasks

### GPT-4o Mini (Fast & Cheap)

**Model:** `.gpt4(.oMini)`

```swift
let request = AIRequest(model: .gpt4(.oMini), prompt: "Quick question")
```

**Specifications:**
- **Context:** 128,000 tokens
- **Pricing:** $0.15/M input, $0.60/M output tokens
- **Speed:** Very fast
- **Vision:** Supported

**Best for:**
- High-volume applications
- Cost optimization
- Quick responses
- Simple tasks

### GPT-4 Turbo (Advanced)

**Model:** `.gpt4(.turbo)`

```swift
let request = AIRequest(model: .gpt4(.turbo), prompt: "Complex analysis")
```

**Specifications:**
- **Context:** 128,000 tokens
- **Pricing:** $10/M input, $30/M output tokens
- **Speed:** Medium
- **Vision:** Supported

**Best for:**
- Complex reasoning
- Coding tasks
- When quality is critical

## Streaming Responses

```swift
let request = AIRequest(model: .gpt4(.o), prompt: "Write a story")
let stream = try await gateway.streamMessage(request, to: .openai)

for try await chunk in stream {
    print(chunk.message.content, terminator: "")
}
```

**GPT Streaming Characteristics:**
- Streams smaller tokens than Claude
- Average: 10-15 chunks/second
- First chunk: ~200ms latency
- Very smooth streaming experience

## Vision (Image Analysis)

GPT-4o and GPT-4 Turbo support vision:

### Analyze an Image URL

```swift
let request = AIRequest(
    model: .gpt4(.o),
    messages: [
        .user([
            .text("What's in this image?"),
            .image(url: "https://example.com/photo.jpg")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .openai)
```

### Analyze Base64 Image

```swift
let base64Image = imageData.base64EncodedString()

let request = AIRequest(
    model: .gpt4(.o),
    messages: [
        .user([
            .text("Describe this image in detail"),
            .image(data: base64Image, mediaType: "image/jpeg")
        ])
    ]
)
```

### Multiple Images

```swift
let request = AIRequest(
    model: .gpt4(.o),
    messages: [
        .user([
            .text("Compare these two images"),
            .image(url: "https://example.com/image1.jpg"),
            .image(url: "https://example.com/image2.jpg")
        ])
    ]
)
```

**Learn more:** <doc:VisionAndImageAnalysis>

## Tool Calling (Function Calling)

```swift
let tools = [
    AITool(
        name: "get_stock_price",
        description: "Get current stock price for a symbol",
        parameters: [
            "symbol": .string(description: "Stock ticker symbol (e.g., AAPL)", required: true)
        ]
    )
]

let request = AIRequest(
    model: .gpt4(.o),
    messages: [.user("What's Apple's stock price?")],
    tools: tools
)

let response = try await gateway.sendMessage(request, to: .openai)

if let toolCalls = response.toolCalls {
    for toolCall in toolCalls {
        if toolCall.name == "get_stock_price" {
            let symbol = toolCall.arguments["symbol"] as? String
            let price = await fetchStockPrice(symbol ?? "AAPL")

            // Send result back to GPT
            let followUp = AIRequest(
                model: .gpt4(.o),
                messages: request.messages + [
                    .assistant("", toolCalls: [toolCall]),
                    .tool(name: toolCall.name, content: "Current price: $\(price)")
                ]
            )

            let finalResponse = try await gateway.sendMessage(followUp, to: .openai)
            print(finalResponse.message.content)
        }
    }
}
```

**Learn more:** <doc:ToolCalling>

## Image Generation (DALL-E)

Generate images using DALL-E 3:

```swift
let request = ImageGenerationRequest.dallE3(
    prompt: "A futuristic city at sunset, cyberpunk style",
    size: .square1024,
    quality: .hd,
    style: .vivid
)

let response = try await gateway.generateImage(request, using: .openai)

for image in response.images {
    if let url = image.url {
        print("Image URL: \(url)")
        // Download and display
    }
}
```

**DALL-E 3 Options:**
- **Sizes:** 1024x1024, 1024x1792, 1792x1024
- **Quality:** standard, hd
- **Style:** vivid, natural
- **Pricing:** $0.040-$0.120 per image

**Learn more:** <doc:ImageGeneration>

## JSON Mode

Get structured JSON responses:

```swift
let request = AIRequest(
    model: .gpt4(.o),
    messages: [.user("List 3 colors in JSON format: {\"colors\": []}")],
    responseFormat: .json
)

let response = try await gateway.sendMessage(request, to: .openai)
// Response is guaranteed valid JSON
```

## Advanced Configuration

### Organization ID

For multi-tenant accounts:

```swift
let provider = OpenAIProvider(
    organizationId: "org-xxxxx"
)

// Register with gateway
let gateway = AIGateway(
    configuration: config,
    providers: [.openai: provider]
)
```

### Custom Base URL

For Azure OpenAI or proxies:

```swift
let config = Configuration(
    keyStrategy: .companyKey("azure-key"),
    customBaseURLs: [
        .openai: "https://your-resource.openai.azure.com"
    ]
)
```

## Best Practices

### System Messages

```swift
let request = AIRequest(
    model: .gpt4(.o),
    systemPrompt: "You are a helpful coding assistant specialized in Swift",
    messages: [.user("How do I use async/await?")]
)
```

### Temperature Settings

```swift
// Creative tasks
let creativeRequest = AIRequest(
    model: .gpt4(.o),
    messages: [.user("Write a creative story")],
    temperature: 0.9
)

// Factual tasks
let factualRequest = AIRequest(
    model: .gpt4(.o),
    messages: [.user("What is 2+2?")],
    temperature: 0.1
)
```

### Max Tokens

```swift
let request = AIRequest(
    model: .gpt4(.o),
    messages: [.user("Write a haiku")],
    maxTokens: 50 // Short response
)
```

## Pricing and Costs

### Token Usage Tracking

```swift
let response = try await gateway.sendMessage(request, to: .openai)

if let usage = response.usage {
    let inputCost = Double(usage.inputTokens) * 0.0000025  // $2.50/M
    let outputCost = Double(usage.outputTokens) * 0.00001  // $10/M
    let total = inputCost + outputCost

    print("Cost: $\(String(format: "%.6f", total))")
}
```

### Model Comparison

| Model | Input ($/M) | Output ($/M) | Best For |
|-------|-------------|--------------|----------|
| GPT-4o | $2.50 | $10.00 | General purpose |
| GPT-4o Mini | $0.15 | $0.60 | High volume |
| GPT-4 Turbo | $10.00 | $30.00 | Complex reasoning |
| GPT-3.5 Turbo | $0.50 | $1.50 | Legacy/simple tasks |

## Migration from OpenAI SDK

### Before (Official SDK)

```swift
import OpenAI

let client = OpenAI(apiToken: "sk-...")

let query = ChatQuery(
    messages: [.init(role: .user, content: "Hello")],
    model: .gpt4_o
)

let result = try await client.chats(query: query)
```

### After (SwiftlyAIKit)

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .gpt4(.o),
    messages: [.user("Hello")]
)

let response = try await gateway.sendMessage(request, to: .openai)
```

**Benefits:**
- Multi-provider support
- Simpler API
- Better error handling
- Server integration included

**Learn more:** <doc:FromOpenAISDK>

## Troubleshooting

### Rate Limits

OpenAI has tier-based rate limits:

| Tier | RPM | TPM |
|------|-----|-----|
| **Free** | 3 | 40,000 |
| **Tier 1** | 500 | 200,000 |
| **Tier 2** | 5,000 | 2,000,000 |

**Solution:**
```swift
do {
    return try await gateway.sendMessage(request, to: .openai)
} catch AIError.rateLimitExceeded(let retryAfter) {
    try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
    return try await gateway.sendMessage(request, to: .openai)
}
```

### Context Length Errors

```swift
do {
    return try await gateway.sendMessage(request, to: .openai)
} catch AIError.validationError(let message) where message.contains("context_length") {
    // Trim conversation history
    let trimmed = trimToFit(request, maxTokens: 120_000)
    return try await gateway.sendMessage(trimmed, to: .openai)
}
```

## See Also

- ``OpenAIProvider``
- <doc:ProvidersOverview>
- <doc:VisionAndImageAnalysis>
- <doc:ImageGeneration>
- <doc:ToolCalling>
- <doc:FromOpenAISDK>
- [OpenAI Documentation](https://platform.openai.com/docs)
