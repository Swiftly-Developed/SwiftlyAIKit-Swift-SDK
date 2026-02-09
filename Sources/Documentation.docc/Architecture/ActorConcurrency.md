# Actor Concurrency

Understand Swift actor-based concurrency in SwiftlyAIKit.

## Overview

SwiftlyAIKit uses Swift actors for thread-safe concurrent operations. This guide explains the concurrency model, best practices, and how to work with actors effectively.

## Why Actors?

Traditional thread-safety approaches (locks, queues) are error-prone. Actors provide:
- **Compiler-enforced safety** - Data races impossible
- **Natural async/await** - Clean concurrent code
- **No manual locking** - Automatic synchronization
- **Swift 6 compliant** - Strict concurrency checking

## Core Actors

### AIGateway Actor

```swift
public actor AIGateway {
    private let configuration: Configuration
    private var providers: [ProviderType: ProviderProtocol]

    // All methods are actor-isolated
    public func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        // Exclusive access to mutable state
    }
}
```

**Actor isolation guarantees:**
- Only one method executes at a time
- Mutable state is protected automatically
- No data races possible
- Thread-safe by design

### HTTPClientManager Actor

```swift
public actor HTTPClientManager {
    private var currentRetryCount: Int = 0

    func post(url: String, headers: [String: String], body: Data) async throws -> Data {
        // Actor-isolated HTTP operations
    }
}
```

## Calling Actors from Your Code

### From Async Context

```swift
// ✅ Natural async/await
func fetchAIResponse() async throws {
    let response = try await gateway.sendMessage(request)
    print(response.message.content)
}
```

### From Synchronous Context

```swift
// ✅ Wrap in Task
func buttonTapped() {
    Task {
        let response = try await gateway.sendMessage(request)
        updateUI(with: response)
    }
}
```

### From Main Actor (SwiftUI)

```swift
@MainActor
class ViewModel: ObservableObject {
    let gateway: AIGateway

    func sendMessage() async {
        // ✅ Crossing actor boundaries is automatic
        let response = try? await gateway.sendMessage(request)
        // Back on main actor
        self.latestResponse = response
    }
}
```

## Concurrent Requests

Actors allow safe concurrent operations:

### Parallel Requests

```swift
async let response1 = gateway.sendMessage(request1)
async let response2 = gateway.sendMessage(request2)
async let response3 = gateway.sendMessage(request3)

// All execute concurrently, safely
let (r1, r2, r3) = try await (response1, response2, response3)
```

### Task Groups

```swift
await withThrowingTaskGroup(of: AIResponse.self) { group in
    for request in requests {
        group.addTask {
            try await gateway.sendMessage(request)
        }
    }

    for try await response in group {
        print(response.message.content)
    }
}
```

## Sendable Conformance

All public types are `Sendable`:

```swift
// Can safely cross actor boundaries
public struct AIRequest: Sendable { }
public struct AIResponse: Sendable { }
public struct Configuration: Sendable { }

// Safely pass between actors
await otherActor.process(request)  // ✅ Safe
```

### Custom Types Must Be Sendable

```swift
// ✅ Correct
struct CustomData: Sendable {
    let value: String
    let count: Int
}

// ❌ Won't compile with strict concurrency
struct BadData {
    var mutableValue: String // Mutable, not thread-safe
}
```

## Actor Isolation Examples

### Accessing Actor State

```swift
let gateway = AIGateway(configuration: config)

// ❌ Can't access actor properties synchronously
// let providers = gateway.providers // Compiler error

// ✅ Access through async method
let isRegistered = await gateway.isProviderRegistered(.anthropic)
```

### Mutating Actor State

```swift
// ✅ Register provider (async, actor-isolated)
await gateway.registerProvider(customProvider, for: .custom("MyProvider"))
```

## Best Practices

### ✅ Do

**1. Keep actor methods focused:**
```swift
public actor AIGateway {
    // ✅ Good: Simple, focused
    public func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        let provider = try getProvider(providerType)
        return try await provider.sendMessage(request, apiKey: apiKey)
    }
}
```

**2. Don't call back into the same actor:**
```swift
public actor AIGateway {
    // ✅ Good: Direct implementation
    func processRequest() async {
        let result = await externalService.call()
    }

    // ❌ Avoid: Re-entering same actor
    func processRequest() async {
        let result = await self.helper() // Can cause issues
    }

    func helper() async -> String { }
}
```

**3. Minimize time in actor:**
```swift
public actor AIGateway {
    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        // ✅ Quick: Just resolve key
        let apiKey = try resolveAPIKey()

        // ✅ Long operation outside actor
        let provider = providers[type]!
        return try await provider.sendMessage(request, apiKey: apiKey)
        // Provider is NOT an actor, doesn't block gateway
    }
}
```

### ❌ Don't

**1. Don't block actors with long operations:**
```swift
// ❌ Bad: Blocks actor for 10 seconds
public actor AIGateway {
    func badMethod() async {
        sleep(10) // Blocks ALL gateway operations!
    }
}
```

**2. Don't create actor deadlocks:**
```swift
// ❌ Can deadlock
actor A {
    let b: B

    func method() async {
        await b.method() // B might call back to A
    }
}

actor B {
    let a: A

    func method() async {
        await a.method() // Deadlock!
    }
}
```

## Testing with Actors

### Mock Actors

```swift
actor MockGateway {
    var responses: [AIResponse] = []

    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        return responses.removeFirst()
    }
}

@Test
func testWithMockActor() async throws {
    let mock = MockGateway()
    await mock.responses.append(testResponse)

    let response = try await mock.sendMessage(testRequest)
    #expect(response.message.content == "expected")
}
```

## Common Patterns

### Actor as Service

```swift
public actor AIService {
    private let gateway: AIGateway
    private var requestCount: Int = 0

    public init(gateway: AIGateway) {
        self.gateway = gateway
    }

    public func ask(_ prompt: String) async throws -> String {
        requestCount += 1

        let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)
        let response = try await gateway.sendMessage(request)

        return response.message.content
    }

    public func getStats() -> Int {
        requestCount
    }
}
```

### Actor for Rate Limiting

```swift
public actor RateLimiter {
    private var requests: [Date] = []
    private let maxRequestsPerMinute: Int

    public init(maxRequestsPerMinute: Int) {
        self.maxRequestsPerMinute = maxRequestsPerMinute
    }

    public func isAllowed() -> Bool {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)

        // Remove old requests
        requests = requests.filter { $0 > oneMinuteAgo }

        if requests.count < maxRequestsPerMinute {
            requests.append(now)
            return true
        }

        return false
    }
}

// Usage
let limiter = RateLimiter(maxRequestsPerMinute: 50)

if await limiter.isAllowed() {
    let response = try await gateway.sendMessage(request)
}
```

## See Also

- ``AIGateway``
- <doc:ArchitectureOverview>
- <doc:ExtensibilityPoints>
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
