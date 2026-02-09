# Implementing Custom Providers

Learn how to add support for new AI providers.

## Overview

Want to add a provider not yet supported by SwiftlyAIKit? Implementing ``ProviderProtocol`` is straightforward:

1. Create a struct conforming to ``ProviderProtocol``
2. Implement ``sendMessage(_:apiKey:)``
3. Implement ``streamMessage(_:apiKey:)``
4. Optionally implement advanced features
5. Register with ``AIGateway``

## Step-by-Step Guide

### Step 1: Create Provider Struct

```swift
import Foundation
import SwiftlyAIKit

public struct MyCustomProvider: ProviderProtocol {
    public let providerType: ProviderType = .custom("MyProvider")

    private let httpClient: HTTPClientManager
    private let baseURL: String

    public init(baseURL: String = "https://api.myprovider.com/v1") {
        self.httpClient = HTTPClientManager()
        self.baseURL = baseURL
    }
}
```

### Step 2: Implement sendMessage

```swift
extension MyCustomProvider {
    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        // 1. Transform AIRequest to provider's format
        let providerRequest = MyProviderRequest(
            model: request.model,
            messages: request.messages.map { msg in
                MyProviderMessage(
                    role: msg.role == .user ? "user" : "assistant",
                    content: msg.textContent
                )
            },
            max_tokens: request.maxTokens,
            temperature: request.temperature
        )

        // 2. Encode to JSON
        let jsonData = try JSONEncoder().encode(providerRequest)

        // 3. Make HTTP request
        let responseData = try await httpClient.post(
            url: "\(baseURL)/chat/completions",
            headers: [
                ("Authorization", "Bearer \(apiKey)"),
                ("Content-Type", "application/json")
            ],
            body: jsonData
        )

        // 4. Decode provider response
        let providerResponse = try JSONDecoder().decode(MyProviderResponse.self, from: responseData)

        // 5. Transform to AIResponse
        return AIResponse(
            id: providerResponse.id,
            model: providerResponse.model,
            message: AIMessage(
                role: .assistant,
                text: providerResponse.choices.first?.message.content ?? ""
            ),
            stopReason: .endTurn,
            usage: AIUsage(
                inputTokens: providerResponse.usage.prompt_tokens,
                outputTokens: providerResponse.usage.completion_tokens
            ),
            provider: .custom("MyProvider")
        )
    }
}

// Provider-specific types
struct MyProviderRequest: Codable {
    let model: String
    let messages: [MyProviderMessage]
    let max_tokens: Int?
    let temperature: Double?
}

struct MyProviderMessage: Codable {
    let role: String
    let content: String
}

struct MyProviderResponse: Codable {
    let id: String
    let model: String
    let choices: [MyProviderChoice]
    let usage: MyProviderUsage
}

struct MyProviderChoice: Codable {
    let message: MyProviderMessage
}

struct MyProviderUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
}
```

### Step 3: Implement Streaming

```swift
extension MyCustomProvider {
    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // 1. Create streaming request
                    var providerRequest = MyProviderRequest(...)
                    providerRequest.stream = true

                    let jsonData = try JSONEncoder().encode(providerRequest)

                    // 2. Stream POST
                    let stream = httpClient.streamPost(
                        url: "\(baseURL)/chat/completions",
                        headers: [
                            ("Authorization", "Bearer \(apiKey)"),
                            ("Content-Type", "application/json")
                        ],
                        body: jsonData
                    )

                    // 3. Parse SSE events
                    for try await chunk in stream {
                        let chunkString = String(data: chunk, encoding: .utf8) ?? ""

                        // Parse Server-Sent Events
                        for line in chunkString.split(separator: "\n") {
                            if line.hasPrefix("data: ") {
                                let jsonStr = line.dropFirst(6)

                                if jsonStr == "[DONE]" {
                                    continuation.finish()
                                    return
                                }

                                if let data = jsonStr.data(using: .utf8),
                                   let event = try? JSONDecoder().decode(MyStreamEvent.self, from: data) {

                                    let response = AIResponse(
                                        id: event.id,
                                        model: event.model,
                                        message: AIMessage(role: .assistant, text: event.delta.content ?? ""),
                                        stopReason: nil,
                                        usage: nil,
                                        provider: .custom("MyProvider")
                                    )

                                    continuation.yield(response)
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

struct MyStreamEvent: Codable {
    let id: String
    let model: String
    let delta: MyProviderDelta
}

struct MyProviderDelta: Codable {
    let content: String?
}
```

### Step 4: Register Provider

```swift
let provider = MyCustomProvider()
await gateway.registerProvider(provider, for: .custom("MyProvider"))

// Use it
let request = AIRequest(model: .custom("my-model"), prompt: "Hello")
let response = try await gateway.sendMessage(request, to: .custom("MyProvider"))
```

## Advanced Features

### Implement Token Counting

```swift
extension MyCustomProvider {
    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int? {
        // If provider has token counting API
        let response = try await httpClient.post(
            url: "\(baseURL)/tokenize",
            headers: [("Authorization", "Bearer \(apiKey)")],
            body: try JSONEncoder().encode(["text": request.messages.last?.textContent ?? ""])
        )

        let result = try JSONDecoder().decode(TokenCount.self, from: response)
        return result.token_count
    }
}

struct TokenCount: Codable {
    let token_count: Int
}
```

### Implement Batch Processing

```swift
extension MyCustomProvider {
    public func createBatch(_ requests: [AIRequest], apiKey: String) async throws -> String {
        // Transform to provider's batch format
        let batchRequests = requests.map { req in
            MyBatchRequest(
                custom_id: UUID().uuidString,
                request: MyProviderRequest(...)
            )
        }

        let response = try await httpClient.post(
            url: "\(baseURL)/batches",
            headers: [("Authorization", "Bearer \(apiKey)")],
            body: try JSONEncoder().encode(batchRequests)
        )

        let result = try JSONDecoder().decode(MyBatchResponse.self, from: response)
        return result.batch_id
    }
}
```

## Testing Your Provider

```swift
@Test
func testCustomProvider() async throws {
    let provider = MyCustomProvider()

    let request = AIRequest(
        model: .custom("my-model"),
        prompt: "Test"
    )

    let response = try await provider.sendMessage(request, apiKey: "test-key")

    #expect(response.message.content.count > 0)
}
```

## See Also

- ``ProviderProtocol``
- <doc:ArchitectureOverview>
- <doc:ExtensibilityPoints>
- ``AIGateway/registerProvider(_:for:)``
