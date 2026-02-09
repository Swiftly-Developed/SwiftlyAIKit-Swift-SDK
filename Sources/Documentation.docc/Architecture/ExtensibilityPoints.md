# Extensibility Points

Learn how to extend and customize SwiftlyAIKit.

## Overview

SwiftlyAIKit is designed for extensibility. You can:
- Add custom AI providers
- Implement custom HTTP clients
- Create custom loggers
- Build custom rate limiters
- Extend with middleware

## Custom Providers

### Implement ProviderProtocol

```swift
public struct CustomProvider: ProviderProtocol {
    public let providerType: ProviderType = .custom("MyCustomProvider")

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        // 1. Transform AIRequest to your provider's format
        let customRequest = CustomRequest(
            prompt: request.messages.last?.content ?? "",
            model: request.model
        )

        // 2. Make HTTP call
        let httpClient = HTTPClientManager()
        let body = try JSONEncoder().encode(customRequest)

        let responseData = try await httpClient.post(
            url: "https://custom-ai-api.com/v1/chat",
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ],
            body: body
        )

        // 3. Parse response
        let customResponse = try JSONDecoder().decode(CustomResponse.self, from: responseData)

        // 4. Transform to AIResponse
        return AIResponse(
            message: AIMessage(role: .assistant, content: customResponse.text),
            stopReason: .endTurn,
            usage: AIUsage(
                inputTokens: customResponse.promptTokens,
                outputTokens: customResponse.completionTokens
            )
        )
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Implement streaming
                continuation.finish()
            }
        }
    }
}

// Register with gateway
let provider = CustomProvider()
await gateway.registerProvider(provider, for: .custom("MyCustomProvider"))

// Use it
let response = try await gateway.sendMessage(request, to: .custom("MyCustomProvider"))
```

## Custom HTTP Client

### Implement Custom HTTP Logic

```swift
public actor CustomHTTPClient {
    func post(url: String, headers: [String: String], body: Data) async throws -> Data {
        // Your custom HTTP implementation
        // - Custom headers
        // - Custom authentication
        // - Custom retry logic
        // - Request/response logging
    }
}

// Use with provider
let httpClient = CustomHTTPClient()
let provider = AnthropicProvider(httpClient: httpClient)
```

### Add Request Middleware

```swift
public actor HTTPMiddleware {
    let next: HTTPClientManager

    func post(url: String, headers: [String: String], body: Data) async throws -> Data {
        // Before request
        print("Requesting: \(url)")
        let start = Date()

        // Execute
        let response = try await next.post(url: url, headers: headers, body: body)

        // After request
        let duration = Date().timeIntervalSince(start)
        print("Completed in \(duration)s")

        return response
    }
}
```

## Custom Logging

### Implement AILogger

```swift
import Logging

public class CustomLogger: AILogger {
    private let logger: Logger

    public init() {
        var l = Logger(label: "com.myapp.ai")
        l.logLevel = .debug
        self.logger = l
    }

    public func log(
        level: LogLevel,
        message: String,
        metadata: [String: String]?,
        file: String,
        function: String,
        line: UInt
    ) {
        let swiftLogLevel: Logger.Level
        switch level {
        case .debug: swiftLogLevel = .debug
        case .info: swiftLogLevel = .info
        case .warning: swiftLogLevel = .warning
        case .error: swiftLogLevel = .error
        }

        logger.log(
            level: swiftLogLevel,
            "\(message)",
            metadata: metadata?.reduce(into: Logger.Metadata()) { result, item in
                result[item.key] = .string(item.value)
            }
        )
    }
}

// Configure
let config = Configuration.withCompanyKey("sk-ant-...")
config.configureLogging(logger: CustomLogger(), logLevel: .debug)
```

## Custom Rate Limiting

### Build Rate Limiter

```swift
public actor RateLimiter {
    private var windows: [String: [Date]] = [:]
    private let maxRequests: Int
    private let windowSeconds: TimeInterval

    public init(maxRequests: Int, per windowSeconds: TimeInterval) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }

    public func checkLimit(for key: String) async -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowSeconds)

        // Clean old entries
        windows[key] = windows[key]?.filter { $0 > windowStart } ?? []

        // Check limit
        if (windows[key]?.count ?? 0) < maxRequests {
            windows[key, default: []].append(now)
            return true
        }

        return false
    }

    public func reset(for key: String) {
        windows[key] = []
    }
}

// Use in your app
let limiter = RateLimiter(maxRequests: 50, per: 60)

if await limiter.checkLimit(for: userID) {
    let response = try await gateway.sendMessage(request)
} else {
    throw AppError.rateLimited
}
```

## Custom Request/Response Transformation

### Request Interceptor

```swift
protocol RequestInterceptor {
    func beforeRequest(_ request: AIRequest) async throws -> AIRequest
    func afterResponse(_ response: AIResponse) async -> AIResponse
}

class LoggingInterceptor: RequestInterceptor {
    func beforeRequest(_ request: AIRequest) async throws -> AIRequest {
        print("📤 Sending: \(request.messages.last?.content ?? "")")
        return request
    }

    func afterResponse(_ response: AIResponse) async -> AIResponse {
        print("📥 Received: \(response.message.content)")
        return response
    }
}

// Wrap gateway
class InterceptedGateway {
    let gateway: AIGateway
    let interceptors: [RequestInterceptor]

    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        var modifiedRequest = request

        // Before interceptors
        for interceptor in interceptors {
            modifiedRequest = try await interceptor.beforeRequest(modifiedRequest)
        }

        // Execute
        var response = try await gateway.sendMessage(modifiedRequest)

        // After interceptors
        for interceptor in interceptors {
            response = await interceptor.afterResponse(response)
        }

        return response
    }
}
```

## Custom Error Handling

### Error Mapper

```swift
protocol ErrorMapper {
    func mapError(_ error: Error) -> Error
}

class UserFriendlyErrorMapper: ErrorMapper {
    func mapError(_ error: Error) -> Error {
        guard let aiError = error as? AIError else {
            return error
        }

        switch aiError {
        case .authenticationFailed:
            return AppError.invalidAPIKey
        case .rateLimitExceeded:
            return AppError.tooManyRequests
        case .networkError:
            return AppError.noConnection
        default:
            return AppError.aiServiceError
        }
    }
}

// Use
let mapper = UserFriendlyErrorMapper()

do {
    return try await gateway.sendMessage(request)
} catch {
    throw mapper.mapError(error)
}
```

## Custom Caching

### Response Cache Actor

```swift
public actor ResponseCache {
    private var cache: [String: CachedResponse] = [:]
    private let ttl: TimeInterval

    struct CachedResponse {
        let response: AIResponse
        let timestamp: Date
    }

    public init(ttl: TimeInterval = 300) { // 5 minutes
        self.ttl = ttl
    }

    public func get(_ key: String) -> AIResponse? {
        guard let cached = cache[key] else { return nil }

        let age = Date().timeIntervalSince(cached.timestamp)
        if age < ttl {
            return cached.response
        } else {
            cache[key] = nil
            return nil
        }
    }

    public func set(_ key: String, response: AIResponse) {
        cache[key] = CachedResponse(response: response, timestamp: Date())
    }
}

// Usage
let cache = ResponseCache(ttl: 300)

func sendWithCache(_ request: AIRequest) async throws -> AIResponse {
    let cacheKey = request.messages.last?.content ?? ""

    if let cached = await cache.get(cacheKey) {
        print("Cache hit!")
        return cached
    }

    let response = try await gateway.sendMessage(request)
    await cache.set(cacheKey, response: response)

    return response
}
```

## Custom Provider Registration

### Dynamic Provider Loading

```swift
class ProviderRegistry {
    static func registerAll(to gateway: AIGateway, config: Configuration) async {
        // Register built-in providers
        await gateway.registerProvider(
            AnthropicProvider(),
            for: .anthropic
        )

        await gateway.registerProvider(
            OpenAIProvider(),
            for: .openai
        )

        // Register custom providers
        if let customProviders = loadCustomProviders() {
            for (type, provider) in customProviders {
                await gateway.registerProvider(provider, for: type)
            }
        }
    }
}
```

## Integration Patterns

### Dependency Injection

```swift
protocol AIServiceProtocol {
    func ask(_ prompt: String) async throws -> String
}

class ProductionAIService: AIServiceProtocol {
    let gateway: AIGateway

    init(gateway: AIGateway) {
        self.gateway = gateway
    }

    func ask(_ prompt: String) async throws -> String {
        let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)
        let response = try await gateway.sendMessage(request)
        return response.message.content
    }
}

class MockAIService: AIServiceProtocol {
    func ask(_ prompt: String) async throws -> String {
        return "Mocked response"
    }
}

// Use in app
class MyApp {
    let aiService: AIServiceProtocol

    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }
}

// Production
let prodService = ProductionAIService(gateway: realGateway)
let app = MyApp(aiService: prodService)

// Testing
let mockService = MockAIService()
let testApp = MyApp(aiService: mockService)
```

## See Also

- <doc:ArchitectureOverview>
- ``AIGateway``
- ``ProviderProtocol``
- <doc:ProviderProtocolGuide>
- [Swift Actors](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
