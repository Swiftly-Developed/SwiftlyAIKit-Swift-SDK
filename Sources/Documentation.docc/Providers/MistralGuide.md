# Mistral AI Guide

Complete guide to using Mistral AI models with SwiftlyAIKit.

## Overview

Mistral AI offers:
- **EU-hosted** - GDPR compliant, European data residency
- **Cost-effective** - Competitive pricing
- **Strong coding** - Codestral specialized model
- **Vision support** - Image analysis capabilities
- **Multiple sizes** - From 3B to Large models

Perfect for: EU compliance requirements, cost-effective quality, coding tasks

## Getting Started

### Get an API Key

1. Visit [console.mistral.ai](https://console.mistral.ai)
2. Create an account
3. Navigate to **API Keys**
4. Create a new key
5. Copy your key (32 characters)

### Basic Usage

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("your-32-char-key")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .custom("mistral-large-2"),
    prompt: "Explain serverless architecture"
)

let response = try await gateway.sendMessage(request, to: .mistral)
print(response.message.content)
```

## Available Models

| Model | Context | Parameters | Pricing | Best For |
|-------|---------|------------|---------|----------|
| **Large 2.1** | 128K | 123B | $2/$6 per M | General purpose |
| **Medium 3** | 128K | - | $2.50/$7.50 per M | Balanced quality |
| **Small 3.1** | 128K | 24B | $0.20/$0.60 per M | High volume |
| **Codestral** | 32K | 22B | $0.30/$0.90 per M | Code generation |
| **Magistral Small** | 128K | - | $1/$3 per M | Cost-effective |
| **Ministral 3B** | 128K | 3B | $0.04/$0.10 per M | Ultra-cheap |
| **Ministral 8B** | 128K | 8B | $0.10/$0.10 per M | Cheap |

## EU Compliance

Mistral is perfect for European deployments:

**Data residency:** Servers in Europe
**GDPR compliance:** Full compliance
**Privacy:** European privacy laws

```swift
// For EU customers
let config = Configuration.withCompanyKey("key")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .custom("mistral-large-2"),
    prompt: "Process this customer data" // Stays in EU
)

let response = try await gateway.sendMessage(request, to: .mistral)
```

## Code Generation (Codestral)

Specialized model for coding:

```swift
let request = AIRequest(
    model: .custom("codestral-latest"),
    systemPrompt: "You are an expert Swift developer",
    messages: [.user("Write a function to parse JSON")]
)

let response = try await gateway.sendMessage(request, to: .mistral)
```

**Codestral features:**
- Trained on 80+ programming languages
- Optimized for code completion
- Strong at debugging
- Good for code review

## Vision Support

Mistral Large supports image analysis:

```swift
let request = AIRequest(
    model: .custom("mistral-large-2"),
    messages: [
        .user([
            .text("What's in this image?"),
            .image(url: "https://example.com/photo.jpg")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .mistral)
```

## Function Calling

```swift
let tools = [
    AITool(
        name: "get_user_info",
        description: "Get user information from database",
        parameters: [
            "user_id": .string(description: "User ID", required: true)
        ]
    )
]

let request = AIRequest(
    model: .custom("mistral-large-2"),
    messages: [.user("Get info for user 12345")],
    tools: tools
)

let response = try await gateway.sendMessage(request, to: .mistral)
```

## Advanced Features

### Safe Prompt Mode

Prepend safety instructions:

```swift
let request = AIRequest(
    model: .custom("mistral-large-2"),
    messages: [.user("Your query")],
    safePrompt: true // Adds safety guardrails
)
```

### Random Seed

For reproducible outputs:

```swift
let request = AIRequest(
    model: .custom("mistral-large-2"),
    messages: [.user("Generate code")],
    seed: 42 // Same seed = same output
)
```

## Best Practices

### Model Selection

```swift
func selectMistralModel(task: TaskType) -> String {
    switch task {
    case .coding:
        return "codestral-latest"
    case .complex:
        return "mistral-large-2"
    case .simple:
        return "ministral-8b"
    case .highVolume:
        return "ministral-3b"
    }
}
```

### Cost Optimization

```swift
// Use smallest model that works
let models = ["ministral-3b", "ministral-8b", "mistral-small-3", "mistral-large-2"]

for model in models {
    let request = AIRequest(model: .custom(model), prompt: prompt)
    let response = try await gateway.sendMessage(request, to: .mistral)

    if meetsQualityBar(response) {
        return response // Use cheapest sufficient model
    }
}
```

## See Also

- ``MistralProvider``
- <doc:ProvidersOverview>
- <doc:VisionAndImageAnalysis>
- <doc:ToolCalling>
- [Mistral Documentation](https://docs.mistral.ai)
