# Common Pitfalls

Avoid these common mistakes when getting started with SwiftlyAIKit.

## Overview

This guide covers the most common issues developers encounter and how to fix them. Each section starts with the error symptom, explains the cause, and shows the solution.

## Authentication Errors

### "Authentication failed" - Invalid API Key

**Symptom:** Error occurs immediately when sending first request

```
AIError.authenticationFailed(provider: .anthropic)
```

**Common Causes:**

#### 1. Typo in API Key

❌ **Wrong:**
```swift
let config = Configuration.withCompanyKey("sk-ant-api-...") // Missing digits
```

✅ **Right:**
```swift
let config = Configuration.withCompanyKey("sk-ant-api03-xxxxxxxxxxxx...")
// Full key including all characters
```

#### 2. Wrong Provider for Your Key

❌ **Wrong:**
```swift
// Using OpenAI key with Anthropic provider
let config = Configuration.withCompanyKey("sk-...") // OpenAI key
let response = try await gateway.sendMessage(request, to: .anthropic)
```

✅ **Right:**
```swift
// Match key to provider
let config = Configuration.withCompanyKey("sk-...") // OpenAI key
let response = try await gateway.sendMessage(request, to: .openai)

// Or use per-provider keys
let config = Configuration.withProviderKeys([
    .anthropic: "sk-ant-...",
    .openai: "sk-..."
])
```

#### 3. API Key Not Set in Environment

❌ **Wrong:**
```swift
// Trying to read from environment but not set
let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
let config = Configuration.withCompanyKey(key) // Empty string!
```

✅ **Right:**
```swift
guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
      !key.isEmpty else {
    fatalError("ANTHROPIC_API_KEY not set")
}
let config = Configuration.withCompanyKey(key)
```

**Quick Fix:** Double-check your API key matches the provider and has no typos.

### "Missing API Key" Error

**Symptom:**
```
AIError.missingAPIKey(provider: .anthropic)
```

**Cause:** Using `clientKey` strategy but not providing a key:

❌ **Wrong:**
```swift
let config = Configuration.withClientKeys()
let gateway = AIGateway(configuration: config)

// No clientAPIKey provided!
let response = try await gateway.sendMessage(request)
```

✅ **Right:**
```swift
let config = Configuration.withClientKeys()
let gateway = AIGateway(configuration: config)

// Provide client key
let userKey = getUserAPIKey() // From user settings
let response = try await gateway.sendMessage(request, clientAPIKey: userKey)
```

**Learn more:** <doc:APIKeyManagement>

## Network Errors

### "Connection timeout" - Request Takes Too Long

**Symptom:**
```
AIError.networkError("Connection timeout")
```

**Causes:**

#### 1. Default Timeout Too Short for Large Requests

❌ **Wrong:**
```swift
let config = Configuration.withCompanyKey("sk-ant-...")
// Default 60 second timeout may be too short for large context
```

✅ **Right:**
```swift
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    timeout: 120  // 2 minutes for large requests
)
```

#### 2. Network Issues

**Quick Fix:**
- Check your internet connection
- Try again in a moment
- Implement retry logic (SwiftlyAIKit retries automatically for network errors)

### "Rate limit exceeded" Error

**Symptom:**
```
AIError.rateLimitExceeded(retryAfter: 60)
```

**Cause:** Too many requests to the provider

✅ **Solution:**
```swift
do {
    let response = try await gateway.sendMessage(request)
} catch AIError.rateLimitExceeded(let retryAfter) {
    print("Rate limited. Retry after \(retryAfter) seconds")

    // Wait and retry
    try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
    let response = try await gateway.sendMessage(request)
}
```

**Long-term fix:**
- Use `APIKeyStrategy.hybrid` to let users bring their own keys
- Implement exponential backoff
- Cache responses when possible
- Use batch processing for bulk requests

**Learn more:** <doc:PerformanceOptimization>

## Model Errors

### "Invalid model" Error

**Symptom:**
```
AIError.invalidModel(model: "gpt-5")
```

**Cause:** Model doesn't exist or typo in model name

❌ **Wrong:**
```swift
let request = AIRequest(model: .custom("gpt-5"), prompt: "Hello")
// GPT-5 doesn't exist yet!
```

✅ **Right:**
```swift
// Use defined model enums
let request = AIRequest(model: .gpt4(.turbo), prompt: "Hello")

// Or check the model exists
let request = AIRequest(model: .custom("gpt-4-turbo"), prompt: "Hello")
```

**Available models:** See <doc:ProvidersOverview> for complete model lists

### "Unsupported feature" Error

**Symptom:**
```
AIError.unsupportedFeature(feature: "tool calling", provider: .perplexity)
```

**Cause:** Provider doesn't support the requested feature

❌ **Wrong:**
```swift
// Perplexity doesn't support tool calling
let tools = [AITool(name: "search", ...)]
let request = AIRequest(
    model: .custom("sonar"),
    messages: [...],
    tools: tools  // Not supported!
)
let response = try await gateway.sendMessage(request, to: .perplexity)
```

✅ **Right:**
```swift
// Use a provider that supports tools
let tools = [AITool(name: "search", ...)]
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [...],
    tools: tools
)
let response = try await gateway.sendMessage(request, to: .anthropic)
```

**Feature support:** See <doc:ProvidersOverview> for feature comparison

## Request Errors

### Empty Response Content

**Symptom:** Response comes back but `message.content` is empty

```swift
let response = try await gateway.sendMessage(request)
print(response.message.content) // ""
```

**Causes:**

#### 1. Tool Call Response

```swift
// AI decided to call a tool instead of responding with text
if let toolCalls = response.toolCalls {
    // Handle tool calls
    for toolCall in toolCalls {
        // Execute tool and send result back
    }
}
```

**Learn more:** <doc:ToolCalling>

#### 2. Stop Reason Was Not Natural

```swift
if response.stopReason != .endTurn {
    switch response.stopReason {
    case .maxTokens:
        print("Response was cut off - increase maxTokens")
    case .stopSequence:
        print("Hit a stop sequence")
    default:
        break
    }
}
```

### "Context length exceeded" Error

**Symptom:**
```
AIError.validationError("Context length exceeded")
```

**Cause:** Your messages are too long for the model's context window

❌ **Wrong:**
```swift
// Trying to send 300K tokens to a 128K token model
let longConversation = [...] // 300K tokens
let request = AIRequest(model: .gpt4(.turbo), messages: longConversation)
```

✅ **Right:**
```swift
// Option 1: Use a model with larger context
let request = AIRequest(model: .gemini(.pro2_5), messages: longConversation)
// Gemini 2.5 Pro supports 2M tokens

// Option 2: Trim the conversation
let recentMessages = Array(longConversation.suffix(20))
let request = AIRequest(model: .gpt4(.turbo), messages: recentMessages)

// Option 3: Summarize older messages
let summary = try await summarizeOldMessages(longConversation)
let trimmedConversation = [summary] + recentMessages
```

**Context windows by model:**
- Gemini 2.5 Pro: 2M tokens
- Cohere Command R+: 256K tokens
- Claude 3.5 Sonnet: 200K tokens
- GPT-4 Turbo: 128K tokens

## Swift Concurrency Errors

### "Call can throw but is not marked with 'try'"

**Symptom:** Compiler error

```swift
let response = gateway.sendMessage(request) // ❌ Error!
```

✅ **Fix:** Add `try await`:
```swift
let response = try await gateway.sendMessage(request)
```

### "Expression is 'async' but is not marked with 'await'"

**Symptom:** Compiler error

```swift
let response = try gateway.sendMessage(request) // ❌ Error!
```

✅ **Fix:** Add `await`:
```swift
let response = try await gateway.sendMessage(request)
```

### "Cannot call mutating async function in a closure"

**Symptom:** Compiler error when using SwiftUI

❌ **Wrong:**
```swift
Button("Send") {
    let response = try await gateway.sendMessage(request) // ❌ Can't use await in non-async closure
}
```

✅ **Right:**
```swift
Button("Send") {
    Task {
        let response = try await gateway.sendMessage(request)
    }
}
```

**Learn more:** <doc:SwiftUIIntegration>

## Debugging Tips

### Enable Logging

See exactly what's being sent and received:

```swift
let config = Configuration.development(
    companyKey: "sk-ant-...",
    provider: .anthropic
)
// Enables verbose logging automatically

// Or configure manually
config.configureLogging(logLevel: .debug)
```

### Check Error Details

Print the full error for debugging:

```swift
do {
    let response = try await gateway.sendMessage(request)
} catch {
    print("Full error: \(error)")
    print("Error type: \(type(of: error))")

    if let aiError = error as? AIError {
        print("SwiftlyAIKit error: \(aiError)")
    }
}
```

### Verify Your Configuration

```swift
let gateway = AIGateway(configuration: config)

// Check which providers are registered
print("Registered providers: \(gateway.registeredProviders)")

// Check default provider
print("Default provider: \(gateway.config.defaultProvider)")
```

## Still Stuck?

If you're still having issues:

1. **Check the error handling guide:** <doc:ErrorHandling>
2. **Review the configuration guide:** <doc:ConfigurationSystem>
3. **Look at working examples:** <doc:SwiftUIIntegration>
4. **Search GitHub issues:** [github.com/Swiftly-Developed/SwiftlyAIKit/issues](https://github.com/Swiftly-Developed/SwiftlyAIKit/issues)
5. **Ask in discussions:** [github.com/Swiftly-Developed/SwiftlyAIKit/discussions](https://github.com/Swiftly-Developed/SwiftlyAIKit/discussions)

## See Also

- <doc:ErrorHandling>
- <doc:APIKeyManagement>
- <doc:PerformanceOptimization>
- <doc:MonitoringAndDebugging>
- ``AIError``
