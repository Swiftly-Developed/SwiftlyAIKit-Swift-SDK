# SwiftlyAIKit

A unified, cross-platform Swift framework for interacting with multiple AI model providers. Use it in your iOS app, macOS app, server, or any Swift application.

## Features

- **9 AI Providers**: Anthropic Claude, OpenAI GPT, Google Gemini, Perplexity, Mistral, Cohere, DeepSeek, xAI Grok, Apple Intelligence
- **Cross-Platform**: iOS, macOS, watchOS, tvOS, visionOS, and Linux
- **Streaming**: Server-Sent Events (SSE) for real-time responses
- **Vision**: Image analysis support (OpenAI, Gemini, Mistral, Cohere, Grok)
- **Tool Calling**: Function calling support (OpenAI, Gemini, Mistral, Cohere, DeepSeek, Grok)
- **Token Counting**: Usage tracking (Anthropic, Gemini, Cohere, Grok)
- **Web Search**: Real-time search with citations (Perplexity, Grok)
- **Prompt Caching**: Cost reduction (Anthropic, DeepSeek, Grok)
- **Reasoning Mode**: Extended thinking (DeepSeek, Mistral, Grok)
- **Image Generation**: AI image creation (Grok)
- **Batch Processing**: Async batch operations (Anthropic)
- **RAG Support**: Retrieval with citations (Cohere)
- **Swift 6**: Full strict concurrency with actor-based design
- **Type-Safe**: Strong typing for all AI interactions

## Requirements

- Swift 6.0+
- iOS 16.0+ / macOS 13.0+ / watchOS 9.0+ / tvOS 16.0+ / visionOS 1.0+ / Linux

## Installation

Add SwiftlyAIKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.10.0")
]
```

Add to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "SwiftlyAIKit", package: "SwiftlyAIKit")
    ]
)
```

> **Note:** For server-side integration (Vapor or Hummingbird), use [SwiftlyAIServerKit](https://github.com/Swiftly-Developed/SwiftlyAIServerKit) which provides server-specific extensions and helpers.

## Quick Start

### Basic Usage

```swift
import SwiftlyAIKit

// Create gateway with your API key
let config = Configuration.withCompanyKey("sk-ant-...")
let gateway = AIGateway(configuration: config)

// Send a message
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [AIMessage(role: .user, content: [.text("Hello!")])]
)
let response = try await gateway.sendMessage(request)
print(response.content)
```

### Streaming

```swift
let stream = try await gateway.streamMessage(request)
for try await chunk in stream {
    print(chunk.content, terminator: "")
}
```

### Using Different Providers

```swift
// OpenAI
let openAIRequest = AIRequest(
    model: .openai(.gpt4o),
    messages: [AIMessage(role: .user, content: [.text("Hello!")])]
)

// Google Gemini
let geminiRequest = AIRequest(
    model: .gemini(.pro2_5),
    messages: [AIMessage(role: .user, content: [.text("Hello!")])]
)

// xAI Grok
let grokRequest = AIRequest(
    model: .grok(.grok3),
    messages: [AIMessage(role: .user, content: [.text("Hello!")])]
)
```

### Vision (Image Analysis)

```swift
let visionRequest = AIRequest(
    model: .openai(.gpt4o),
    messages: [
        AIMessage(role: .user, content: [
            .text("What's in this image?"),
            .image(url: "https://example.com/image.jpg")
        ])
    ]
)
```

### Tool Calling

```swift
let tools = [
    AITool(
        name: "get_weather",
        description: "Get current weather for a location",
        parameters: AIToolParameters(
            properties: [
                "location": AIToolProperty(type: "string", description: "City name")
            ],
            required: ["location"]
        )
    )
]

let toolRequest = AIRequest(
    model: .openai(.gpt4o),
    messages: [AIMessage(role: .user, content: [.text("What's the weather in Paris?")])],
    tools: tools,
    toolChoice: .auto
)
```

## Configuration

### API Key Strategies

```swift
// Single key for all providers
let config = Configuration.withCompanyKey("sk-ant-...")

// Per-provider keys
let config = Configuration.withPerProviderKeys([
    .anthropic: "sk-ant-...",
    .openai: "sk-...",
    .google: "AIza...",
    .grok: "xai-..."
])

// Client-provided keys (for multi-tenant apps)
let config = Configuration.withClientKeys()

// Hybrid: fallback to company key if client doesn't provide one
let config = Configuration.withHybridKeys(defaultKey: "sk-ant-...")
```

## Supported Providers

| Provider | Models | Features |
|----------|--------|----------|
| **Anthropic** | Claude 4, Sonnet 4.5, Haiku | Streaming, Vision, Tools, Batch, Caching |
| **OpenAI** | GPT-4o, GPT-4 Turbo, GPT-3.5 | Streaming, Vision, Tools |
| **Google Gemini** | 2.5 Pro, 2.5 Flash, 1.5 Pro | Streaming, Vision, Tools, Token Count |
| **Perplexity** | Sonar, Sonar Pro, Reasoning | Streaming, Web Search, Citations |
| **Mistral** | Large 2.1, Medium 3, Small 3.1 | Streaming, Vision, Tools, Reasoning |
| **Cohere** | Command A, Command R | Streaming, Vision, Tools, RAG, Token Count |
| **DeepSeek** | Chat, Coder, R1 | Streaming, Tools, Caching, Reasoning |
| **xAI Grok** | Grok 4, Grok 3, Vision | Streaming, Vision, Tools, Web Search, Images |
| **Apple Intelligence** | Foundation Models | On-device, Privacy-first, No API key needed |

## Architecture

```
Sources/SwiftlyAIKit/
├── Core/           # AIGateway, Configuration, APIKeyStrategy, ProviderProtocol
├── Models/         # AIRequest, AIResponse, AIMessage, AIError, AITool
├── Providers/      # 9 provider implementations
│   ├── Anthropic/
│   ├── OpenAI/
│   ├── Gemini/
│   ├── Perplexity/
│   ├── Mistral/
│   ├── Cohere/
│   ├── DeepSeek/
│   ├── Grok/
│   └── Apple/     # Apple Intelligence (on-device)
└── Utilities/      # HTTPClientManager with retry logic
```

## Testing

```bash
swift build            # Build
swift test             # Run all 520+ tests
swift test --filter SwiftlyAIKitTests.AIGatewayTests  # Run specific tests
```

## Related Packages

- **[SwiftlyAIServerKit](https://github.com/Swiftly-Developed/SwiftlyAIServerKit)** - Vapor server integration
- **[SwiftlyAIClient](https://github.com/Swiftly-Developed/SwiftlyAIClient)** - iOS/macOS SDK for your server
- **[SwiftlyAIVapor](https://github.com/Swiftly-Developed/SwiftlyAIVapor)** - Pre-built Vapor routes and middleware
- **[SwiftlyAIHummingbird](https://github.com/Swiftly-Developed/SwiftlyAIHummingbird)** - Hummingbird integration

## License

MIT License. See LICENSE file for details.
