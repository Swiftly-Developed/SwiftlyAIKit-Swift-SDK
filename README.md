# SwiftlyAIKit

A unified, cross-platform Swift framework for interacting with multiple AI model providers. Use it in your Vapor server, iOS app, macOS app, or any Swift application.

## Features

- **Multi-Provider Support**: Seamlessly integrate with OpenAI, Anthropic, Google AI, Cohere, Mistral, DeepSeek, and more
- **Cross-Platform**: Works on iOS, macOS, watchOS, tvOS, visionOS, and server-side Swift
- **Flexible API Key Management**: Support for both company-provided and client-provided API keys
- **Optional Vapor Integration**: Use standalone or with native Vapor support via separate target
- **Type-Safe**: Leveraging Swift's strong type system for safe AI interactions
- **Async/Await**: Built with modern Swift concurrency
- **Actor-Based**: Thread-safe gateway coordination using Swift actors

## Requirements

- Swift 6.2+
- **Platform Support:**
  - iOS 16.0+
  - macOS 13.0+
  - watchOS 9.0+
  - tvOS 16.0+
  - visionOS 1.0+
  - Linux (server-side)
- Vapor 4.99.0+ (optional, only required for `SwiftlyAIKitVapor` target)

## Installation

Add SwiftlyAIKit to your Package.swift dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/SwiftlyWorkspace/SwiftlyAIKit.git", from: "0.1.0")
]
```

### For Device Apps (iOS, macOS, watchOS, tvOS, visionOS)

Use the core `SwiftlyAIKit` target without Vapor dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "SwiftlyAIKit", package: "SwiftlyAIKit")
    ]
)
```

### For Vapor Server Applications

Use the `SwiftlyAIKitVapor` target which includes Vapor integration:

```swift
.target(
    name: "YourVaporApp",
    dependencies: [
        .product(name: "SwiftlyAIKitVapor", package: "SwiftlyAIKit"),
        .product(name: "Vapor", package: "vapor")
    ]
)
```

## Quick Start

### Using SwiftlyAIKit in Device Apps

```swift
import SwiftlyAIKit

// Initialize the AI gateway
let config = Configuration.withCompanyKey("sk-ant-api03-...")
let gateway = AIGateway(configuration: config)

// Send a message
let request = AIRequest(
    model: "claude-sonnet-4-5",
    messages: [AIMessage(role: .user, content: [.text("Hello!")])]
)

let response = try await gateway.sendMessage(request)
print(response.message.content)

// Stream a message
let stream = gateway.streamMessage(request)
for try await chunk in stream {
    if let text = chunk.message.content.first?.text {
        print(text, terminator: "")
    }
}
```

### Using SwiftlyAIKit with Vapor

```swift
import Vapor
import SwiftlyAIKitVapor

// Configure the AI gateway in your Vapor application
func configure(_ app: Application) async throws {
    // Option 1: Company key strategy (simplest - use your own API keys)
    let config = Configuration.withCompanyKey("sk-ant-api03-...")
    app.ai.initialize(with: config)

    // Option 2: Client key strategy (clients provide their own keys)
    // let config = Configuration.withClientKeys()
    // app.ai.initialize(with: config)

    // Option 3: Hybrid strategy (fallback to company key if client doesn't provide one)
    // let config = Configuration.withHybridKeys(defaultKey: "sk-ant-api03-...")
    // app.ai.initialize(with: config)
}

// Use the gateway in your routes
func routes(_ app: Application) throws {
    // Basic chat completion
    app.post("ai", "chat") { req async throws -> AIResponse in
        struct ChatRequest: Content {
            let model: String
            let prompt: String
        }

        let input = try req.content.decode(ChatRequest.self)
        let aiRequest = AIRequest(
            model: input.model,
            messages: [AIMessage(role: .user, content: [.text(input.prompt)])]
        )

        // Automatically uses client API key from X-API-Key header if present
        return try await req.ai.sendMessage(aiRequest)
    }

    // Streaming response
    app.post("ai", "stream") { req async throws -> Response in
        let aiRequest = AIRequest(
            model: "claude-sonnet-4-5",
            messages: [AIMessage(role: .user, content: [.text("Tell me a story")])]
        )
        return try await req.ai.streamMessage(aiRequest)
    }
}
```

## Configuration

### API Key Strategies

SwiftlyAIKit supports three API key management strategies:

#### 1. Company Key Strategy (Recommended for Single-Tenant)
Use your organization's API keys for all requests. Simplest setup.

```swift
let config = Configuration.withCompanyKey("sk-ant-api03-...")
app.ai.initialize(with: config)
```

**Use when:** You control all AI usage and want centralized billing.

#### 2. Client Key Strategy (Multi-Tenant)
Clients provide their own API keys via the `X-API-Key` header.

```swift
let config = Configuration.withClientKeys()
app.ai.initialize(with: config)
```

**Use when:** Each client has their own AI provider accounts.

#### 3. Hybrid Strategy (Recommended for Production)
Fallback to company key if client doesn't provide one.

```swift
let config = Configuration.withHybridKeys(defaultKey: "sk-ant-api03-...")
app.ai.initialize(with: config)
```

**Use when:** You want flexibility - some clients use their keys, others use yours.

## Supported Providers

- **OpenAI** - GPT models and completions
- **Anthropic** - Claude models with extended thinking and prompt caching
- **Google AI** - Gemini models with multimodal support
- **Cohere** - Command models with RAG and citations
- **Mistral AI** - Mistral models with reasoning mode
- **DeepSeek** - DeepSeek Chat and Reasoner models with prompt caching
- **Perplexity** - Sonar models with real-time web search
- Additional providers can be added via the provider protocol

## Architecture

### Core Components

- **AIGateway**: Main actor that coordinates provider calls and manages configuration
- **Provider Protocol**: Defines the interface all AI providers must implement
- **Models**: Type-safe request/response structures for AI interactions
- **Vapor Extensions**: Optional Vapor integration helpers (separate target)

### Multi-Target Structure

SwiftlyAIKit uses a modular architecture with two targets:

**SwiftlyAIKit (Core Target)**
- Platform-agnostic AI gateway
- All provider implementations
- No Vapor dependencies
- Works on iOS, macOS, watchOS, tvOS, visionOS, Linux

**SwiftlyAIKitVapor (Vapor Extensions)**
- Vapor-specific integration
- Request/Application extensions
- Requires Vapor 4.99.0+
- Server-side only

### Directory Structure

```
Sources/
├── SwiftlyAIKit/           # Core framework (no Vapor)
│   ├── Models/             # Data models for requests, responses, and messages
│   ├── Providers/          # Provider implementations (OpenAI, Anthropic, etc.)
│   ├── Core/               # Gateway, configuration, and key management
│   └── Utilities/          # HTTP client and JSON helpers
└── SwiftlyAIKitVapor/      # Vapor integration (separate target)
    ├── Application+AI.swift  # App lifecycle extensions
    └── Request+AI.swift      # Request helpers
```

## API Documentation

Comprehensive API documentation will be generated using DocC and published as the framework matures.

## Testing

Run the test suite:

```bash
swift test
```

Run specific tests:

```bash
swift test --filter SwiftlyAIKitTests.<TestName>
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

- Follow Swift API Design Guidelines
- Use async/await for asynchronous operations
- Maintain thread-safety with actors where appropriate
- Add tests for new functionality
- Document public APIs with DocC-style comments

## License

SwiftlyAIKit is available under the MIT license. See the LICENSE file for more info.

## Roadmap

The following features are planned for future releases:

- [ ] Complete provider implementations for all supported services
- [ ] Streaming response support
- [ ] Rate limiting and retry logic
- [ ] Caching layer for responses
- [ ] Metrics and monitoring integration
- [ ] Example Vapor application
- [ ] Comprehensive API documentation
- [ ] Performance benchmarks
