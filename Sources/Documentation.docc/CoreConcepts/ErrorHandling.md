# Error Handling

Handle AI provider failures gracefully in production.

## Overview

AI requests can fail for many reasons: invalid API keys, rate limits, network issues, or provider outages. SwiftlyAIKit provides comprehensive error handling through the ``AIError`` type and automatic retry logic.

This guide covers:
- Understanding ``AIError`` cases
- Handling common error scenarios
- Implementing retry strategies
- Production error handling patterns

## AIError Types

SwiftlyAIKit defines specific error cases for common failure modes:

```swift
public enum AIError: Error, Sendable {
    /// Authentication failed (invalid or missing API key)
    case authenticationFailed(provider: ProviderType)

    /// Missing API key for provider
    case missingAPIKey(provider: ProviderType)

    /// Rate limit exceeded (retry after N seconds)
    case rateLimitExceeded(retryAfter: Int)

    /// Invalid model specified
    case invalidModel(model: String)

    /// Validation error (bad request)
    case validationError(String)

    /// Provider error (server issue)
    case providerError(statusCode: Int, message: String)

    /// Network error (connection issue)
    case networkError(String)

    /// Unsupported feature for provider
    case unsupportedFeature(feature: String, provider: ProviderType)

    /// Provider not registered
    case providerNotRegistered(ProviderType)

    /// Response parsing failed
    case parsingError(String)
}
```

## Basic Error Handling

### Catch All Errors

```swift
do {
    let response = try await gateway.sendMessage(request)
    print("Success: \(response.message.content)")
} catch {
    print("Error occurred: \(error)")
}
```

### Handle Specific Errors

```swift
do {
    let response = try await gateway.sendMessage(request)
    print("Success: \(response.message.content)")
} catch AIError.authenticationFailed(let provider) {
    print("Bad API key for \(provider)")
    // Prompt user to check their API key
} catch AIError.rateLimitExceeded(let retryAfter) {
    print("Rate limited. Retry after \(retryAfter) seconds")
    // Implement backoff strategy
} catch AIError.networkError(let message) {
    print("Network issue: \(message)")
    // Check connectivity, retry
} catch {
    print("Unexpected error: \(error)")
}
```

### Switch on Error Cases

```swift
do {
    let response = try await gateway.sendMessage(request)
    return response
} catch let error as AIError {
    switch error {
    case .authenticationFailed(let provider):
        // Handle auth error
        throw CustomError.invalidCredentials(provider)

    case .rateLimitExceeded(let retryAfter):
        // Handle rate limit
        try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
        return try await gateway.sendMessage(request) // Retry

    case .validationError(let message):
        // Handle validation error
        throw CustomError.invalidRequest(message)

    case .providerError(let statusCode, let message):
        // Handle provider error
        print("Provider error \(statusCode): \(message)")
        throw CustomError.providerIssue

    case .networkError(let message):
        // Handle network error
        throw CustomError.networkIssue(message)

    case .unsupportedFeature(let feature, let provider):
        // Handle unsupported feature
        print("\(provider) doesn't support \(feature)")
        throw CustomError.featureNotSupported

    default:
        throw error
    }
} catch {
    // Non-AIError cases
    throw error
}
```

## Common Error Scenarios

### Authentication Errors

**Symptom:** Request fails immediately with authentication error

**Causes:**
- Invalid API key
- Expired API key
- Wrong provider for the key
- Key not set in environment

**Solution:**

```swift
func sendWithAuthRetry(_ request: AIRequest) async throws -> AIResponse {
    do {
        return try await gateway.sendMessage(request)
    } catch AIError.authenticationFailed(let provider) {
        // Log the error
        print("Authentication failed for \(provider)")

        // Check if we have a fallback key
        if let fallbackKey = getFallbackKey(for: provider) {
            return try await gateway.sendMessage(request, clientAPIKey: fallbackKey)
        }

        // Prompt user to update their API key
        throw UserFacingError.pleaseUpdateAPIKey(provider)
    }
}
```

### Rate Limiting

**Symptom:** Too many requests, need to back off

**Causes:**
- Exceeding provider rate limits
- Too many concurrent requests
- No rate limiting on client side

**Solution with Exponential Backoff:**

```swift
func sendWithBackoff(
    _ request: AIRequest,
    maxRetries: Int = 3,
    baseDelay: TimeInterval = 1.0
) async throws -> AIResponse {
    var attempt = 0

    while attempt < maxRetries {
        do {
            return try await gateway.sendMessage(request)
        } catch AIError.rateLimitExceeded(let retryAfter) {
            attempt += 1

            if attempt >= maxRetries {
                throw AIError.rateLimitExceeded(retryAfter: retryAfter)
            }

            // Exponential backoff: 1s, 2s, 4s, 8s...
            let delay = min(retryAfter, Int(baseDelay * pow(2.0, Double(attempt))))
            print("Rate limited. Waiting \(delay)s before retry \(attempt)/\(maxRetries)")

            try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        }
    }

    throw AIError.rateLimitExceeded(retryAfter: 60)
}
```

### Network Errors

**Symptom:** Connection timeouts or failures

**Causes:**
- No internet connection
- Provider API down
- Firewall blocking requests
- Timeout too short

**Solution with Retry Logic:**

```swift
func sendWithNetworkRetry(
    _ request: AIRequest,
    maxRetries: Int = 3
) async throws -> AIResponse {
    var lastError: Error?

    for attempt in 1...maxRetries {
        do {
            return try await gateway.sendMessage(request)
        } catch AIError.networkError(let message) {
            lastError = AIError.networkError(message)

            if attempt < maxRetries {
                let delay = attempt * 2 // 2s, 4s, 6s
                print("Network error on attempt \(attempt). Retrying in \(delay)s...")
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            }
        } catch {
            // Non-network errors should not retry
            throw error
        }
    }

    throw lastError ?? AIError.networkError("Max retries exceeded")
}
```

### Validation Errors

**Symptom:** Request rejected by provider

**Causes:**
- Invalid model name
- Context too long
- Invalid parameters
- Missing required fields

**Solution:**

```swift
func sendWithValidation(_ request: AIRequest) async throws -> AIResponse {
    do {
        return try await gateway.sendMessage(request)
    } catch AIError.validationError(let message) {
        // Parse validation error
        if message.contains("context_length_exceeded") {
            // Trim messages and retry
            let trimmedRequest = trimContext(request)
            return try await gateway.sendMessage(trimmedRequest)
        } else if message.contains("invalid_model") {
            // Fall back to default model
            var fallbackRequest = request
            fallbackRequest.model = .claude(.sonnet4_5)
            return try await gateway.sendMessage(fallbackRequest)
        } else {
            throw AIError.validationError(message)
        }
    }
}

func trimContext(_ request: AIRequest) -> AIRequest {
    // Keep only recent messages
    let maxMessages = 20
    let recentMessages = Array(request.messages.suffix(maxMessages))

    var trimmed = request
    trimmed.messages = recentMessages
    return trimmed
}
```

### Provider Errors

**Symptom:** Provider API returns 500+ status code

**Causes:**
- Provider service outage
- Provider API bug
- Provider overload

**Solution with Fallback:**

```swift
func sendWithFallback(_ request: AIRequest) async throws -> AIResponse {
    let primaryProvider: ProviderType = .anthropic
    let fallbackProvider: ProviderType = .openai

    do {
        return try await gateway.sendMessage(request, to: primaryProvider)
    } catch AIError.providerError(let statusCode, let message) {
        if statusCode >= 500 {
            // Server error, try fallback provider
            print("Provider error \(statusCode): \(message)")
            print("Falling back to \(fallbackProvider)")

            return try await gateway.sendMessage(request, to: fallbackProvider)
        } else {
            throw AIError.providerError(statusCode: statusCode, message: message)
        }
    }
}
```

## Production Error Handling Patterns

### Comprehensive Error Handler

```swift
class AIService {
    let gateway: AIGateway

    func sendMessage(
        _ request: AIRequest,
        maxRetries: Int = 3
    ) async throws -> AIResponse {
        var attempt = 0
        var lastError: Error?

        while attempt < maxRetries {
            attempt += 1

            do {
                let response = try await gateway.sendMessage(request)
                return response

            } catch let error as AIError {
                lastError = error

                switch error {
                case .authenticationFailed(let provider):
                    // Don't retry auth errors
                    throw UserError.invalidAPIKey(provider)

                case .rateLimitExceeded(let retryAfter):
                    if attempt < maxRetries {
                        await sleep(seconds: retryAfter)
                        continue
                    }
                    throw UserError.rateLimited

                case .networkError:
                    if attempt < maxRetries {
                        await sleep(seconds: attempt * 2)
                        continue
                    }
                    throw UserError.networkIssue

                case .validationError(let message):
                    // Don't retry validation errors
                    throw UserError.invalidRequest(message)

                case .providerError(let statusCode, _):
                    if statusCode >= 500 && attempt < maxRetries {
                        await sleep(seconds: attempt * 2)
                        continue
                    }
                    throw UserError.providerIssue

                case .unsupportedFeature(let feature, let provider):
                    throw UserError.featureNotSupported(feature, provider)

                default:
                    throw error
                }
            } catch {
                throw error
            }
        }

        throw lastError ?? AIError.networkError("Max retries exceeded")
    }

    private func sleep(seconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
    }
}

enum UserError: Error {
    case invalidAPIKey(ProviderType)
    case rateLimited
    case networkIssue
    case invalidRequest(String)
    case providerIssue
    case featureNotSupported(String, ProviderType)
}
```

### Error Logging

```swift
class AIServiceWithLogging {
    let gateway: AIGateway
    let logger: Logger

    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        do {
            let response = try await gateway.sendMessage(request)

            // Log success
            logger.info("AI request succeeded", metadata: [
                "model": .string(request.model),
                "inputTokens": .string("\(response.usage?.inputTokens ?? 0)"),
                "outputTokens": .string("\(response.usage?.outputTokens ?? 0)")
            ])

            return response

        } catch let error as AIError {
            // Log structured error
            logger.error("AI request failed", metadata: [
                "error": .string(String(describing: error)),
                "model": .string(request.model)
            ])

            // Re-throw with user-friendly message
            throw toUserError(error)
        } catch {
            logger.error("Unexpected error: \(error)")
            throw error
        }
    }

    private func toUserError(_ error: AIError) -> UserError {
        switch error {
        case .authenticationFailed(let provider):
            return .invalidAPIKey(provider)
        case .rateLimitExceeded:
            return .rateLimited
        case .networkError:
            return .networkIssue
        case .validationError(let message):
            return .invalidRequest(message)
        case .providerError:
            return .providerIssue
        case .unsupportedFeature(let feature, let provider):
            return .featureNotSupported(feature, provider)
        default:
            return .unknownError
        }
    }
}
```

### Circuit Breaker Pattern

Prevent cascading failures by stopping requests when provider is down:

```swift
actor CircuitBreaker {
    enum State {
        case closed      // Normal operation
        case open        // Blocking requests
        case halfOpen    // Testing recovery
    }

    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let threshold = 5
    private let timeout: TimeInterval = 60

    func recordSuccess() {
        state = .closed
        failureCount = 0
    }

    func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()

        if failureCount >= threshold {
            state = .open
        }
    }

    func canAttempt() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            // Check if timeout has passed
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout {
                state = .halfOpen
                return true
            }
            return false
        case .halfOpen:
            return true
        }
    }
}

class AIServiceWithCircuitBreaker {
    let gateway: AIGateway
    let circuitBreaker = CircuitBreaker()

    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        guard await circuitBreaker.canAttempt() else {
            throw UserError.serviceUnavailable
        }

        do {
            let response = try await gateway.sendMessage(request)
            await circuitBreaker.recordSuccess()
            return response
        } catch {
            await circuitBreaker.recordFailure()
            throw error
        }
    }
}
```

## SwiftUI Error Handling

### Display Errors to Users

```swift
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            // Chat UI...

            Button("Send") {
                Task {
                    do {
                        try await viewModel.sendMessage()
                    } catch {
                        errorMessage = toUserMessage(error)
                        showError = true
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    func toUserMessage(_ error: Error) -> String {
        if let aiError = error as? AIError {
            switch aiError {
            case .authenticationFailed:
                return "Invalid API key. Please check your settings."
            case .rateLimitExceeded:
                return "Too many requests. Please wait a moment and try again."
            case .networkError:
                return "Network connection issue. Please check your internet connection."
            case .validationError(let message):
                return "Invalid request: \(message)"
            case .providerError:
                return "The AI service is temporarily unavailable. Please try again later."
            default:
                return "An error occurred. Please try again."
            }
        }
        return error.localizedDescription
    }
}
```

## Testing Error Handling

```swift
@Test("Handle authentication error")
func testAuthError() async throws {
    let config = Configuration.withCompanyKey("invalid-key")
    let gateway = AIGateway(configuration: config)

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello")

    do {
        _ = try await gateway.sendMessage(request)
        Issue.record("Should have thrown authentication error")
    } catch AIError.authenticationFailed(let provider) {
        #expect(provider == .anthropic)
    } catch {
        Issue.record("Wrong error type: \(error)")
    }
}

@Test("Handle rate limit with retry")
func testRateLimitRetry() async throws {
    // Use mock that returns rate limit error first, then success
    let mockProvider = MockProvider()
    mockProvider.shouldReturnRateLimit = true

    let config = Configuration.withCompanyKey("test")
    let gateway = AIGateway(configuration: config, providers: [
        .anthropic: mockProvider
    ])

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello")

    let response = try await sendWithBackoff(request, using: gateway)
    #expect(response.message.content.count > 0)
}
```

## Best Practices

### ✅ Do

- Handle specific error cases relevant to your app
- Implement retry logic for transient failures
- Log errors with context for debugging
- Show user-friendly error messages
- Implement circuit breakers for resilience
- Test error handling paths

### ❌ Don't

- Retry authentication errors (they won't succeed)
- Retry validation errors (fix the request instead)
- Show raw error messages to users
- Ignore errors silently
- Retry indefinitely without backoff
- Log sensitive data (API keys, user content)

## See Also

- ``AIError``
- ``AIGateway``
- <doc:CommonPitfalls>
- <doc:MonitoringAndDebugging>
- <doc:PerformanceOptimization>
- <doc:Testing>
