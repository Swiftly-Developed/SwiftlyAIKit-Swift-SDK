# DeepSeek Guide

Complete guide to using DeepSeek models with SwiftlyAIKit.

## Overview

DeepSeek is the cost optimization champion:
- **Lowest pricing** - $0.14/$0.28 per million tokens
- **Reasoning mode** - DeepSeek-R1 for complex thinking
- **Prompt caching** - Reduce costs further
- **Good quality** - Competitive with expensive models
- **Fast inference** - Quick response times

Perfect for: Cost-sensitive applications, reasoning tasks, high-volume usage

## Getting Started

### Get an API Key

1. Visit [platform.deepseek.com](https://platform.deepseek.com)
2. Create an account
3. Navigate to **API Keys**
4. Create a new key
5. Copy your key (starts with `sk-`)

### Basic Usage

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .custom("deepseek-chat"),
    prompt: "Explain neural networks"
)

let response = try await gateway.sendMessage(request, to: .deepseek)
print(response.message.content)
```

## Available Models

### DeepSeek Chat (Recommended)

**Model:** `.custom("deepseek-chat")`

**Specifications:**
- **Context:** 64,000 tokens input, 8,192 tokens output
- **Pricing:** $0.14/M input, $0.28/M output (93% cheaper than GPT-4)
- **Speed:** Fast
- **Quality:** Good for most tasks

**Best for:**
- Cost optimization
- High-volume applications
- Standard conversations
- Code generation

### DeepSeek R1 (Reasoning)

**Model:** `.custom("deepseek-reasoner")`

**Specifications:**
- **Context:** 64,000 tokens
- **Pricing:** $0.55/M input, $2.19/M output (still cheap!)
- **Speed:** Slower (includes thinking)
- **Quality:** Excellent for complex problems

**Best for:**
- Math problems
- Logic puzzles
- Complex reasoning
- Strategic planning

## Reasoning Mode

DeepSeek R1 shows its "thinking" process:

```swift
let request = AIRequest(
    model: .custom("deepseek-reasoner"),
    messages: [.user("Solve: If 5 machines make 5 widgets in 5 minutes, how long for 100 machines to make 100 widgets?")]
)

let response = try await gateway.sendMessage(request, to: .deepseek)

// Response includes reasoning chain
print("Reasoning: \(response.reasoning ?? "")")
print("Answer: \(response.message.content)")
```

**Example output:**
```
Reasoning: Let me think step by step...
1. 5 machines make 5 widgets in 5 minutes
2. So each machine makes 1 widget in 5 minutes
3. 100 machines would make 100 widgets...

Answer: 5 minutes
```

## Prompt Caching

Reduce costs by 90% for repeated context:

```swift
// First request with large context
let systemPrompt = """
[Large system prompt or document - 20,000 tokens]
"""

let request1 = AIRequest(
    model: .custom("deepseek-chat"),
    systemPrompt: systemPrompt,
    messages: [.user("Question 1")],
    cacheControl: .enabled
)

let response1 = try await gateway.sendMessage(request1, to: .deepseek)
// Cost: Full price for system prompt

// Second request reuses cached context
let request2 = AIRequest(
    model: .custom("deepseek-chat"),
    systemPrompt: systemPrompt, // Same prompt - cached!
    messages: [.user("Question 2")],
    cacheControl: .enabled
)

let response2 = try await gateway.sendMessage(request2, to: .deepseek)
// Cost: 90% discount on cached portion
```

## Cost Comparison

DeepSeek vs competitors for 1M tokens (50/50 input/output):

| Provider | Model | Cost |
|----------|-------|------|
| **DeepSeek** | Chat | **$0.21** |
| Google | Gemini Flash | $0.25 |
| OpenAI | GPT-4o Mini | $0.38 |
| Anthropic | Haiku | $0.75 |
| OpenAI | GPT-4o | $6.25 |
| Anthropic | Sonnet | $9.00 |

**Savings:** Up to 97% vs premium models!

## Tool Calling

```swift
let tools = [
    AITool(
        name: "calculate",
        description: "Perform calculations",
        parameters: [
            "expression": .string(description: "Math expression", required: true)
        ]
    )
]

let request = AIRequest(
    model: .custom("deepseek-chat"),
    messages: [.user("What's 15% of 230?")],
    tools: tools
)

let response = try await gateway.sendMessage(request, to: .deepseek)

if let toolCalls = response.toolCalls {
    // Execute calculations
}
```

## Best Practices

### When to Use DeepSeek

✅ **Perfect for:**
- High-volume applications (cost adds up)
- Chatbots with many users
- Background processing
- Non-critical tasks
- Development and testing

❌ **Consider alternatives for:**
- Mission-critical applications (less proven)
- Complex reasoning (use R1 or Claude)
- Vision tasks (not supported)
- Web search (use Perplexity)

### Cost Optimization Strategies

```swift
// Strategy 1: Use DeepSeek for simple, GPT-4 for complex
func smartRoute(_ prompt: String) async throws -> AIResponse {
    let complexity = analyzeComplexity(prompt)

    if complexity < 0.5 {
        // Simple task - use DeepSeek (97% cheaper!)
        let request = AIRequest(model: .custom("deepseek-chat"), prompt: prompt)
        return try await gateway.sendMessage(request, to: .deepseek)
    } else {
        // Complex task - use premium model
        let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)
        return try await gateway.sendMessage(request, to: .anthropic)
    }
}

// Strategy 2: Cascade from cheap to expensive
func cascadeRequest(_ prompt: String) async throws -> AIResponse {
    // Try DeepSeek first
    let deepseekRequest = AIRequest(model: .custom("deepseek-chat"), prompt: prompt)
    let deepseekResponse = try await gateway.sendMessage(deepseekRequest, to: .deepseek)

    // Validate quality
    if isGoodQuality(deepseekResponse) {
        return deepseekResponse
    }

    // Fall back to premium if quality insufficient
    let claudeRequest = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)
    return try await gateway.sendMessage(claudeRequest, to: .anthropic)
}
```

## Limitations

DeepSeek does NOT support:
- Vision/image analysis
- Image generation
- Web search
- Batch processing

For these features, use other providers.

## See Also

- ``DeepSeekProvider``
- <doc:ProvidersOverview>
- <doc:PerformanceOptimization>
- <doc:PromptCaching>
- [DeepSeek Documentation](https://platform.deepseek.com/docs)
