# Google Gemini Guide

Complete guide to using Google Gemini models with SwiftlyAIKit.

## Overview

Google Gemini is known for:
- **Massive context** - 2 million token context window
- **Multimodal** - Text, images, audio, video
- **Token counting** - Built-in token counting API
- **Cost-effective** - Competitive pricing for long context
- **Free tier** - Generous free usage limits

SwiftlyAIKit provides full support for:
- GenerateContent API
- Streaming responses
- Token counting
- Function calling
- Safety settings
- Structured outputs

## Getting Started

### Get an API Key

1. Visit [aistudio.google.com](https://aistudio.google.com)
2. Click **Get API Key**
3. Create or select a project
4. Copy your key (39 characters)

### Basic Usage

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("YOUR_GOOGLE_API_KEY")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .gemini(.pro2_5),
    prompt: "Analyze this 100-page document"
)

let response = try await gateway.sendMessage(request, to: .google)
print(response.message.content)
```

## Available Models

### Gemini 2.5 Pro (Best Quality + Huge Context)

**Model:** `.gemini(.pro2_5)`

**Specifications:**
- **Context:** 2,000,000 tokens input, 65,536 tokens output
- **Pricing:** $1.25/M input (<= 128K), $2.50/M (> 128K), $10/M output
- **Speed:** Medium (2-4 seconds)
- **Multimodal:** Text, images, audio, video

**Best for:**
- Entire books or codebases
- Long document analysis
- Multi-document reasoning
- Complex multimodal tasks

### Gemini 2.0 Flash (Fast & Cheap)

**Model:** `.gemini(.flash2)`

**Specifications:**
- **Context:** 1,000,000 tokens input, 8,192 tokens output
- **Pricing:** $0.10/M input (<= 128K), $0.20/M (> 128K), $0.40/M output
- **Speed:** Very fast
- **Multimodal:** Text, images

**Best for:**
- High-volume applications
- Cost-sensitive use cases
- Quick responses
- Standard context needs

## The 2 Million Token Advantage

Gemini's massive context window lets you process entire books:

```swift
// Process a 500-page book (≈ 150,000 tokens)
let bookText = loadEntireBook() // 500 pages

let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [
        .user("Analyze this entire book and identify the main themes:\n\n\(bookText)")
    ]
)

let response = try await gateway.sendMessage(request, to: .google)
// Gemini can see the ENTIRE book at once!
```

**Context window comparison:**
- Gemini 2.5 Pro: **2,000,000 tokens** (entire books)
- GPT-4 Turbo: 128,000 tokens (long documents)
- Claude 3.5 Sonnet: 200,000 tokens (technical docs)

## Token Counting

Gemini provides a token counting API:

```swift
let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [.user("How many tokens is this message?")]
)

let tokenCount = try await gateway.countTokens(request, for: .google)
print("This request will use \(tokenCount ?? 0) tokens")

// Helps estimate costs before making request
if let count = tokenCount {
    let cost = Double(count) * 0.00000125 // $1.25/M for input
    print("Estimated cost: $\(String(format: "%.6f", cost))")
}
```

## Function Calling

Gemini supports function calling:

```swift
let tools = [
    AITool(
        name: "get_exchange_rate",
        description: "Get current exchange rate between currencies",
        parameters: [
            "from": .string(description: "Source currency code", required: true),
            "to": .string(description: "Target currency code", required: true)
        ]
    )
]

let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [.user("What's the USD to EUR exchange rate?")],
    tools: tools
)

let response = try await gateway.sendMessage(request, to: .google)

if let toolCalls = response.toolCalls {
    for toolCall in toolCalls {
        if toolCall.name == "get_exchange_rate" {
            let rate = await getExchangeRate(
                from: toolCall.arguments["from"] as? String ?? "USD",
                to: toolCall.arguments["to"] as? String ?? "EUR"
            )
            // Send result back to Gemini
        }
    }
}
```

## Multimodal Capabilities

### Image Analysis

```swift
let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [
        .user([
            .text("Describe this image in detail"),
            .image(data: base64Image, mediaType: "image/jpeg")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .google)
```

**Note:** Gemini requires base64-encoded images, not URLs.

### Multiple Images

```swift
let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [
        .user([
            .text("Compare these three images"),
            .image(data: image1Base64, mediaType: "image/jpeg"),
            .image(data: image2Base64, mediaType: "image/jpeg"),
            .image(data: image3Base64, mediaType: "image/jpeg")
        ])
    ]
)
```

## Safety Settings

Control content filtering:

```swift
let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [.user("Your prompt")],
    safetySettings: [
        .harassment: .blockNone,
        .hateSpeech: .blockMediumAndAbove,
        .sexuallyExplicit: .blockMediumAndAbove,
        .dangerous: .blockMediumAndAbove
    ]
)
```

**Thresholds:**
- `blockNone` - Allow all content
- `blockLowAndAbove` - Block low-risk and above
- `blockMediumAndAbove` - Block medium-risk and above
- `blockOnlyHigh` - Block only high-risk

## Structured Outputs

Get JSON responses:

```swift
let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [.user("List 3 programming languages as JSON array")],
    responseFormat: .json,
    responseSchema: """
    {
        "type": "array",
        "items": {"type": "string"}
    }
    """
)

let response = try await gateway.sendMessage(request, to: .google)
// Response is guaranteed valid JSON matching schema
```

## Pricing Details

### Tiered Pricing

Gemini uses tiered pricing based on context size:

| Context Size | Pro 2.5 Input | Flash 2.0 Input |
|--------------|---------------|-----------------|
| 0-128K tokens | $1.25/M | $0.10/M |
| 128K+ tokens | $2.50/M | $0.20/M |

Output pricing:
- Pro 2.5: $10/M tokens
- Flash 2.0: $0.40/M tokens

### Cost Calculation

```swift
func calculateGeminiCost(inputTokens: Int, outputTokens: Int, model: String) -> Double {
    let inputCost: Double
    if inputTokens <= 128_000 {
        inputCost = model.contains("pro") ? 0.00000125 : 0.0000001
    } else {
        inputCost = model.contains("pro") ? 0.0000025 : 0.0000002
    }

    let outputCost = model.contains("pro") ? 0.00001 : 0.0000004

    return Double(inputTokens) * inputCost + Double(outputTokens) * outputCost
}
```

## Free Tier

Gemini offers a generous free tier:

**Limits:**
- 15 requests per minute
- 1 million tokens per day
- 1,500 requests per day

**Models:**
- Gemini 2.0 Flash (free)
- Gemini 1.5 Flash (free)
- Gemini 1.5 Pro (free with limits)

Perfect for:
- Prototyping
- Small-scale applications
- Learning and experimentation

## Best Practices

### Long Context Usage

```swift
// Process multiple documents at once
let documents = [doc1, doc2, doc3, doc4, doc5] // 200K tokens total

let combined = documents.joined(separator: "\n\n---\n\n")

let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [.user("Find common themes across these 5 documents:\n\n\(combined)")]
)
// Gemini can see ALL documents simultaneously!
```

### Cost Optimization

```swift
// Use Flash for simple tasks
let simpleRequest = AIRequest(model: .gemini(.flash2), prompt: "Quick question")

// Use Pro for complex reasoning
let complexRequest = AIRequest(model: .gemini(.pro2_5), prompt: "Analyze deeply")
```

### Token Counting Before Requests

```swift
if let count = try await gateway.countTokens(request, for: .google) {
    if count > 128_000 {
        print("Warning: Will use higher pricing tier (>128K tokens)")

        // Consider splitting or summarizing
        if count > 1_900_000 {
            print("Too large! Must reduce context.")
        }
    }
}
```

## Rate Limits

| Tier | RPM | TPM | RPD |
|------|-----|-----|-----|
| **Free** | 15 | 1,000,000 | 1,500 |
| **Paid** | 360 | 4,000,000 | 10,000 |

## Migration from Google AI SDK

### Before

```swift
import GoogleGenerativeAI

let model = GenerativeModel(name: "gemini-2.0-flash", apiKey: "key")
let response = try await model.generateContent("Hello")
```

### After (SwiftlyAIKit)

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("key")
let gateway = AIGateway(configuration: config)

let request = AIRequest(model: .gemini(.flash2), prompt: "Hello")
let response = try await gateway.sendMessage(request, to: .google)
```

## See Also

- ``GeminiProvider``
- <doc:ProvidersOverview>
- <doc:VisionAndImageAnalysis>
- <doc:ToolCalling>
- [Google AI Documentation](https://ai.google.dev/docs)
