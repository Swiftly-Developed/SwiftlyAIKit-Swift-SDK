# SwiftlyAIKit

> **Setup 1: Direct Access**
>
> This package provides direct AI provider access. Developers manage their own API keys.
> No monetization or usage tracking. For monetized access, see SwiftlyAIClient.

Core AI gateway framework providing unified access to 9 AI providers through a single Swift API. Works on iOS, macOS, watchOS, tvOS, visionOS, and Linux servers.

## Structure

```
SwiftlyAIKit/Sources/SwiftlyAIKit/
├── Core/           # AIGateway, Configuration, APIKeyStrategy, ProviderProtocol
├── Models/         # AIRequest, AIResponse, AIMessage, AIError
├── Providers/      # Provider implementations (Anthropic, OpenAI, Gemini, etc.)
└── Utilities/      # HTTPClientManager with retry logic, Logger with aiLog()
```

## Providers

- **Anthropic** - Claude models with Messages API, Batch API, streaming, vision, PDF
- **OpenAI** - GPT models with Chat Completions API, streaming, vision
- **Google Gemini** - Gemini models with GenerateContent API, streaming, multimodal
- **Perplexity** - Sonar models with web search, citations, domain filtering
- **Mistral** - Mistral models with streaming, vision, tool calling
- **Cohere** - Command models with RAG, citations, safety modes
- **DeepSeek** - DeepSeek models with reasoning mode, prompt caching
- **xAI Grok** - Grok models with live web search, image generation
- **Apple Intelligence** - On-device AI via Foundation Models

## Core Components

- **AIGateway** - Main coordinator actor routing requests to providers
- **Configuration** - Builder pattern with `.withCompanyKey()`, `.withClientKeys()`, `.withHybridKeys()`
- **ProviderProtocol** - Interface all providers must implement
- **HTTPClientManager** - Actor-based HTTP client with retry logic, error mapping, and structured logging via `aiLog()`

## When to Use SwiftlyAIKit

Use SwiftlyAIKit (Setup 1) when you want to:
- Manage your own AI provider API keys
- Avoid SwiftlyAI Cloud dependency
- Run completely self-hosted infrastructure
- Build internal tools or prototypes

### For Monetized Access

See **SwiftlyAIClient** for:
- **Setup 2**: Cloud Direct (App → SwiftlyAI Cloud) - Recommended for most apps
- **Setup 3**: Cloud via Server (App → Your Server → Cloud) - Enterprise/custom logic

## Usage

```swift
import SwiftlyAIKit

// Direct provider access - no SwiftlyAI Cloud
let config = Configuration.withCompanyKey("sk-ant-...")
let gateway = AIGateway(configuration: config)

// Send a message
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello!")
let response = try await gateway.sendMessage(request)

// Streaming
let stream = try await gateway.streamMessage(request)
for try await chunk in stream {
    print(chunk.content)
}
```

## Where to Look

| For... | See... |
|--------|--------|
| Main gateway logic | `Core/AIGateway.swift` |
| Configuration setup | `Core/Configuration.swift` |
| API key strategies | `Core/APIKeyStrategy.swift` |
| Provider interface | `Core/ProviderProtocol.swift` |
| Request/response types | `Models/AIRequest.swift`, `Models/AIResponse.swift` |
| Anthropic implementation | `Providers/Anthropic/AnthropicProvider.swift` |
| OpenAI implementation | `Providers/OpenAI/OpenAIProvider.swift` |
| Gemini implementation | `Providers/Gemini/GeminiProvider.swift` |
| HTTP client | `Utilities/HTTPClientManager.swift` |
| Adding new providers | `Documentation/` folder for implementation plans |
| **For monetized access** | **SwiftlyAIClient package** |
| **For server integration** | **SwiftlyAIVapor or SwiftlyAIHummingbird** |

## Code Quality

SwiftLint runs on every build via the `SwiftLintBuildToolPlugin`. Configuration is inherited from the workspace root via `parent_config` in `.swiftlint.yml`. See the workspace `AGENTS.md` for rules and guidelines.

## Dependencies

- AsyncHTTPClient 1.19.0+

**Note:** This package has zero Vapor dependencies. For Vapor integration, see SwiftlyAIServerKit.
