# Migrating from OpenAI SDK

Switch from the official OpenAI SDK to SwiftlyAIKit.

## Overview

This guide shows you how to migrate from the official OpenAI Swift SDK to SwiftlyAIKit, highlighting:
- API differences
- Code changes required
- Benefits of switching
- Common migration issues

## Why Migrate?

**Benefits of SwiftlyAIKit:**
- ✅ **Multi-provider support** - Not locked into OpenAI
- ✅ **Simpler API** - More intuitive interface
- ✅ **Better error handling** - Typed errors
- ✅ **Server integration** - SwiftlyAIServerKit for Vapor
- ✅ **Unified streaming** - Consistent across providers
- ✅ **Active development** - Regular updates

## Installation Changes

### Before (OpenAI SDK)

```swift
dependencies: [
    .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.0")
]
```

### After (SwiftlyAIKit)

```swift
dependencies: [
    .package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.10.0")
]
```

## Code Migration

### Basic Chat

**Before:**
```swift
import OpenAI

let openAI = OpenAI(apiToken: "sk-...")

let query = ChatQuery(
    messages: [
        .init(role: .system, content: "You are a helpful assistant"),
        .init(role: .user, content: "Hello!")
    ],
    model: .gpt4_o
)

let result = try await openAI.chats(query: query)
let response = result.choices.first?.message.content?.string
```

**After:**
```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .gpt4(.o),
    systemPrompt: "You are a helpful assistant",
    messages: [.user("Hello!")]
)

let response = try await gateway.sendMessage(request, to: .openai)
let content = response.message.content
```

### Streaming

**Before:**
```swift
let query = ChatQuery(messages: messages, model: .gpt4_o)

for try await result in openAI.chatsStream(query: query) {
    if let content = result.choices.first?.delta.content {
        print(content, terminator: "")
    }
}
```

**After:**
```swift
let request = AIRequest(model: .gpt4(.o), messages: messages)

let stream = try await gateway.streamMessage(request, to: .openai)

for try await chunk in stream {
    print(chunk.message.content, terminator: "")
}
```

### Vision

**Before:**
```swift
let query = ChatQuery(
    messages: [
        .init(role: .user, content: [
            .text("What's in this image?"),
            .imageUrl(URL(string: imageURL)!)
        ])
    ],
    model: .gpt4_o
)

let result = try await openAI.chats(query: query)
```

**After:**
```swift
let request = AIRequest(
    model: .gpt4(.o),
    messages: [
        .user([
            .text("What's in this image?"),
            .image(url: imageURL)
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .openai)
```

### Image Generation (DALL-E)

**Before:**
```swift
let query = ImagesQuery(
    prompt: "A sunset",
    model: .dall_e_3,
    size: "1024x1024"
)

let result = try await openAI.images(query: query)
let imageURL = result.data.first?.url
```

**After:**
```swift
let request = ImageGenerationRequest.dallE3(
    prompt: "A sunset",
    size: .square1024
)

let response = try await gateway.generateImage(request, using: .openai)
let imageURL = response.images.first?.url
```

## API Mapping

### Models

| OpenAI SDK | SwiftlyAIKit |
|------------|--------------|
| `.gpt4_o` | `.gpt4(.o)` |
| `.gpt4_o_mini` | `.gpt4(.oMini)` |
| `.gpt4_turbo` | `.gpt4(.turbo)` |
| `.gpt35_turbo` | `.gpt35(.turbo)` |

### Message Roles

| OpenAI SDK | SwiftlyAIKit |
|------------|--------------|
| `.system` | System prompt (separate parameter) |
| `.user` | `.user("text")` |
| `.assistant` | `.assistant("text")` |
| `.tool` | `.tool(name: "...", content: "...")` |

### Parameters

| OpenAI SDK | SwiftlyAIKit |
|------------|--------------|
| `temperature` | `temperature` ✓ |
| `maxTokens` | `maxTokens` ✓ |
| `topP` | `topP` ✓ |
| `stop` | `stopSequences` |
| `responseFormat` | `responseFormat` ✓ |

## Migration Checklist

- [ ] Replace OpenAI SDK dependency with SwiftlyAIKit
- [ ] Update import statements
- [ ] Replace OpenAI client with AIGateway
- [ ] Convert ChatQuery to AIRequest
- [ ] Update model names
- [ ] Convert system messages to systemPrompt
- [ ] Update streaming code
- [ ] Update error handling
- [ ] Test thoroughly

## Benefits After Migration

### Multi-Provider Support

Now you can easily switch providers:

```swift
// Same request works with any provider!
let request = AIRequest(model: .custom("model"), prompt: "Hello")

let openaiResponse = try await gateway.sendMessage(request, to: .openai)
let claudeResponse = try await gateway.sendMessage(request, to: .anthropic)
let geminiResponse = try await gateway.sendMessage(request, to: .google)
```

### Better Error Handling

```swift
// Before: Generic errors
catch {
    print("Error: \(error)")
}

// After: Typed errors
catch AIError.authenticationFailed(let provider) {
    print("Bad API key for \(provider)")
} catch AIError.rateLimitExceeded(let retryAfter) {
    print("Rate limited. Retry after \(retryAfter)s")
}
```

### Server Integration

```swift
// SwiftlyAIKit includes Vapor integration
import SwiftlyAIServerKit

try app.ai.initialize(with: config)

app.post("chat") { req async throws in
    try await req.ai.sendMessage(request)
}
```

## Common Migration Issues

### Issue 1: System Messages

OpenAI SDK uses system role in messages array. SwiftlyAIKit uses separate parameter:

**Before:**
```swift
messages: [
    .init(role: .system, content: "You are helpful"),
    .init(role: .user, content: "Hello")
]
```

**After:**
```swift
systemPrompt: "You are helpful",
messages: [.user("Hello")]
```

### Issue 2: Response Structure

**Before:**
```swift
let content = result.choices.first?.message.content?.string
```

**After:**
```swift
let content = response.message.content
```

### Issue 3: Streaming Deltas

**Before:**
```swift
result.choices.first?.delta.content
```

**After:**
```swift
chunk.message.content
```

## See Also

- <doc:OpenAIGuide>
- <doc:QuickStart>
- <doc:ProvidersOverview>
- ``AIGateway``
- ``AIRequest``
