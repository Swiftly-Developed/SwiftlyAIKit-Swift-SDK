# SwiftlyAIKit

Unified AI provider SDK for Swift - works everywhere Swift runs.

## Overview

SwiftlyAIKit provides a single, elegant API for calling 9 major AI providers:
**Anthropic Claude**, **OpenAI GPT**, **Google Gemini**, **Perplexity**, **Mistral AI**, **Cohere**, **DeepSeek**, **xAI Grok**, and **Apple Intelligence**.

Write once, switch providers with a single parameter. Works on iOS, macOS, watchOS, tvOS, visionOS, and Linux servers.

### Why SwiftlyAIKit?

- **🎯 Single API** - One interface for all providers
- **🔄 Easy Switching** - Change providers without rewriting code
- **⚡ Streaming Built-in** - Real-time responses like ChatGPT
- **🔒 Flexible Security** - Multiple API key management strategies
- **🎨 SwiftUI Ready** - Native async/await integration
- **🌍 Cross-Platform** - iOS to Linux, one codebase

### Provider Comparison

| Provider | Context | Streaming | Tools | Vision | Best For |
|----------|---------|-----------|-------|--------|----------|
| **Anthropic Claude** | 200K | ✓ | ✓ | ✓ | Complex reasoning, long context |
| **OpenAI GPT-4** | 128K | ✓ | ✓ | ✓ | General purpose, wide adoption |
| **Google Gemini** | 2M | ✓ | ✓ | ✓ | Massive context, multimodal |
| **Perplexity** | 127K | ✓ | - | - | Web search, citations |
| **Mistral AI** | 128K | ✓ | ✓ | ✓ | EU-hosted, cost-effective |
| **Cohere** | 256K | ✓ | ✓ | ✓ | RAG optimization, enterprise |
| **DeepSeek** | 64K | ✓ | ✓ | - | Cost optimization, reasoning |
| **xAI Grok** | 128K | ✓ | ✓ | ✓ | Real-time data, image generation |
| **Apple Intelligence** | - | ✓ | - | - | On-device privacy, no network |

## Get Started in 5 Minutes

Choose your path:
- 🚀 ``QuickStart`` - First AI call in 5 minutes
- 📱 <doc:SwiftUIIntegration> - Build a chat app
- 🖥️ <doc:VaporIntegration> - Server-side AI

### Installation

Add SwiftlyAIKit to your Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.10.0")
]
```

### Your First AI Call

```swift
import SwiftlyAIKit

// Configure with your API key
let config = Configuration.withCompanyKey("sk-ant-...")
let gateway = AIGateway(configuration: config)

// Send a message
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello!")
let response = try await gateway.sendMessage(request)
print(response.message.content)
```

### Switch Providers Instantly

```swift
// Use Claude
let claudeResponse = try await gateway.sendMessage(request, to: .anthropic)

// Use GPT-4
let gptResponse = try await gateway.sendMessage(request, to: .openai)

// Use Gemini
let geminiResponse = try await gateway.sendMessage(request, to: .google)
```

## Topics

### Essentials (New Users)
- <doc:QuickStart>
- <doc:UnderstandingYourFirstCall>
- <doc:CommonPitfalls>
- <doc:ChoosingAProvider>

### Core API (Technical Reference)
- ``AIGateway``
- ``Configuration``
- ``AIRequest``
- ``AIResponse``
- ``AIMessage``
- ``AIError``

### Providers (Technical Reference)
- <doc:ProvidersOverview>
- ``AnthropicProvider``
- ``OpenAIProvider``
- ``GeminiProvider``
- ``PerplexityProvider``
- ``MistralProvider``
- ``CohereProvider``
- ``DeepSeekProvider``
- ``GrokProvider``
- ``AppleIntelligenceProvider``

### Provider Guides (In-Depth Documentation)
- <doc:AnthropicGuide>
- <doc:OpenAIGuide>
- <doc:GeminiGuide>
- <doc:PerplexityGuide>
- <doc:MistralGuide>
- <doc:CohereGuide>
- <doc:DeepSeekGuide>
- <doc:GrokGuide>
- <doc:AppleIntelligenceGuide>

### Core Concepts (Essential Knowledge)
- <doc:ErrorHandling>
- <doc:StreamingResponses>
- <doc:APIKeyManagement>
- <doc:ConfigurationSystem>

### Advanced Features (Power Users)
- <doc:ToolCalling>
- <doc:ImageGeneration>
- <doc:PromptCaching>
- <doc:BatchProcessing>
- <doc:VisionAndImageAnalysis>
- <doc:RAGOptimization>

### Platform Integration (Build Apps)
- <doc:SwiftUIIntegration>
- <doc:UIKitIntegration>
- <doc:VaporIntegration>
- <doc:CommandLineTools>
- <doc:WatchOSIntegration>

### Production Deployment (Ship It)
- <doc:ChoosingDeploymentPattern>
- <doc:PerformanceOptimization>
- <doc:MonitoringAndDebugging>
- <doc:Testing>
- <doc:ProductionChecklist>

### Architecture (Deep Dive)
- <doc:ArchitectureOverview>
- ``ProviderProtocol``
- <doc:ActorConcurrency>
- <doc:ExtensibilityPoints>

### Migration Guides
- <doc:FromOpenAISDK>
- <doc:FromAnthropicSDK>
- <doc:VersionMigration>

## Featured Examples

### Streaming Chat (Like ChatGPT)

```swift
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Write a story")
let stream = try await gateway.streamMessage(request)

for try await chunk in stream {
    print(chunk.message.content, terminator: "")
}
```

### Tool Calling (Function Integration)

```swift
let tools = [
    AITool(
        name: "get_weather",
        description: "Get current weather",
        parameters: [
            "location": .string(description: "City name")
        ]
    )
]

let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("What's the weather in Tokyo?")],
    tools: tools
)

let response = try await gateway.sendMessage(request)
if let toolCall = response.toolCalls?.first {
    // Handle tool call
}
```

### Image Generation

```swift
let request = ImageGenerationRequest.dallE3(
    prompt: "A sunset over mountains",
    size: .square1024,
    quality: .hd
)

let response = try await gateway.generateImage(request)
for image in response.images {
    // Display image.url or image.data
}
```

### Vision (Analyze Images)

```swift
let request = AIRequest(
    model: .gpt4(.vision),
    messages: [
        .user([
            .text("What's in this image?"),
            .image(url: "https://example.com/image.jpg")
        ])
    ]
)

let response = try await gateway.sendMessage(request)
print(response.message.content) // Description of the image
```

## Deployment Patterns

SwiftlyAIKit supports three deployment patterns for maximum flexibility:

### Pattern 1: Client → Server → Providers (Recommended for Production)

```
iOS/macOS App (SwiftlyAIClient)
  └─> Your Vapor Server (SwiftlyAIServerKit + SwiftlyAIVapor)
       └─> AI Providers
```

**Benefits:** API key security, rate limiting, centralized tracking
**Packages:** SwiftlyAIClient + SwiftlyAIServerKit + SwiftlyAIVapor
**Guide:** <doc:ChoosingDeploymentPattern>

### Pattern 2: Client → Providers (Direct Access)

```
iOS/macOS App (SwiftlyAIKit)
  └─> AI Providers
```

**Benefits:** Simpler architecture, no server needed
**Drawbacks:** API keys on device, no centralized control
**Packages:** SwiftlyAIKit only
**Guide:** <doc:ChoosingDeploymentPattern>

### Pattern 3: Hybrid - Local + Server

```
iOS/macOS App (SwiftlyAIClient)
  ├─> Apple Intelligence (on-device, no network)
  └─> Your Vapor Server (cloud providers)
```

**Benefits:** Privacy-first local AI + powerful cloud AI
**Packages:** SwiftlyAIClient (includes SwiftlyAIKit)
**Guide:** <doc:ChoosingDeploymentPattern>

## Community & Support

- **GitHub:** [github.com/Swiftly-Developed/SwiftlyAIKit](https://github.com/Swiftly-Developed/SwiftlyAIKit)
- **Issues:** Report bugs and request features
- **Discussions:** Ask questions and share ideas
- **Changelog:** <doc:VersionMigration>

## License

SwiftlyAIKit is released under the MIT License. See LICENSE for details.
