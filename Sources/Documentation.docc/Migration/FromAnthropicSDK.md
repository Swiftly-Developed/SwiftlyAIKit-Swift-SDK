# Migrating from Anthropic SDK

Switch from the official Anthropic SDK to SwiftlyAIKit.

## Overview

Migrate from the official Anthropic Swift SDK to gain:
- Multi-provider support
- Unified API across providers
- Better error handling
- Server integration

## Installation Changes

### Before (Anthropic SDK)

```swift
dependencies: [
    .package(url: "https://github.com/anthropics/anthropic-sdk-swift", from: "0.1.0")
]
```

### After (SwiftlyAIKit)

```swift
dependencies: [
    .package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.10.0")
]
```

## Code Migration

### Basic Message

**Before:**
```swift
import Anthropic

let client = Anthropic(apiKey: "sk-ant-...")

let message = try await client.messages.create(
    model: "claude-3-5-sonnet-20241022",
    messages: [.init(role: .user, content: "Hello")],
    maxTokens: 1024
)

let response = message.content.first?.text
```

**After:**
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
let content = response.message.content
```

### Streaming

**Before:**
```swift
for try await event in client.messages.stream(
    model: "claude-3-5-sonnet-20241022",
    messages: messages,
    maxTokens: 1024
) {
    if case .contentBlockDelta(let delta) = event {
        print(delta.delta.text, terminator: "")
    }
}
```

**After:**
```swift
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: messages,
    maxTokens: 1024
)

let stream = try await gateway.streamMessage(request, to: .anthropic)

for try await chunk in stream {
    print(chunk.message.content, terminator: "")
}
```

## Benefits After Migration

### Switch to Any Provider

```swift
// Same code works with GPT, Gemini, etc.
let response = try await gateway.sendMessage(request, to: .openai)
let response2 = try await gateway.sendMessage(request, to: .google)
```

### Better Error Types

```swift
catch AIError.rateLimitExceeded(let retryAfter) {
    print("Retry after \(retryAfter)s")
}
```

### Server Integration

```swift
import SwiftlyAIServerKit

try app.ai.initialize(with: config)
```

## See Also

- <doc:AnthropicGuide>
- <doc:QuickStart>
- ``AIGateway``
