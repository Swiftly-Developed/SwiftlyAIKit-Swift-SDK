# Architecture Overview

Understand how SwiftlyAIKit is designed and structured.

## Overview

SwiftlyAIKit follows a clean, modular architecture built on Swift 6 concurrency primitives. The framework is organized into layers, each with specific responsibilities.

## System Architecture

```
┌─────────────────────────────────────────────┐
│           Your Application                   │
│  (iOS, macOS, watchOS, tvOS, Linux server)  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           AIGateway (Actor)                  │
│  • Routes requests to providers              │
│  • Resolves API keys                         │
│  • Handles errors and retries               │
│  • Manages provider registry                │
└──────────────────┬──────────────────────────┘
                   │
         ┌─────────┼─────────┐
         ▼         ▼         ▼
    ┌────────┐ ┌────────┐ ┌────────┐
    │Anthropic│ │OpenAI  │ │ Gemini │ ...
    │Provider │ │Provider│ │Provider│
    └────┬────┘ └────┬───┘ └────┬───┘
         │           │          │
         ▼           ▼          ▼
    ┌──────────────────────────────┐
    │   HTTPClientManager (Actor)   │
    │  • Makes HTTP requests        │
    │  • Handles retries            │
    │  • Parses SSE streams         │
    └──────────────┬────────────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │  AI Provider APIs    │
         │  (Anthropic, OpenAI,│
         │   Google, etc.)     │
         └─────────────────────┘
```

## Core Components

### AIGateway (Coordinator)

The ``AIGateway`` is an actor that coordinates all AI operations:

**Responsibilities:**
- Accept ``AIRequest`` from your app
- Resolve which provider to use
- Resolve which API key to use
- Route to appropriate ``ProviderProtocol`` implementation
- Return ``AIResponse`` to your app

**Why an actor?**
- Thread-safe by design
- No data races
- Safe for concurrent access
- Swift 6 compliant

**Example:**
```swift
public actor AIGateway {
    private let configuration: Configuration
    private var providers: [ProviderType: ProviderProtocol]

    public func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        // 1. Determine provider
        let providerType = configuration.defaultProvider

        // 2. Resolve API key
        let apiKey = try resolveAPIKey(for: providerType)

        // 3. Get provider implementation
        let provider = try getProvider(providerType)

        // 4. Execute request
        return try await provider.sendMessage(request, apiKey: apiKey)
    }
}
```

### Configuration (Settings)

The ``Configuration`` struct holds all framework settings:

**Immutable by design:**
- Create once
- Reuse throughout app lifecycle
- Thread-safe (value type)
- No hidden state

**Example:**
```swift
public struct Configuration: Sendable {
    public let keyStrategy: APIKeyStrategy
    public let timeout: Int
    public let maxRetries: Int
    // ...
}
```

### ProviderProtocol (Abstraction)

All providers implement ``ProviderProtocol``:

**Standard interface:**
```swift
public protocol ProviderProtocol: Sendable {
    var providerType: ProviderType { get }

    func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse
    func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error>

    // Optional:
    func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int?
    func createBatch(_ requests: [AIRequest], apiKey: String) async throws -> String
    // ...
}
```

**Benefits:**
- Provider implementations are interchangeable
- Easy to add new providers
- Testing with mocks is trivial
- Gateway doesn't know provider details

### HTTPClientManager (HTTP Layer)

Actor-based HTTP client with retry logic:

**Responsibilities:**
- Make HTTP requests with timeout
- Implement exponential backoff
- Parse SSE streams
- Map HTTP status codes to errors

**Example:**
```swift
public actor HTTPClientManager {
    func post(url: String, headers: [String: String], body: Data) async throws -> Data {
        // 1. Make request with timeout
        // 2. Check HTTP status
        // 3. Retry on transient failures
        // 4. Return response data
    }

    func streamPost(url: String, headers: [String: String], body: Data) -> AsyncThrowingStream<Data, Error> {
        // Server-Sent Events streaming
    }
}
```

## Request Flow

### Non-Streaming Request

```
1. App creates AIRequest
     ↓
2. Calls gateway.sendMessage(request)
     ↓
3. Gateway resolves API key via keyStrategy
     ↓
4. Gateway gets provider implementation
     ↓
5. Provider transforms AIRequest → ProviderRequest
     ↓
6. Provider calls HTTPClientManager.post()
     ↓
7. HTTPClientManager makes HTTP request
     ↓
8. HTTPClientManager receives HTTP response
     ↓
9. Provider transforms ProviderResponse → AIResponse
     ↓
10. Gateway returns AIResponse to app
```

### Streaming Request

```
1. App calls gateway.streamMessage(request)
     ↓
2. Gateway returns AsyncThrowingStream immediately
     ↓
3. Background task starts:
     ↓
4. Provider calls HTTPClientManager.streamPost()
     ↓
5. HTTPClientManager opens SSE connection
     ↓
6. For each SSE event:
     │  ├─ Provider parses event → AIResponse chunk
     │  └─ Yields chunk to stream
     ↓
7. Stream completes when [DONE] received
```

## Error Handling Flow

```
HTTP Status Code
     ↓
HTTPClientManager maps to AIError
     ↓
Provider can enrich error with details
     ↓
Gateway catches and logs error
     ↓
Error thrown to app
```

**Error mapping:**
- 401/403 → `AIError.authenticationFailed`
- 429 → `AIError.rateLimitExceeded`
- 400/422 → `AIError.validationError`
- 500+ → `AIError.providerError`
- Network → `AIError.networkError`

## Concurrency Model

### Actor Isolation

```
AIGateway (Actor)
    │
    ├─ Isolated mutable state
    ├─ Sequential access guaranteed
    └─ Can be called from any thread

HTTPClientManager (Actor)
    │
    ├─ Isolated HTTP client
    ├─ Safe for concurrent requests
    └─ Automatic retry synchronization
```

**Benefits:**
- No manual locking required
- No data races possible
- Compiler enforces safety
- Easy to reason about

### Sendable Types

All public types conform to `Sendable`:

```swift
public struct AIRequest: Sendable { }
public struct AIResponse: Sendable { }
public struct Configuration: Sendable { }
public enum APIKeyStrategy: Sendable { }
public protocol ProviderProtocol: Sendable { }
```

**Why?**
- Safe to pass across actor boundaries
- Can be used in async contexts
- Compiler verifies thread safety
- Swift 6 strict concurrency compliance

## Extensibility Points

### Custom Providers

```swift
public struct CustomProvider: ProviderProtocol {
    public let providerType: ProviderType = .custom("MyProvider")

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        // Your implementation
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        // Your implementation
    }
}

// Register with gateway
let provider = CustomProvider()
await gateway.registerProvider(provider, for: .custom("MyProvider"))
```

### Custom HTTP Client

```swift
let customHTTPClient = HTTPClientManager(
    maxRetries: 5,
    timeout: .seconds(120),
    enableLogging: true
)

let provider = AnthropicProvider(httpClient: customHTTPClient)
```

## Design Principles

### 1. Protocol-Oriented

All providers implement `ProviderProtocol` - enables:
- Polymorphism
- Easy testing
- Provider swapping
- Extensibility

### 2. Actor-Based Concurrency

Actors for mutable state:
- No manual locks
- Compiler-verified safety
- Natural async/await integration

### 3. Value Types Where Possible

Structs for data:
- Immutable
- Thread-safe
- Efficient copying
- Clear ownership

### 4. Separation of Concerns

Clear boundaries:
- **Core/** - Framework logic
- **Models/** - Data structures
- **Providers/** - Provider implementations
- **Utilities/** - Shared helpers

### 5. Dependency Injection

Configuration passed explicitly:
- No globals
- Easy to test
- Clear dependencies
- Flexible setup

## Performance Characteristics

### Memory Usage

**Lightweight:**
- ~1MB framework overhead
- Streaming doesn't accumulate in memory
- Providers are stateless structs
- Minimal allocations

### Latency

**Components add minimal overhead:**
- Gateway routing: < 1ms
- Provider transformation: < 1ms
- HTTP overhead: Network dependent
- Total non-network overhead: < 5ms

### Concurrency

**Highly concurrent:**
- Multiple requests in parallel
- Actor isolation prevents contention
- HTTP client supports connection pooling
- Streaming doesn't block

## Module Organization

```
SwiftlyAIKit/
├── Core/
│   ├── AIGateway.swift          (Main coordinator)
│   ├── Configuration.swift       (Settings)
│   ├── APIKeyStrategy.swift      (Key management)
│   ├── ProviderProtocol.swift    (Provider interface)
│   └── ...
├── Models/
│   ├── AIRequest.swift           (Request type)
│   ├── AIResponse.swift          (Response type)
│   ├── AIMessage.swift           (Message type)
│   ├── AIError.swift             (Error type)
│   └── ...
├── Providers/
│   ├── Anthropic/
│   │   ├── AnthropicProvider.swift
│   │   └── AnthropicModels.swift
│   ├── OpenAI/
│   │   ├── OpenAIProvider.swift
│   │   └── OpenAIModels.swift
│   └── ...
└── Utilities/
    ├── HTTPClientManager.swift   (HTTP layer)
    └── Logger.swift              (Logging)
```

## See Also

- ``AIGateway``
- ``ProviderProtocol``
- <doc:ActorConcurrency>
- <doc:ExtensibilityPoints>
- <doc:ProviderProtocolGuide>
