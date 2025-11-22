# SwiftlyAIKit

A unified, server-side Swift framework for interacting with multiple AI model providers, built for Vapor applications.

## Features

- **Multi-Provider Support**: Seamlessly integrate with OpenAI, Anthropic, Google AI, Cohere, Mistral, and more
- **Flexible API Key Management**: Support for both company-provided and client-provided API keys
- **Vapor Integration**: Native support for Vapor web framework
- **Type-Safe**: Leveraging Swift's strong type system for safe AI interactions
- **Async/Await**: Built with modern Swift concurrency
- **Actor-Based**: Thread-safe gateway coordination using Swift actors

## Requirements

- Swift 6.2+
- macOS 13.0+
- Vapor 4.99.0+

## Installation

Add SwiftlyAIKit to your Package.swift dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/SwiftlyWorkspace/SwiftlyAIKit.git", from: "0.1.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SwiftlyAIKit", package: "SwiftlyAIKit")
    ]
)
```

## Quick Start

```swift
import Vapor
import SwiftlyAIKit

// Configure the AI gateway in your Vapor application
func configure(_ app: Application) async throws {
    // TODO: Configuration example will be added
}

// Use the gateway in your routes
func routes(_ app: Application) throws {
    app.get("ai", "chat") { req async throws -> AIResponse in
        // TODO: Usage example will be added
        return AIResponse()
    }
}
```

## Configuration

### API Key Strategies

SwiftlyAIKit supports multiple API key management strategies:

- **Company Keys**: Use your organization's API keys for all requests
- **Client Keys**: Allow clients to provide their own API keys
- **Hybrid**: Mix of both approaches based on configuration

Configuration details will be added as the framework is implemented.

## Supported Providers

- **OpenAI** - GPT models and completions
- **Anthropic** - Claude models
- **Google AI** - Gemini and PaLM models
- **Cohere** - Command and embedding models
- **Mistral AI** - Mistral models
- Additional providers can be added via the provider protocol

## Architecture

### Core Components

- **AIGateway**: Main actor that coordinates provider calls and manages configuration
- **Provider Protocol**: Defines the interface all AI providers must implement
- **Models**: Type-safe request/response structures for AI interactions
- **Extensions**: Vapor integration helpers for seamless framework usage

### Directory Structure

```
Sources/SwiftlyAIKit/
├── Models/          # Data models for requests, responses, and messages
├── Providers/       # Provider implementations (OpenAI, Anthropic, etc.)
├── Core/            # Gateway, configuration, and key management
├── Extensions/      # Vapor integration extensions
└── Utilities/       # HTTP client and JSON helpers
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
