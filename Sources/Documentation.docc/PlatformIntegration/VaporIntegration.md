# Vapor Integration

Integrate SwiftlyAIKit with Vapor servers.

## Overview

For Vapor server integration, SwiftlyAIKit provides a dedicated package: **SwiftlyAIServerKit**.

This guide shows basic SwiftlyAIKit usage on Vapor. For production Vapor deployments, see [SwiftlyAIServerKit](https://github.com/Swiftly-Developed/SwiftlyAIServerKit).

## Basic Integration

### Add Dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.10.0"),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
],
targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "SwiftlyAIKit", package: "SwiftlyAIKit"),
            .product(name: "Vapor", package: "vapor")
        ]
    )
]
```

### Configure Gateway

```swift
import Vapor
import SwiftlyAIKit

func configure(_ app: Application) throws {
    // Load API key from environment
    guard let apiKey = Environment.get("ANTHROPIC_API_KEY") else {
        app.logger.critical("ANTHROPIC_API_KEY not set")
        throw ConfigurationError.missingAPIKey
    }

    // Create gateway (store in app)
    let config = Configuration.withCompanyKey(apiKey)
    let gateway = AIGateway(configuration: config)

    app.storage[AIGatewayKey.self] = gateway
}

// Storage key
struct AIGatewayKey: StorageKey {
    typealias Value = AIGateway
}

extension Application {
    var aiGateway: AIGateway {
        get {
            guard let gateway = storage[AIGatewayKey.self] else {
                fatalError("AIGateway not configured. Call configure() first.")
            }
            return gateway
        }
        set {
            storage[AIGatewayKey.self] = newValue
        }
    }
}
```

### Create Routes

```swift
import Vapor
import SwiftlyAIKit

func routes(_ app: Application) throws {
    // Chat endpoint
    app.post("chat") { req async throws -> Response in
        struct ChatRequest: Content {
            let message: String
            let model: String?
        }

        let chatRequest = try req.content.decode(ChatRequest.self)

        let aiRequest = AIRequest(
            model: .claude(.sonnet4_5),
            prompt: chatRequest.message
        )

        let response = try await req.application.aiGateway.sendMessage(aiRequest)

        return try await response.encodeResponse(for: req)
    }

    // Streaming endpoint
    app.post("stream") { req async throws -> Response in
        let chatRequest = try req.content.decode(ChatRequest.self)

        let aiRequest = AIRequest(
            model: .claude(.sonnet4_5),
            prompt: chatRequest.message
        )

        let stream = try await req.application.aiGateway.streamMessage(aiRequest)

        return Response(
            status: .ok,
            headers: ["Content-Type": "text/event-stream"],
            body: .init(asyncStream: stream.map { response in
                "data: \(response.message.content)\n\n"
            })
        )
    }
}

struct ChatRequest: Content {
    let message: String
    let model: String?
}
```

## Server-Sent Events Streaming

### SSE Stream Handler

```swift
app.post("stream-chat") { req async throws -> Response in
    let chatRequest = try req.content.decode(ChatRequest.self)

    let aiRequest = AIRequest(
        model: .claude(.sonnet4_5),
        messages: chatRequest.messages.map { msg in
            AIMessage(role: msg.role == "user" ? .user : .assistant, content: msg.content)
        }
    )

    let stream = try await req.application.aiGateway.streamMessage(aiRequest)

    let sseStream: AsyncStream<String> = AsyncStream { continuation in
        Task {
            do {
                for try await chunk in stream {
                    let sseEvent = "data: \(chunk.message.content)\n\n"
                    continuation.yield(sseEvent)
                }

                continuation.yield("data: [DONE]\n\n")
                continuation.finish()
            } catch {
                let errorEvent = "data: {\"error\":\"\(error.localizedDescription)\"}\n\n"
                continuation.yield(errorEvent)
                continuation.finish()
            }
        }
    }

    return Response(
        status: .ok,
        headers: HTTPHeaders([
            ("Content-Type", "text/event-stream"),
            ("Cache-Control", "no-cache"),
            ("Connection", "keep-alive")
        ]),
        body: .init(stream: sseStream.map { ByteBuffer(string: $0) })
    )
}
```

## For Production Vapor Apps

**Use SwiftlyAIServerKit** for production features:

```swift
import Vapor
import SwiftlyAIServerKit
import SwiftlyAIVapor

func configure(_ app: Application) throws {
    // SwiftlyAIServerKit provides app.ai.initialize()
    let config = Configuration.withCompanyKey(
        Environment.get("ANTHROPIC_API_KEY")!
    )

    try app.ai.initialize(with: config)

    // SwiftlyAIVapor provides pre-built routes
    try app.register(collection: AIRoutes())
}

func routes(_ app: Application) throws {
    // Use req.ai helpers
    app.post("chat") { req async throws -> AIResponse in
        let request = try req.content.decode(AIRequest.self)
        return try await req.ai.sendMessage(request)
    }
}
```

**Features in SwiftlyAIServerKit:**
- `app.ai.initialize()` - Lifecycle management
- `req.ai.sendMessage()` - Request helpers
- Pre-built routes with JWT auth
- Rate limiting middleware
- Request/response logging

**Learn more:** [SwiftlyAIServerKit Documentation](https://github.com/Swiftly-Developed/SwiftlyAIServerKit)

## See Also

- <doc:ChoosingDeploymentPattern>
- <doc:APIKeyManagement>
- <doc:StreamingResponses>
- [SwiftlyAIServerKit](https://github.com/Swiftly-Developed/SwiftlyAIServerKit)
- [SwiftlyAIVapor](https://github.com/Swiftly-Developed/SwiftlyAIVapor)
