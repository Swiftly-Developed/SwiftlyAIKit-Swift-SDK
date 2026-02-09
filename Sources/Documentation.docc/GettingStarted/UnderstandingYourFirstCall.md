# Understanding Your First Call

Learn what happens when you make your first AI request with SwiftlyAIKit.

## Overview

After completing the <doc:QuickStart> tutorial, you might wonder: what just happened? This guide explains each component and how they work together to call an AI provider.

## The Three Core Objects

Every SwiftlyAIKit request involves three key objects:

### 1. Configuration

```swift
let config = Configuration.withCompanyKey("sk-ant-...")
```

The ``Configuration`` tells SwiftlyAIKit:
- **How to authenticate** with providers (API key strategy)
- **Which provider** to use by default
- **HTTP settings** like timeouts and retries
- **Logging preferences** for debugging

Think of it as your framework settings. You typically create one configuration at app startup and reuse it throughout your app.

**Learn more:** <doc:ConfigurationSystem>

### 2. AIGateway

```swift
let gateway = AIGateway(configuration: config)
```

The ``AIGateway`` is your main interface to all AI providers. It's an actor (thread-safe) that:
- **Routes requests** to the appropriate provider
- **Resolves API keys** based on your configuration
- **Handles errors** and retries automatically
- **Manages streaming** and batch operations

Think of it as your AI client. You typically create one gateway and use it for all requests.

### 3. AIRequest

```swift
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello!")
```

The ``AIRequest`` contains:
- **The model** you want to use (e.g., Claude, GPT-4)
- **Your messages** (the conversation)
- **Optional settings** like temperature, max tokens, tools

Think of it as a single question to the AI. You create a new request for each API call.

## The Response

```swift
let response = try await gateway.sendMessage(request)
print(response.message.content)
```

The ``AIResponse`` contains:
- **message** - The AI's reply (``AIMessage``)
- **stopReason** - Why the response ended (natural completion, token limit, etc.)
- **usage** - Token consumption for billing
- **toolCalls** - If the AI wants to call tools/functions
- **metadata** - Provider-specific extra data

## Request Flow Diagram

```
Your App
    │
    ├─► Configuration (API key strategy)
    │
    ├─► AIGateway (coordinator)
    │       │
    │       ├─► Resolves which provider to use
    │       ├─► Resolves which API key to use
    │       └─► Routes to provider
    │
    ├─► AIRequest (your question)
    │
    └─► Provider (Anthropic/OpenAI/etc)
            │
            └─► AIResponse (AI's answer)
```

## Common Questions

### Q: Why do I need a Configuration and a Gateway?

**A:** Separation of concerns. Configuration holds your settings (which rarely change), while Gateway handles operations (which happen frequently). This design:
- Lets you reuse one configuration across multiple gateways
- Makes testing easier (mock configurations)
- Keeps your code organized

### Q: Can I reuse the same AIGateway for multiple requests?

**A:** Yes! In fact, you should. Create one gateway at app startup:

```swift
class AIService {
    let gateway: AIGateway

    init() {
        let config = Configuration.withCompanyKey("sk-ant-...")
        self.gateway = AIGateway(configuration: config)
    }

    func ask(_ question: String) async throws -> String {
        let request = AIRequest(model: .claude(.sonnet4_5), prompt: question)
        let response = try await gateway.sendMessage(request)
        return response.message.content
    }
}
```

### Q: What's the difference between `model` and `provider`?

**A:**
- **Model** is the specific AI (e.g., "claude-3-5-sonnet")
- **Provider** is the company (e.g., Anthropic)

SwiftlyAIKit can usually figure out the provider from the model name:

```swift
// Explicit provider
let response = try await gateway.sendMessage(request, to: .anthropic)

// Inferred from model
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello")
// SwiftlyAIKit knows Claude models come from Anthropic
```

### Q: What are "tokens" and why do they matter?

**A:** Tokens are pieces of text that AI models process. Roughly:
- **1 token ≈ 4 characters** in English
- **1 token ≈ 0.75 words** on average

AI providers charge based on tokens:
- **Input tokens** - Your messages
- **Output tokens** - AI's response

Example:
```swift
// This message is about 4 tokens: "What", "is", "the", "weather"
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "What is the weather")

// Response might be 10 tokens: "I", "don", "'t", "have", "access", "to", "real", "-", "time", "weather"
```

Check usage in responses:
```swift
let response = try await gateway.sendMessage(request)
print("Input tokens: \(response.usage?.inputTokens ?? 0)")
print("Output tokens: \(response.usage?.outputTokens ?? 0)")
```

### Q: What happens if my API key is invalid?

**A:** You'll get an ``AIError/authenticationFailed(provider:)`` error:

```swift
do {
    let response = try await gateway.sendMessage(request)
} catch AIError.authenticationFailed(let provider) {
    print("Bad API key for \(provider)")
} catch {
    print("Other error: \(error)")
}
```

**Learn more:** <doc:ErrorHandling>

## What's Next?

Now that you understand the basics, explore:

- **<doc:ChoosingAProvider>** - Which AI provider should you use?
- **<doc:StreamingResponses>** - Get responses in real-time
- **<doc:ErrorHandling>** - Handle failures gracefully
- **<doc:APIKeyManagement>** - Secure your API keys
- **<doc:SwiftUIIntegration>** - Build a chat interface

## See Also

- ``AIGateway``
- ``Configuration``
- ``AIRequest``
- ``AIResponse``
- ``APIKeyStrategy``
