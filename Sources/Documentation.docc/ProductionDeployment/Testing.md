# Testing

Test your AI-powered features with SwiftlyAIKit.

## Overview

Testing AI applications requires special considerations:
- AI responses are non-deterministic
- External API calls are expensive
- Network dependencies complicate tests
- Response times vary

This guide shows you how to test effectively using mocks, stubs, and integration tests.

## Testing Framework

SwiftlyAIKit uses **Swift Testing** (not XCTest):

```swift
import Testing
@testable import SwiftlyAIKit

@Test
func testBasicRequest() async throws {
    let config = Configuration.withCompanyKey("test-key")
    let gateway = AIGateway(configuration: config)

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello")

    // Test implementation
}
```

## Unit Testing with Mocks

### Mock Provider

```swift
actor MockProvider: ProviderProtocol {
    var providerType: ProviderType = .anthropic
    var responseToReturn: AIResponse?
    var errorToThrow: Error?
    var callCount = 0

    func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        callCount += 1

        if let error = errorToThrow {
            throw error
        }

        return responseToReturn ?? AIResponse(
            message: AIMessage(role: .assistant, content: "Mock response"),
            stopReason: .endTurn,
            usage: nil
        )
    }

    func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            if let response = responseToReturn {
                continuation.yield(response)
            }
            continuation.finish()
        }
    }
}

// Usage
@Test
func testWithMock() async throws {
    let mock = MockProvider()
    mock.responseToReturn = AIResponse(
        message: AIMessage(role: .assistant, content: "Test response"),
        stopReason: .endTurn,
        usage: nil
    )

    let config = Configuration.withCompanyKey("test")
    let gateway = AIGateway(
        configuration: config,
        providers: [.anthropic: mock]
    )

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Test")
    let response = try await gateway.sendMessage(request)

    #expect(response.message.content == "Test response")
    #expect(await mock.callCount == 1)
}
```

### Testing Error Handling

```swift
@Test
func testAuthenticationError() async throws {
    let mock = MockProvider()
    mock.errorToThrow = AIError.authenticationFailed(provider: .anthropic)

    let config = Configuration.withCompanyKey("test")
    let gateway = AIGateway(configuration: config, providers: [.anthropic: mock])

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Test")

    do {
        _ = try await gateway.sendMessage(request)
        Issue.record("Should have thrown authentication error")
    } catch AIError.authenticationFailed(let provider) {
        #expect(provider == .anthropic)
    } catch {
        Issue.record("Wrong error type: \(error)")
    }
}

@Test
func testRateLimitRetry() async throws {
    let mock = MockProvider()

    // First call returns rate limit
    mock.errorToThrow = AIError.rateLimitExceeded(retryAfter: 1)

    let config = Configuration.withCompanyKey("test")
    let gateway = AIGateway(configuration: config, providers: [.anthropic: mock])

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Test")

    do {
        _ = try await gateway.sendMessage(request)
        Issue.record("Should have thrown rate limit error")
    } catch AIError.rateLimitExceeded(let retryAfter) {
        #expect(retryAfter == 1)

        // Test retry logic
        try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)

        // Second attempt succeeds
        mock.errorToThrow = nil
        mock.responseToReturn = AIResponse(
            message: AIMessage(role: .assistant, content: "Success"),
            stopReason: .endTurn,
            usage: nil
        )

        let response = try await gateway.sendMessage(request)
        #expect(response.message.content == "Success")
    }
}
```

### Testing Streaming

```swift
@Test
func testStreaming() async throws {
    actor StreamingMockProvider: ProviderProtocol {
        let providerType: ProviderType = .anthropic

        func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
            fatalError("Not used in streaming test")
        }

        func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
            AsyncThrowingStream { continuation in
                // Yield 3 chunks
                continuation.yield(AIResponse(message: AIMessage(role: .assistant, content: "Hello"), stopReason: nil, usage: nil))
                continuation.yield(AIResponse(message: AIMessage(role: .assistant, content: " there"), stopReason: nil, usage: nil))
                continuation.yield(AIResponse(message: AIMessage(role: .assistant, content: "!"), stopReason: .endTurn, usage: nil))
                continuation.finish()
            }
        }
    }

    let mock = StreamingMockProvider()
    let config = Configuration.withCompanyKey("test")
    let gateway = AIGateway(configuration: config, providers: [.anthropic: mock])

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Test")

    var chunks: [String] = []
    let stream = try await gateway.streamMessage(request)

    for try await chunk in stream {
        chunks.append(chunk.message.content)
    }

    #expect(chunks.count == 3)
    #expect(chunks.joined() == "Hello there!")
}
```

## Integration Testing

### Test with Real Providers (Conditionally)

```swift
@Test(.enabled(if: ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "true"))
func testRealAnthropicAPI() async throws {
    guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
        Issue.record("ANTHROPIC_API_KEY not set")
        return
    }

    let config = Configuration.withCompanyKey(apiKey)
    let gateway = AIGateway(configuration: config)

    let request = AIRequest(
        model: .claude(.haiku3_5), // Use cheap model for testing
        prompt: "Say 'test'",
        maxTokens: 10
    )

    let response = try await gateway.sendMessage(request, to: .anthropic)

    #expect(response.message.content.count > 0)
    #expect(response.usage != nil)
}
```

## Testing Patterns

### Test Request Building

```swift
@Test
func testRequestConstruction() {
    let request = AIRequest(
        model: .claude(.sonnet4_5),
        messages: [
            .user("Hello"),
            .assistant("Hi there!"),
            .user("How are you?")
        ],
        systemPrompt: "Be helpful",
        temperature: 0.7,
        maxTokens: 1000
    )

    #expect(request.messages.count == 3)
    #expect(request.model == .claude(.sonnet4_5).rawValue)
    #expect(request.temperature == 0.7)
    #expect(request.maxTokens == 1000)
}
```

### Test Configuration

```swift
@Test
func testConfigurationStrategies() {
    // Company key
    let companyConfig = Configuration.withCompanyKey("sk-test")
    #expect(companyConfig.keyStrategy.requiresClientKey == false)

    // Client key
    let clientConfig = Configuration.withClientKeys()
    #expect(clientConfig.keyStrategy.requiresClientKey == true)

    // Hybrid
    let hybridConfig = Configuration.withHybridKeys(defaultKey: "sk-test")
    #expect(hybridConfig.keyStrategy.acceptsClientKey == true)
}
```

### Test Error Mapping

```swift
@Test
func testErrorMapping() throws {
    let errors: [(AIError, String)] = [
        (.authenticationFailed(provider: .anthropic), "auth"),
        (.rateLimitExceeded(retryAfter: 60), "rate"),
        (.validationError("test"), "validation"),
        (.networkError("timeout"), "network")
    ]

    for (error, expectedType) in errors {
        let mapped = mapToUserError(error)
        #expect(mapped.contains(expectedType))
    }
}

func mapToUserError(_ error: AIError) -> String {
    switch error {
    case .authenticationFailed:
        return "auth"
    case .rateLimitExceeded:
        return "rate"
    case .validationError:
        return "validation"
    case .networkError:
        return "network"
    default:
        return "unknown"
    }
}
```

## UI Testing

### SwiftUI Preview Testing

```swift
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock gateway for previews
        let config = Configuration.withCompanyKey("preview-key")
        let gateway = AIGateway(configuration: config)

        ChatView(gateway: gateway)
    }
}
```

### Test ViewModel State

```swift
@Test
@MainActor
func testChatViewModel() async throws {
    let mock = MockProvider()
    mock.responseToReturn = AIResponse(
        message: AIMessage(role: .assistant, content: "Hello!"),
        stopReason: .endTurn,
        usage: nil
    )

    let config = Configuration.withCompanyKey("test")
    let gateway = AIGateway(configuration: config, providers: [.anthropic: mock])

    let viewModel = ChatViewModel(gateway: gateway)

    #expect(viewModel.messages.isEmpty)
    #expect(viewModel.isLoading == false)

    viewModel.inputText = "Hi"
    await viewModel.sendMessage()

    #expect(viewModel.messages.count == 2) // User + assistant
    #expect(viewModel.messages[0].role == .user)
    #expect(viewModel.messages[1].role == .assistant)
    #expect(viewModel.messages[1].content == "Hello!")
}
```

## Performance Testing

### Measure Response Time

```swift
@Test
func testResponseTime() async throws {
    let mock = MockProvider()
    mock.responseToReturn = AIResponse(
        message: AIMessage(role: .assistant, content: "Fast!"),
        stopReason: .endTurn,
        usage: nil
    )

    let config = Configuration.withCompanyKey("test")
    let gateway = AIGateway(configuration: config, providers: [.anthropic: mock])

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Test")

    let start = Date()
    _ = try await gateway.sendMessage(request)
    let duration = Date().timeIntervalSince(start)

    // Framework overhead should be minimal
    #expect(duration < 0.1) // < 100ms
}
```

### Concurrent Request Testing

```swift
@Test
func testConcurrentRequests() async throws {
    let mock = MockProvider()
    mock.responseToReturn = AIResponse(
        message: AIMessage(role: .assistant, content: "Response"),
        stopReason: .endTurn,
        usage: nil
    )

    let config = Configuration.withCompanyKey("test")
    let gateway = AIGateway(configuration: config, providers: [.anthropic: mock])

    let requests = (0..<10).map { i in
        AIRequest(model: .claude(.sonnet4_5), prompt: "Test \(i)")
    }

    // Execute concurrently
    let start = Date()

    let responses = try await withThrowingTaskGroup(of: AIResponse.self) { group in
        for request in requests {
            group.addTask {
                try await gateway.sendMessage(request)
            }
        }

        var results: [AIResponse] = []
        for try await response in group {
            results.append(response)
        }
        return results
    }

    let duration = Date().timeIntervalSince(start)

    #expect(responses.count == 10)
    // Should be faster than sequential (10 × individual time)
}
```

## Best Practices

### ✅ Do

- Use mocks for unit tests
- Test error handling paths
- Test with real APIs conditionally
- Measure performance
- Test concurrent scenarios
- Test cancellation
- Test timeout behavior

### ❌ Don't

- Make real API calls in unit tests
- Ignore error cases
- Test only happy path
- Skip performance tests
- Hardcode test API keys
- Test in production

## Common Test Patterns

### Test Suite Structure

```swift
@Suite("AIGateway Tests")
struct AIGatewayTests {

    @Test("Send message successfully")
    func testSendMessage() async throws {
        // Arrange
        let mock = MockProvider()
        let gateway = AIGateway(...)

        // Act
        let response = try await gateway.sendMessage(request)

        // Assert
        #expect(response.message.content == "expected")
    }

    @Test("Handle rate limit")
    func testRateLimit() async throws {
        // Test rate limiting
    }

    @Test("Stream responses")
    func testStreaming() async throws {
        // Test streaming
    }
}
```

### Test Fixtures

```swift
enum TestFixtures {
    static let mockResponse = AIResponse(
        message: AIMessage(role: .assistant, content: "Test response"),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 10, outputTokens: 20)
    )

    static let mockRequest = AIRequest(
        model: .claude(.sonnet4_5),
        messages: [.user("Test prompt")]
    )

    static func mockGateway() -> AIGateway {
        let config = Configuration.withCompanyKey("test-key")
        return AIGateway(configuration: config)
    }
}

// Usage
@Test
func testSomething() async throws {
    let gateway = TestFixtures.mockGateway()
    let request = TestFixtures.mockRequest

    // Test...
}
```

## See Also

- <doc:ErrorHandling>
- <doc:MonitoringAndDebugging>
- ``AIGateway``
- ``ProviderProtocol``
