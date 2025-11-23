# OpenAI Provider Implementation Plan for SwiftlyAIKit

**Research Date:** 2025-11-23
**Target Framework:** SwiftlyAIKit v0.3.0
**Pattern Reference:** AnthropicProvider.swift (~620 lines), AnthropicModels.swift (~700 lines)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [OpenAI API Endpoints](#openai-api-endpoints)
3. [Required Model Structures](#required-model-structures)
4. [Provider Implementation](#provider-implementation)
5. [Feature Comparison: OpenAI vs Anthropic](#feature-comparison)
6. [Special Considerations](#special-considerations)
7. [Implementation Phases](#implementation-phases)
8. [Testing Strategy](#testing-strategy)
9. [Commit Strategy](#commit-strategy)
10. [API References](#api-references)

---

## Executive Summary

This plan details the complete implementation of OpenAI API support in SwiftlyAIKit, following the established framework patterns. The implementation will add approximately 1,750 lines of code across model definitions, provider implementation, and comprehensive tests.

**Key Deliverables:**
- Full Chat Completions API support (standard + streaming)
- Batch API for cost-effective bulk processing (50% savings)
- Tool/function calling capabilities
- Vision support (GPT-4o, GPT-4 Turbo)
- Comprehensive error handling and rate limiting
- 100% test coverage matching Anthropic provider standards

---

## OpenAI API Endpoints

### Priority 1: Core Endpoints

#### 1.1 Chat Completions API
**Endpoint:** `POST /v1/chat/completions`
**Base URL:** `https://api.openai.com/v1`

**Features:**
- Standard message completion
- Streaming completions (Server-Sent Events)
- Tool/function calling support
- Vision support (image inputs via URL or base64)
- JSON response format mode
- Deterministic sampling with seed parameter

**Authentication:**
```
Authorization: Bearer sk-...
OpenAI-Organization: org-... (optional)
```

**Request Format:**
```json
{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful assistant."
    },
    {
      "role": "user",
      "content": "Hello!"
    }
  ],
  "max_tokens": 1000,
  "temperature": 0.7,
  "stream": false
}
```

**Response Format:**
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "gpt-4o",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Hello! How can I help you?"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 9,
    "completion_tokens": 12,
    "total_tokens": 21
  }
}
```

#### 1.2 Models API
**Endpoint:** `GET /v1/models`

**Purpose:**
- List available models
- Get model details and capabilities
- Validate model availability

**Response:**
```json
{
  "object": "list",
  "data": [
    {
      "id": "gpt-4o",
      "object": "model",
      "created": 1686935002,
      "owned_by": "openai"
    }
  ]
}
```

#### 1.3 Batch API
**Endpoints:**
- `POST /v1/batches` - Create batch
- `GET /v1/batches/{batch_id}` - Retrieve batch
- `POST /v1/batches/{batch_id}/cancel` - Cancel batch
- `GET /v1/batches` - List batches

**Benefits:**
- 50% cost savings compared to synchronous API
- Process up to 50,000 requests per batch
- 24-hour processing window
- Automatic retry handling

**Workflow:**
1. Create JSONL file with batch requests
2. Upload file via Files API: `POST /v1/files`
3. Create batch with file ID
4. Poll batch status (validating → in_progress → completed)
5. Download results file when complete

**Batch Request Format (JSONL):**
```json
{"custom_id": "request-1", "method": "POST", "url": "/v1/chat/completions", "body": {"model": "gpt-4o", "messages": [{"role": "user", "content": "Hello"}]}}
{"custom_id": "request-2", "method": "POST", "url": "/v1/chat/completions", "body": {"model": "gpt-4o", "messages": [{"role": "user", "content": "Hi"}]}}
```

**Batch Status Response:**
```json
{
  "id": "batch_abc123",
  "object": "batch",
  "endpoint": "/v1/chat/completions",
  "status": "completed",
  "input_file_id": "file-abc123",
  "output_file_id": "file-xyz789",
  "completion_window": "24h",
  "created_at": 1711471533,
  "completed_at": 1711493163,
  "request_counts": {
    "total": 100,
    "completed": 95,
    "failed": 5
  }
}
```

### Priority 2: Optional Endpoints

#### 2.1 Embeddings API
**Endpoint:** `POST /v1/embeddings`

**Models:**
- `text-embedding-3-small` - 512-8192 dimensions
- `text-embedding-3-large` - 256-3072 dimensions
- `text-embedding-ada-002` - Legacy model

**Note:** Not yet part of SwiftlyAIKit's core abstraction. Consider adding in future version if embedding support is added to the framework.

---

## Required Model Structures

### File: `Sources/SwiftlyAIKit/Models/OpenAI/OpenAIModels.swift`

**Estimated Size:** ~700 lines (mirrors AnthropicModels.swift)

#### 3.1 Content Blocks

```swift
/// Represents different types of content that can be sent in OpenAI messages
public enum OpenAIContentBlock: Codable, Sendable, Equatable {
    case text(String)
    case imageUrl(url: String, detail: ImageDetail?)

    public enum ImageDetail: String, Codable, Sendable {
        case low
        case high
        case auto
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }

    private enum ContentType: String, Codable {
        case text
        case imageUrl = "image_url"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let content):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(content, forKey: .text)

        case .imageUrl(let url, let detail):
            try container.encode(ContentType.imageUrl, forKey: .type)
            var imageUrlContainer = container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            try imageUrlContainer.encode(url, forKey: .url)
            if let detail = detail {
                try imageUrlContainer.encode(detail, forKey: .detail)
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)

        switch type {
        case .text:
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)

        case .imageUrl:
            let imageUrlContainer = try container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            let url = try imageUrlContainer.decode(String.self, forKey: .url)
            let detail = try? imageUrlContainer.decode(ImageDetail.self, forKey: .detail)
            self = .imageUrl(url: url, detail: detail)
        }
    }

    private enum ImageUrlKeys: String, CodingKey {
        case url
        case detail
    }
}
```

#### 3.2 Message Structure

```swift
/// OpenAI message structure for chat completions
public struct OpenAIMessage: Codable, Sendable, Equatable {
    public let role: Role
    public let content: MessageContent?
    public let name: String?
    public let toolCalls: [OpenAIToolCall]?
    public let toolCallId: String?

    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public enum MessageContent: Codable, Sendable, Equatable {
        case text(String)
        case contentArray([OpenAIContentBlock])

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .contentArray(let blocks):
                try container.encode(blocks)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let blocks = try? container.decode([OpenAIContentBlock].self) {
                self = .contentArray(blocks)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Content must be either a string or an array of content blocks"
                )
            }
        }
    }

    public init(
        role: Role,
        content: MessageContent? = nil,
        name: String? = nil,
        toolCalls: [OpenAIToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}
```

#### 3.3 Tool/Function Calling

```swift
/// Tool definition for function calling
public struct OpenAIToolDefinition: Codable, Sendable, Equatable {
    public let type: String
    public let function: FunctionDefinition

    public struct FunctionDefinition: Codable, Sendable, Equatable {
        public let name: String
        public let description: String?
        public let parameters: [String: AnyCodable]

        public init(name: String, description: String? = nil, parameters: [String: AnyCodable]) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }

    public init(function: FunctionDefinition) {
        self.type = "function"
        self.function = function
    }
}

/// Tool choice parameter
public enum OpenAIToolChoice: Codable, Sendable, Equatable {
    case none
    case auto
    case required
    case function(String)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .function(let name):
            try container.encode(["type": "function", "function": ["name": name]])
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            switch string {
            case "none":
                self = .none
            case "auto":
                self = .auto
            case "required":
                self = .required
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid tool_choice string value"
                )
            }
        } else if let dict = try? container.decode([String: [String: String]].self),
                  let functionName = dict["function"]?["name"] {
            self = .function(functionName)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid tool_choice format"
            )
        }
    }
}

/// Tool call made by the assistant
public struct OpenAIToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let function: FunctionCall

    public struct FunctionCall: Codable, Sendable, Equatable {
        public let name: String
        public let arguments: String

        public init(name: String, arguments: String) {
            self.name = name
            self.arguments = arguments
        }
    }

    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}
```

#### 3.4 Request Structure

```swift
/// OpenAI chat completion request
public struct OpenAIRequest: Codable, Sendable {
    public let model: String
    public let messages: [OpenAIMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let n: Int?
    public let stream: Bool?
    public let stop: [String]?
    public let presencePenalty: Double?
    public let frequencyPenalty: Double?
    public let logitBias: [String: Double]?
    public let user: String?
    public let responseFormat: ResponseFormat?
    public let seed: Int?
    public let tools: [OpenAIToolDefinition]?
    public let toolChoice: OpenAIToolChoice?

    public struct ResponseFormat: Codable, Sendable, Equatable {
        public let type: String

        public init(type: String) {
            self.type = type
        }

        public static let text = ResponseFormat(type: "text")
        public static let jsonObject = ResponseFormat(type: "json_object")
    }

    public init(
        model: String,
        messages: [OpenAIMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        logitBias: [String: Double]? = nil,
        user: String? = nil,
        responseFormat: ResponseFormat? = nil,
        seed: Int? = nil,
        tools: [OpenAIToolDefinition]? = nil,
        toolChoice: OpenAIToolChoice? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.n = n
        self.stream = stream
        self.stop = stop
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.logitBias = logitBias
        self.user = user
        self.responseFormat = responseFormat
        self.seed = seed
        self.tools = tools
        self.toolChoice = toolChoice
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case n
        case stream
        case stop
        case user
        case seed
        case tools
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
        case logitBias = "logit_bias"
        case responseFormat = "response_format"
        case toolChoice = "tool_choice"
    }
}
```

#### 3.5 Response Structure

```swift
/// OpenAI chat completion response
public struct OpenAIResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage
    public let systemFingerprint: String?

    public struct Choice: Codable, Sendable {
        public let index: Int
        public let message: OpenAIMessage
        public let finishReason: String?
        public let logprobs: LogProbs?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case logprobs
            case finishReason = "finish_reason"
        }
    }

    public struct Usage: Codable, Sendable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    public struct LogProbs: Codable, Sendable {
        // Optional: Implementation for token probability information
        // Can be added in future if needed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case model
        case choices
        case usage
        case systemFingerprint = "system_fingerprint"
    }
}
```

#### 3.6 Streaming Response

```swift
/// OpenAI streaming chunk
public struct OpenAIStreamChunk: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [StreamChoice]
    public let systemFingerprint: String?

    public struct StreamChoice: Codable, Sendable {
        public let index: Int
        public let delta: Delta
        public let finishReason: String?

        public struct Delta: Codable, Sendable {
            public let role: String?
            public let content: String?
            public let toolCalls: [DeltaToolCall]?

            public struct DeltaToolCall: Codable, Sendable {
                public let index: Int
                public let id: String?
                public let type: String?
                public let function: DeltaFunction?

                public struct DeltaFunction: Codable, Sendable {
                    public let name: String?
                    public let arguments: String?
                }
            }

            enum CodingKeys: String, CodingKey {
                case role
                case content
                case toolCalls = "tool_calls"
            }
        }

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case model
        case choices
        case systemFingerprint = "system_fingerprint"
    }
}
```

#### 3.7 Batch API Models

```swift
/// OpenAI batch status
public struct OpenAIBatch: Codable, Sendable {
    public let id: String
    public let object: String
    public let endpoint: String
    public let errors: BatchErrors?
    public let inputFileId: String
    public let completionWindow: String
    public let status: BatchStatus
    public let outputFileId: String?
    public let errorFileId: String?
    public let createdAt: Int
    public let inProgressAt: Int?
    public let expiresAt: Int?
    public let completedAt: Int?
    public let failedAt: Int?
    public let expiredAt: Int?
    public let cancellingAt: Int?
    public let cancelledAt: Int?
    public let requestCounts: RequestCounts?
    public let metadata: [String: String]?

    public enum BatchStatus: String, Codable, Sendable {
        case validating
        case failed
        case inProgress = "in_progress"
        case finalizing
        case completed
        case expired
        case cancelling
        case cancelled
    }

    public struct BatchErrors: Codable, Sendable {
        public let object: String
        public let data: [ErrorData]

        public struct ErrorData: Codable, Sendable {
            public let code: String
            public let message: String
            public let param: String?
            public let line: Int?
        }
    }

    public struct RequestCounts: Codable, Sendable {
        public let total: Int
        public let completed: Int
        public let failed: Int
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case endpoint
        case errors
        case status
        case metadata
        case inputFileId = "input_file_id"
        case completionWindow = "completion_window"
        case outputFileId = "output_file_id"
        case errorFileId = "error_file_id"
        case createdAt = "created_at"
        case inProgressAt = "in_progress_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case failedAt = "failed_at"
        case expiredAt = "expired_at"
        case cancellingAt = "cancelling_at"
        case cancelledAt = "cancelled_at"
        case requestCounts = "request_counts"
    }
}

/// Batch request item (for JSONL file)
public struct OpenAIBatchRequest: Codable, Sendable {
    public let customId: String
    public let method: String
    public let url: String
    public let body: OpenAIRequest

    public init(customId: String, method: String = "POST", url: String = "/v1/chat/completions", body: OpenAIRequest) {
        self.customId = customId
        self.method = method
        self.url = url
        self.body = body
    }

    enum CodingKeys: String, CodingKey {
        case method
        case url
        case body
        case customId = "custom_id"
    }
}

/// Batch result item
public struct OpenAIBatchResult: Codable, Sendable {
    public let id: String
    public let customId: String
    public let response: BatchResponse?
    public let error: BatchError?

    public struct BatchResponse: Codable, Sendable {
        public let statusCode: Int
        public let requestId: String?
        public let body: OpenAIResponse

        enum CodingKeys: String, CodingKey {
            case body
            case statusCode = "status_code"
            case requestId = "request_id"
        }
    }

    public struct BatchError: Codable, Sendable {
        public let code: String?
        public let message: String
    }

    enum CodingKeys: String, CodingKey {
        case id
        case error
        case response
        case customId = "custom_id"
    }
}

/// Batch creation request
public struct OpenAICreateBatchRequest: Codable, Sendable {
    public let inputFileId: String
    public let endpoint: String
    public let completionWindow: String
    public let metadata: [String: String]?

    public init(
        inputFileId: String,
        endpoint: String = "/v1/chat/completions",
        completionWindow: String = "24h",
        metadata: [String: String]? = nil
    ) {
        self.inputFileId = inputFileId
        self.endpoint = endpoint
        self.completionWindow = completionWindow
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case endpoint
        case metadata
        case inputFileId = "input_file_id"
        case completionWindow = "completion_window"
    }
}

/// List batches response
public struct OpenAIBatchList: Codable, Sendable {
    public let object: String
    public let data: [OpenAIBatch]
    public let firstId: String?
    public let lastId: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case object
        case data
        case firstId = "first_id"
        case lastId = "last_id"
        case hasMore = "has_more"
    }
}
```

#### 3.8 Error Response

```swift
/// OpenAI error response
public struct OpenAIErrorResponse: Codable, Sendable {
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let type: String
        public let param: String?
        public let code: String?
    }
}
```

#### 3.9 Helper Types

```swift
/// Helper for encoding arbitrary JSON values
public struct AnyCodable: Codable, Sendable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value"
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simplified equality - enhance as needed
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}
```

---

## Provider Implementation

### File: `Sources/SwiftlyAIKit/Providers/OpenAIProvider.swift`

**Estimated Size:** ~600 lines (mirrors AnthropicProvider.swift)

#### 4.1 Provider Structure

```swift
import Foundation
import AsyncHTTPClient
import Vapor

/// OpenAI provider implementation for GPT models
public struct OpenAIProvider: ProviderProtocol {
    public let providerType: ProviderType = .openai

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let organizationId: String?
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize OpenAI provider
    /// - Parameters:
    ///   - baseURL: Base URL for OpenAI API (default: https://api.openai.com/v1)
    ///   - organizationId: Optional organization ID for multi-tenant accounts
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://api.openai.com/v1",
        organizationId: String? = nil,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = HTTPClientManager.shared
        self.baseURL = baseURL
        self.organizationId = organizationId
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        let openAIRequest = try mapToOpenAIRequest(request)
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let response: OpenAIResponse = try await httpClient.post(
            url: "\(baseURL)/chat/completions",
            body: openAIRequest,
            headers: headers,
            timeout: timeout,
            maxRetries: maxRetries,
            enableLogging: enableLogging
        )

        return mapToAIResponse(response)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var openAIRequest = try mapToOpenAIRequest(request)
                    openAIRequest.stream = true

                    let headers = buildHeaders(apiKey: apiKey, stream: true)

                    let stream = try await httpClient.stream(
                        url: "\(baseURL)/chat/completions",
                        body: openAIRequest,
                        headers: headers,
                        timeout: timeout
                    )

                    var accumulatedContent = ""

                    for try await chunk in stream {
                        let lines = chunk.split(separator: "\n")

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)

                            // Check for stream end signal
                            if trimmed == "data: [DONE]" {
                                continuation.finish()
                                return
                            }

                            // Parse SSE format: "data: {...}"
                            guard trimmed.hasPrefix("data: ") else { continue }

                            let jsonString = String(trimmed.dropFirst(6))
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            let streamChunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData)

                            // Extract delta content
                            if let delta = streamChunk.choices.first?.delta,
                               let content = delta.content {
                                accumulatedContent += content

                                // Create incremental response
                                let response = AIResponse(
                                    id: streamChunk.id,
                                    content: accumulatedContent,
                                    model: streamChunk.model,
                                    provider: .openai,
                                    stopReason: nil,
                                    usage: nil,
                                    raw: nil
                                )

                                continuation.yield(response)
                            }

                            // Check for finish
                            if let finishReason = streamChunk.choices.first?.finishReason {
                                let finalResponse = AIResponse(
                                    id: streamChunk.id,
                                    content: accumulatedContent,
                                    model: streamChunk.model,
                                    provider: .openai,
                                    stopReason: mapFinishReason(finishReason),
                                    usage: nil,
                                    raw: nil
                                )

                                continuation.yield(finalResponse)
                                continuation.finish()
                                return
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

    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int? {
        // OpenAI doesn't have a dedicated token counting endpoint
        // Token count is returned in the usage field of responses
        // Return nil here - token counting happens post-response
        return nil
    }

    // MARK: - Batch Operations

    public func createBatch(_ requests: [AIRequest], apiKey: String) async throws -> String {
        // Step 1: Create JSONL content with batch requests
        var jsonlLines: [String] = []

        for (index, request) in requests.enumerated() {
            let openAIRequest = try mapToOpenAIRequest(request)
            let batchRequest = OpenAIBatchRequest(
                customId: "request-\(index)",
                body: openAIRequest
            )

            let jsonData = try JSONEncoder().encode(batchRequest)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            jsonlLines.append(jsonString)
        }

        let jsonlContent = jsonlLines.joined(separator: "\n")

        // Step 2: Upload JSONL file
        let fileId = try await uploadFile(content: jsonlContent, apiKey: apiKey)

        // Step 3: Create batch with file ID
        let createRequest = OpenAICreateBatchRequest(inputFileId: fileId)
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let batch: OpenAIBatch = try await httpClient.post(
            url: "\(baseURL)/batches",
            body: createRequest,
            headers: headers,
            timeout: timeout
        )

        return batch.id
    }

    public func retrieveBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus {
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let batch: OpenAIBatch = try await httpClient.get(
            url: "\(baseURL)/batches/\(batchId)",
            headers: headers,
            timeout: timeout
        )

        return mapToBatchStatus(batch)
    }

    public func cancelBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus {
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let batch: OpenAIBatch = try await httpClient.post(
            url: "\(baseURL)/batches/\(batchId)/cancel",
            headers: headers,
            timeout: timeout
        )

        return mapToBatchStatus(batch)
    }

    public func listBatches(limit: Int?, afterId: String?, apiKey: String) async throws -> [BatchStatus] {
        var queryParams: [String] = []
        if let limit = limit {
            queryParams.append("limit=\(limit)")
        }
        if let afterId = afterId {
            queryParams.append("after=\(afterId)")
        }

        let queryString = queryParams.isEmpty ? "" : "?" + queryParams.joined(separator: "&")
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let list: OpenAIBatchList = try await httpClient.get(
            url: "\(baseURL)/batches\(queryString)",
            headers: headers,
            timeout: timeout
        )

        return list.data.map { mapToBatchStatus($0) }
    }

    public func getBatchResults(_ batchId: String, apiKey: String) -> AsyncThrowingStream<BatchResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Retrieve batch to get output file ID
                    let batch = try await retrieveBatch(batchId, apiKey: apiKey)

                    guard let outputFileId = batch.outputFileId else {
                        throw AIError.batchNotReady(batchId: batchId)
                    }

                    // Download results file
                    let headers = buildHeaders(apiKey: apiKey, stream: false)
                    let fileContent: String = try await httpClient.get(
                        url: "\(baseURL)/files/\(outputFileId)/content",
                        headers: headers,
                        timeout: timeout
                    )

                    // Parse JSONL results
                    let lines = fileContent.split(separator: "\n")

                    for line in lines {
                        guard !line.isEmpty else { continue }

                        let jsonData = Data(line.utf8)
                        let result = try JSONDecoder().decode(OpenAIBatchResult.self, from: jsonData)

                        let batchResult = mapToBatchResult(result)
                        continuation.yield(batchResult)
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private func buildHeaders(apiKey: String, stream: Bool) -> [(String, String)] {
        var headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        if let orgId = organizationId {
            headers.append(("OpenAI-Organization", orgId))
        }

        if stream {
            headers.append(("Accept", "text/event-stream"))
        }

        return headers
    }

    private func mapToOpenAIRequest(_ request: AIRequest) throws -> OpenAIRequest {
        var messages: [OpenAIMessage] = []

        // Add system message if present (OpenAI uses messages array, not separate parameter)
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            messages.append(OpenAIMessage(
                role: .system,
                content: .text(systemPrompt)
            ))
        }

        // Map AIMessage to OpenAIMessage
        for message in request.messages {
            let openAIMessage = try mapMessage(message)
            messages.append(openAIMessage)
        }

        return OpenAIRequest(
            model: request.model,
            messages: messages,
            maxTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            stop: request.stopSequences,
            tools: request.tools.map { mapTools($0) },
            toolChoice: request.toolChoice.map { mapToolChoice($0) }
        )
    }

    private func mapMessage(_ message: AIMessage) throws -> OpenAIMessage {
        let role: OpenAIMessage.Role = message.role == .user ? .user : .assistant

        // Handle different content types
        if message.content.count == 1, case .text(let text) = message.content[0] {
            // Simple text message
            return OpenAIMessage(role: role, content: .text(text))
        } else {
            // Multi-part content (text + images)
            let contentBlocks = try message.content.map { try mapContentBlock($0) }
            return OpenAIMessage(role: role, content: .contentArray(contentBlocks))
        }
    }

    private func mapContentBlock(_ block: AIContentBlock) throws -> OpenAIContentBlock {
        switch block {
        case .text(let text):
            return .text(text)

        case .image(let source, let mediaType):
            switch source {
            case .url(let url):
                return .imageUrl(url: url, detail: .auto)

            case .base64(let data):
                // Convert to data URL format
                let mimeType = mediaType ?? "image/jpeg"
                let dataUrl = "data:\(mimeType);base64,\(data)"
                return .imageUrl(url: dataUrl, detail: .auto)
            }

        case .toolUse, .toolResult:
            throw AIError.unsupportedFeature("Tool use mapping not yet implemented")
        }
    }

    private func mapTools(_ tools: [AIToolDefinition]) -> [OpenAIToolDefinition] {
        tools.map { tool in
            OpenAIToolDefinition(
                function: OpenAIToolDefinition.FunctionDefinition(
                    name: tool.name,
                    description: tool.description,
                    parameters: tool.inputSchema.mapValues { AnyCodable($0) }
                )
            )
        }
    }

    private func mapToolChoice(_ choice: AIToolChoice) -> OpenAIToolChoice {
        switch choice {
        case .auto:
            return .auto
        case .any:
            return .required
        case .tool(let name):
            return .function(name)
        }
    }

    private func mapToAIResponse(_ response: OpenAIResponse) -> AIResponse {
        guard let firstChoice = response.choices.first else {
            return AIResponse(
                id: response.id,
                content: "",
                model: response.model,
                provider: .openai,
                stopReason: nil,
                usage: nil,
                raw: nil
            )
        }

        let content = extractContent(from: firstChoice.message)

        let usage = AIUsage(
            inputTokens: response.usage.promptTokens,
            outputTokens: response.usage.completionTokens,
            totalTokens: response.usage.totalTokens
        )

        return AIResponse(
            id: response.id,
            content: content,
            model: response.model,
            provider: .openai,
            stopReason: firstChoice.finishReason.map { mapFinishReason($0) },
            usage: usage,
            raw: nil
        )
    }

    private func extractContent(from message: OpenAIMessage) -> String {
        switch message.content {
        case .text(let text):
            return text
        case .contentArray(let blocks):
            return blocks.compactMap { block in
                if case .text(let text) = block {
                    return text
                }
                return nil
            }.joined(separator: "\n")
        case .none:
            return ""
        }
    }

    private func mapFinishReason(_ reason: String) -> AIStopReason {
        switch reason {
        case "stop":
            return .endTurn
        case "length":
            return .maxTokens
        case "tool_calls":
            return .toolUse
        case "content_filter":
            return .contentFilter
        default:
            return .other(reason)
        }
    }

    private func mapToBatchStatus(_ batch: OpenAIBatch) -> BatchStatus {
        BatchStatus(
            id: batch.id,
            status: mapBatchStatus(batch.status),
            createdAt: Date(timeIntervalSince1970: TimeInterval(batch.createdAt)),
            completedAt: batch.completedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            expiresAt: batch.expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            requestCounts: batch.requestCounts.map {
                BatchRequestCounts(
                    total: $0.total,
                    completed: $0.completed,
                    failed: $0.failed
                )
            },
            outputFileId: batch.outputFileId,
            errorFileId: batch.errorFileId
        )
    }

    private func mapBatchStatus(_ status: OpenAIBatch.BatchStatus) -> BatchStatusType {
        switch status {
        case .validating:
            return .processing
        case .inProgress, .finalizing:
            return .processing
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .expired:
            return .expired
        case .cancelling, .cancelled:
            return .cancelled
        }
    }

    private func mapToBatchResult(_ result: OpenAIBatchResult) -> BatchResult {
        if let response = result.response {
            let aiResponse = mapToAIResponse(response.body)
            return BatchResult(
                customId: result.customId,
                response: aiResponse,
                error: nil
            )
        } else if let error = result.error {
            return BatchResult(
                customId: result.customId,
                response: nil,
                error: AIError.providerError(
                    provider: .openai,
                    statusCode: 500,
                    message: error.message
                )
            )
        } else {
            return BatchResult(
                customId: result.customId,
                response: nil,
                error: AIError.invalidResponse(message: "No response or error in batch result")
            )
        }
    }

    private func uploadFile(content: String, apiKey: String) async throws -> String {
        // Create multipart form data for file upload
        let boundary = UUID().uuidString
        var body = Data()

        // Add purpose field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        body.append("batch\r\n".data(using: .utf8)!)

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"batch.jsonl\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/jsonl\r\n\r\n".data(using: .utf8)!)
        body.append(content.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "multipart/form-data; boundary=\(boundary)")
        ]

        if let orgId = organizationId {
            headers.append(("OpenAI-Organization", orgId))
        }

        // Upload file and get file ID
        struct FileUploadResponse: Codable {
            let id: String
        }

        let response: FileUploadResponse = try await httpClient.post(
            url: "\(baseURL)/files",
            body: body,
            headers: headers,
            timeout: timeout
        )

        return response.id
    }
}

// MARK: - Error Mapping Extension

extension OpenAIProvider {
    func mapOpenAIError(_ error: OpenAIErrorResponse) -> AIError {
        switch error.error.type {
        case "invalid_request_error":
            return .invalidRequest(message: error.error.message)

        case "authentication_error":
            return .invalidAPIKey(provider: .openai, message: error.error.message)

        case "permission_error":
            return .permissionDenied(provider: .openai, message: error.error.message)

        case "not_found_error":
            return .notFound(resource: "endpoint", provider: .openai)

        case "rate_limit_error":
            return .rateLimitExceeded(provider: .openai, retryAfter: nil)

        case "api_error", "server_error":
            return .internalError(provider: .openai, message: error.error.message)

        default:
            return .providerError(
                provider: .openai,
                statusCode: 500,
                message: error.error.message
            )
        }
    }
}
```

---

## Feature Comparison

### 5.1 Similar Features

| Feature | OpenAI | Anthropic | Implementation Notes |
|---------|--------|-----------|---------------------|
| Chat Completions | ✅ | ✅ | Both use messages array format |
| Streaming | ✅ | ✅ | Both use SSE, different end signals |
| Tool/Function Calling | ✅ | ✅ | Similar JSON schema, different param names |
| Vision (Images) | ✅ | ✅ | Both support base64 and URLs |
| Batch Processing | ✅ | ✅ | Both offer async batch API with cost savings |
| Token Counting | ✅ | ✅ | OpenAI returns in response, Anthropic has endpoint |
| Stop Sequences | ✅ | ✅ | Custom stop strings supported |
| Temperature Control | ✅ | ✅ | 0.0 - 2.0 range (OpenAI), 0.0 - 1.0 (Anthropic) |
| Top-P Sampling | ✅ | ✅ | Nucleus sampling supported |

### 5.2 OpenAI-Specific Features

**Present in OpenAI, Not in Anthropic:**

| Feature | Description | Parameter |
|---------|-------------|-----------|
| Multiple Completions | Generate N different responses | `n: Int` |
| Logit Bias | Modify token likelihood | `logit_bias: [String: Double]` |
| Presence Penalty | Penalize repeated topics | `presence_penalty: Double` (-2.0 to 2.0) |
| Frequency Penalty | Penalize repeated tokens | `frequency_penalty: Double` (-2.0 to 2.0) |
| Deterministic Sampling | Reproducible outputs | `seed: Int` |
| JSON Mode | Force JSON output | `response_format: {type: "json_object"}` |
| Log Probabilities | Token probability info | `logprobs: Bool`, `top_logprobs: Int` |

**Present in Anthropic, Not in OpenAI:**

| Feature | Description | Notes |
|---------|-------------|-------|
| Prompt Caching | Cache prompt prefixes for cost savings | Reduces repeat costs up to 90% |
| Extended Thinking | Explicit reasoning mode | Separate thinking blocks |
| PDF Support | Native PDF parsing | Built-in document understanding |
| Thinking Content | Separate reasoning from output | Different content block type |

### 5.3 Key Implementation Differences

| Aspect | OpenAI | Anthropic | Impact on Mapping |
|--------|--------|-----------|-------------------|
| **Auth Header** | `Authorization: Bearer <key>` | `x-api-key: <key>` | Different header builder |
| **API Version** | In URL path (`/v1/`) | Header (`anthropic-version: 2023-06-01`) | URL vs header |
| **System Message** | Part of messages array | Separate `system` parameter | Prepend to messages |
| **Max Tokens** | Optional (has smart defaults) | Required field | Make optional in mapper |
| **Message Roles** | 4 types (system/user/assistant/tool) | 2 types (user/assistant) | Role mapping required |
| **Stop Reason** | `finish_reason` field | `stop_reason` field | Different field names |
| **Streaming End** | `data: [DONE]` string | `message_stop` event type | Different parsing |
| **Image Format** | `image_url` with URL or data URL | `image` with source type | Format conversion |
| **Tool Choice** | String or object | String | Type difference |
| **Error Format** | `error.type` categorization | HTTP status codes | Error mapping differs |

---

## Special Considerations

### 6.1 Rate Limiting & Error Handling

#### Rate Limit Strategy

OpenAI provides rate limit information in response headers:

```
x-ratelimit-limit-requests: 10000
x-ratelimit-limit-tokens: 2000000
x-ratelimit-remaining-requests: 9999
x-ratelimit-remaining-tokens: 1999000
x-ratelimit-reset-requests: 8.64s
x-ratelimit-reset-tokens: 6ms
```

**Implementation Approach:**

1. **Exponential Backoff with Jitter**
   ```swift
   private func calculateBackoff(attempt: Int) -> TimeInterval {
       let baseDelay = 1.0
       let exponentialDelay = pow(2.0, Double(attempt - 1))
       let jitter = Double.random(in: 0...0.1)
       return min(baseDelay * exponentialDelay + jitter, 60.0)
   }
   ```

2. **Retry Logic**
   - Retry on HTTP 429 (rate limit)
   - Retry on HTTP 500, 503 (server errors)
   - DO NOT retry on 400, 401, 403, 404 (client errors)
   - Maximum 3 retry attempts by default

3. **Rate Limit Headers Parsing**
   ```swift
   private func parseRateLimitHeaders(_ headers: HTTPHeaders) -> RateLimitInfo? {
       guard let remaining = headers.first(name: "x-ratelimit-remaining-requests"),
             let resetTime = headers.first(name: "x-ratelimit-reset-requests") else {
           return nil
       }

       return RateLimitInfo(
           remaining: Int(remaining) ?? 0,
           resetTime: parseResetTime(resetTime)
       )
   }
   ```

#### Error Code Mapping

```swift
private func mapOpenAIError(_ error: OpenAIErrorResponse, statusCode: Int) -> AIError {
    switch error.error.type {
    case "invalid_request_error":
        // Bad request - check if it's model-specific
        if error.error.message.contains("model") {
            return .modelNotFound(model: "", provider: .openai)
        }
        return .invalidRequest(message: error.error.message)

    case "authentication_error":
        return .invalidAPIKey(provider: .openai, message: error.error.message)

    case "permission_error":
        return .permissionDenied(provider: .openai, message: error.error.message)

    case "not_found_error":
        return .notFound(resource: error.error.param ?? "endpoint", provider: .openai)

    case "rate_limit_error":
        // Extract retry-after if available
        let retryAfter = extractRetryAfter(from: error.error.message)
        return .rateLimitExceeded(provider: .openai, retryAfter: retryAfter)

    case "api_error", "server_error":
        return .internalError(provider: .openai, message: error.error.message)

    case "tokens_exceeded":
        return .maxTokensExceeded(
            requested: nil,
            limit: nil,
            provider: .openai
        )

    default:
        return .providerError(
            provider: .openai,
            statusCode: statusCode,
            message: error.error.message
        )
    }
}
```

**Common Error Types:**

| Error Type | HTTP Status | Description | Retry? |
|------------|-------------|-------------|--------|
| `invalid_request_error` | 400 | Malformed request | ❌ No |
| `authentication_error` | 401 | Invalid API key | ❌ No |
| `permission_error` | 403 | Insufficient permissions | ❌ No |
| `not_found_error` | 404 | Resource not found | ❌ No |
| `rate_limit_error` | 429 | Rate limit exceeded | ✅ Yes |
| `api_error` | 500 | OpenAI server error | ✅ Yes |
| `server_error` | 503 | Service unavailable | ✅ Yes |

### 6.2 Token Counting

OpenAI doesn't provide a dedicated token counting endpoint. Two approaches:

#### Approach 1: Extract from Response (Recommended)

```swift
public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int? {
    // Return nil - token counting happens post-response via usage field
    // The AIResponse will contain usage.inputTokens and usage.outputTokens
    return nil
}
```

**Pros:**
- No additional API calls required
- Accurate token counts from actual request
- Includes both input and output tokens

**Cons:**
- Can't pre-calculate tokens before sending
- Requires making the actual API call

#### Approach 2: Client-Side Estimation (Future Enhancement)

OpenAI uses tiktoken for tokenization. Could add Swift implementation:

```swift
// Future enhancement - not in initial implementation
public func estimateTokens(_ text: String, model: String) -> Int {
    // Use tiktoken-style tokenizer
    // Different encodings for different models:
    // - gpt-4, gpt-3.5-turbo: cl100k_base
    // - Older models: p50k_base, r50k_base
    return tiktoken.encode(text, encoding: encodingForModel(model)).count
}
```

**Decision:** Use Approach 1 for initial implementation. Document limitation in code comments.

### 6.3 Batch Processing

OpenAI's Batch API differs significantly from Anthropic's approach:

#### Batch Workflow Comparison

**OpenAI:**
1. Create JSONL file locally
2. Upload file via Files API → get `file_id`
3. Create batch with `input_file_id`
4. Poll batch status (validating → in_progress → completed)
5. Download output file via Files API
6. Parse JSONL results

**Anthropic:**
1. Send batch request with inline requests array
2. Get batch ID immediately
3. Poll batch status
4. Stream results via dedicated endpoint
5. No file upload/download required

#### Implementation Details

**File Upload (multipart/form-data):**

```swift
private func uploadBatchFile(content: String, apiKey: String) async throws -> String {
    let boundary = "Boundary-\(UUID().uuidString)"
    var body = Data()

    // Purpose field
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
    body.append("batch\r\n".data(using: .utf8)!)

    // File field
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"batch.jsonl\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: application/jsonl\r\n\r\n".data(using: .utf8)!)
    body.append(content.data(using: .utf8)!)
    body.append("\r\n".data(using: .utf8)!)
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

    let headers = [
        ("Authorization", "Bearer \(apiKey)"),
        ("Content-Type", "multipart/form-data; boundary=\(boundary)")
    ]

    struct UploadResponse: Codable {
        let id: String
    }

    let response: UploadResponse = try await httpClient.post(
        url: "\(baseURL)/files",
        body: body,
        headers: headers
    )

    return response.id
}
```

**JSONL Format:**

Each line is a separate JSON object:

```json
{"custom_id": "request-1", "method": "POST", "url": "/v1/chat/completions", "body": {"model": "gpt-4o", "messages": [...]}}
{"custom_id": "request-2", "method": "POST", "url": "/v1/chat/completions", "body": {"model": "gpt-4o", "messages": [...]}}
```

**Results Parsing:**

```swift
public func getBatchResults(_ batchId: String, apiKey: String) -> AsyncThrowingStream<BatchResult, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                // Get batch to find output file
                let batch = try await retrieveBatch(batchId, apiKey: apiKey)

                guard let fileId = batch.outputFileId else {
                    throw AIError.batchNotReady(batchId: batchId)
                }

                // Download file content
                let content: String = try await httpClient.get(
                    url: "\(baseURL)/files/\(fileId)/content",
                    headers: buildHeaders(apiKey: apiKey, stream: false)
                )

                // Parse JSONL line by line
                for line in content.split(separator: "\n") {
                    let data = Data(line.utf8)
                    let result = try JSONDecoder().decode(OpenAIBatchResult.self, from: data)
                    continuation.yield(mapToBatchResult(result))
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```

### 6.4 System Messages

**Key Difference:** OpenAI treats system messages as the first message in the messages array, not a separate parameter.

#### Mapping Strategy

```swift
private func mapToOpenAIRequest(_ request: AIRequest) throws -> OpenAIRequest {
    var messages: [OpenAIMessage] = []

    // System prompt becomes first message
    if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
        messages.append(OpenAIMessage(
            role: .system,
            content: .text(systemPrompt)
        ))
    }

    // Add user/assistant messages
    for message in request.messages {
        messages.append(try mapMessage(message))
    }

    return OpenAIRequest(
        model: request.model,
        messages: messages,
        // ... other params
    )
}
```

#### Best Practices

From OpenAI documentation:
- System message should be the **first** message in the array
- Can have multiple system messages (they'll be concatenated)
- System messages have stronger influence than user messages
- Use for: role definition, behavior guidelines, output format instructions

**Example:**

```swift
// ✅ Correct
[
    {role: "system", content: "You are a helpful assistant."},
    {role: "user", content: "Hello!"}
]

// ❌ Incorrect - system message not first
[
    {role: "user", content: "Hello!"},
    {role: "system", content: "You are a helpful assistant."}
]
```

### 6.5 Vision Support

OpenAI supports vision in GPT-4o, GPT-4 Turbo, and GPT-4 Vision models.

#### Image Input Formats

**Option 1: URL**
```json
{
  "type": "image_url",
  "image_url": {
    "url": "https://example.com/image.jpg",
    "detail": "high"
  }
}
```

**Option 2: Base64 Data URL**
```json
{
  "type": "image_url",
  "image_url": {
    "url": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
    "detail": "auto"
  }
}
```

#### Detail Parameter

Controls image processing quality and token cost:

| Detail | Description | Token Cost | Use Case |
|--------|-------------|------------|----------|
| `low` | Low-res 512x512 | 85 tokens | Quick analysis, icons |
| `high` | Detailed tiles | 85 + 170*tiles | OCR, fine details |
| `auto` | AI chooses based on size | Variable | Default, balanced |

#### Mapping from AIMessage

```swift
private func mapContentBlock(_ block: AIContentBlock) throws -> OpenAIContentBlock {
    switch block {
    case .text(let text):
        return .text(text)

    case .image(let source, let mediaType):
        switch source {
        case .url(let url):
            // External URL - use directly
            return .imageUrl(url: url, detail: .auto)

        case .base64(let data):
            // Base64 data - convert to data URL
            let mimeType = mediaType ?? "image/jpeg"
            let dataUrl = "data:\(mimeType);base64,\(data)"
            return .imageUrl(url: dataUrl, detail: .auto)
        }

    case .toolUse, .toolResult:
        throw AIError.unsupportedFeature("Tool blocks not yet implemented")
    }
}
```

#### Image Size Limits

- **Max file size:** 20MB
- **Supported formats:** PNG, JPEG, WEBP, GIF (non-animated)
- **Recommended size:** 768x768 or 2000x768 for detailed analysis
- **Auto-resize:** Images larger than 2048x2048 are resized

### 6.6 Streaming Implementation

OpenAI uses Server-Sent Events (SSE) format with specific termination signal.

#### SSE Format

```
data: {"id":"chatcmpl-123","object":"chat.completion.chunk",...}

data: {"id":"chatcmpl-123","object":"chat.completion.chunk",...}

data: [DONE]
```

#### Key Differences from Anthropic

| Aspect | OpenAI | Anthropic |
|--------|--------|-----------|
| Event Types | No event types, just `data:` | Multiple event types (message_start, content_block_delta, etc.) |
| End Signal | `data: [DONE]` string | `message_stop` event |
| Delta Format | Single delta object | Separate events per content block |
| Tool Calls | Streaming with index | Separate tool_use blocks |

#### Parsing Implementation

```swift
public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                var openAIRequest = try mapToOpenAIRequest(request)
                openAIRequest.stream = true

                let stream = try await httpClient.stream(
                    url: "\(baseURL)/chat/completions",
                    body: openAIRequest,
                    headers: buildHeaders(apiKey: apiKey, stream: true)
                )

                var accumulated = ""
                var responseId = ""
                var model = ""

                for try await chunk in stream {
                    // Split by newlines (SSE format)
                    let lines = chunk.split(separator: "\n")

                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)

                        // Check for termination
                        if trimmed == "data: [DONE]" {
                            // Send final response
                            let final = AIResponse(
                                id: responseId,
                                content: accumulated,
                                model: model,
                                provider: .openai,
                                stopReason: .endTurn,
                                usage: nil
                            )
                            continuation.yield(final)
                            continuation.finish()
                            return
                        }

                        // Parse SSE data line
                        guard trimmed.hasPrefix("data: ") else { continue }

                        let jsonString = String(trimmed.dropFirst(6))
                        guard let jsonData = jsonString.data(using: .utf8) else { continue }

                        let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData)

                        // Store metadata
                        if responseId.isEmpty {
                            responseId = chunk.id
                            model = chunk.model
                        }

                        // Extract delta content
                        if let choice = chunk.choices.first,
                           let content = choice.delta.content {
                            accumulated += content

                            // Yield incremental response
                            let response = AIResponse(
                                id: responseId,
                                content: accumulated,
                                model: model,
                                provider: .openai,
                                stopReason: nil,
                                usage: nil
                            )
                            continuation.yield(response)
                        }

                        // Check for finish reason
                        if let choice = chunk.choices.first,
                           let finishReason = choice.finishReason {
                            let final = AIResponse(
                                id: responseId,
                                content: accumulated,
                                model: model,
                                provider: .openai,
                                stopReason: mapFinishReason(finishReason),
                                usage: nil
                            )
                            continuation.yield(final)
                            continuation.finish()
                            return
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
```

### 6.7 Model Selection

Update `ModelProvider.swift` with current GPT models:

```swift
// GPT-4o series (2025) - Most capable, multimodal
case gpt4o = "gpt-4o"
case gpt4oMini = "gpt-4o-mini"
case gpt4o20250514 = "gpt-4o-2025-05-14"

// GPT-4 Turbo series
case gpt4Turbo = "gpt-4-turbo"
case gpt4Turbo20240409 = "gpt-4-turbo-2024-04-09"
case gpt4TurboPreview = "gpt-4-turbo-preview"

// GPT-4 series
case gpt4 = "gpt-4"
case gpt40613 = "gpt-4-0613"

// GPT-3.5 Turbo series
case gpt35Turbo = "gpt-3.5-turbo"
case gpt35Turbo0125 = "gpt-3.5-turbo-0125"
case gpt35Turbo1106 = "gpt-3.5-turbo-1106"
```

#### Model Capabilities Matrix

| Model | Context Window | Max Output | Vision | Tools | Recommended For |
|-------|---------------|------------|--------|-------|-----------------|
| gpt-4o | 128K | 16K | ✅ | ✅ | Latest, best performance |
| gpt-4o-mini | 128K | 16K | ✅ | ✅ | Cost-effective, fast |
| gpt-4-turbo | 128K | 4K | ✅ | ✅ | High intelligence |
| gpt-4 | 8K | 4K | ❌ | ✅ | Complex reasoning |
| gpt-3.5-turbo | 16K | 4K | ❌ | ✅ | Simple tasks, speed |

#### Pricing (2025)

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Batch Discount |
|-------|----------------------|------------------------|----------------|
| gpt-4o | $2.50 | $10.00 | 50% |
| gpt-4o-mini | $0.15 | $0.60 | 50% |
| gpt-4-turbo | $10.00 | $30.00 | 50% |
| gpt-3.5-turbo | $0.50 | $1.50 | 50% |

---

## Implementation Phases

### Phase 1: Core Models (~700 lines)

**File:** `Sources/SwiftlyAIKit/Models/OpenAI/OpenAIModels.swift`

**Tasks:**
1. Define `OpenAIContentBlock` enum with text and image_url cases
2. Define `OpenAIMessage` struct with role, content, tool fields
3. Define `OpenAIRequest` struct with all parameters
4. Define `OpenAIResponse` struct with choices, usage
5. Define `OpenAIStreamChunk` for streaming
6. Define tool types: `OpenAIToolDefinition`, `OpenAIToolCall`, `OpenAIToolChoice`
7. Define batch types: `OpenAIBatch`, `OpenAIBatchRequest`, `OpenAIBatchResult`
8. Define `OpenAIErrorResponse` struct
9. Add `AnyCodable` helper for JSON schema parameters
10. Implement comprehensive `Codable` conformance with snake_case mapping

**Commit Strategy:**
- Commit 1: Add message and content block models
- Commit 2: Add request and response models
- Commit 3: Add tool calling models
- Commit 4: Add streaming and batch models
- Commit 5: Add error models and helpers

### Phase 2: Provider Implementation (~600 lines)

**File:** `Sources/SwiftlyAIKit/Providers/OpenAIProvider.swift`

**Tasks:**
1. Implement provider struct with initialization
2. Implement `sendMessage()` method
3. Implement `streamMessage()` method with SSE parsing
4. Implement `countTokens()` method (return nil, extract from usage)
5. Implement batch operations:
   - `createBatch()` with file upload
   - `retrieveBatch()`
   - `cancelBatch()`
   - `listBatches()`
   - `getBatchResults()` with file download
6. Implement mapping functions:
   - `mapToOpenAIRequest()` - handle system messages
   - `mapToAIResponse()`
   - `mapMessage()`
   - `mapContentBlock()`
   - `mapTools()`, `mapToolChoice()`
   - `mapFinishReason()`
   - `mapToBatchStatus()`, `mapToBatchResult()`
7. Implement `buildHeaders()` helper
8. Implement `uploadFile()` for batch processing
9. Add error handling and retry logic
10. Add comprehensive logging

**Commit Strategy:**
- Commit 6: Implement provider structure and initialization
- Commit 7: Implement sendMessage() and core mapping
- Commit 8: Implement streaming support
- Commit 9: Implement batch operations
- Commit 10: Add error handling and retry logic

### Phase 3: Model Definitions (~50 lines)

**File:** `Sources/SwiftlyAIKit/Models/ModelProvider.swift`

**Tasks:**
1. Add GPT-4o model cases (gpt-4o, gpt-4o-mini)
2. Add GPT-4 Turbo model cases
3. Add GPT-4 model cases
4. Add GPT-3.5 Turbo model cases
5. Update model capabilities:
   - Vision support flags
   - Tool calling support flags
   - Context window sizes
   - Max output token limits
6. Update provider type mapping

**Commit Strategy:**
- Commit 11: Add OpenAI model definitions and capabilities

### Phase 4: Testing (~400 lines)

**Files:**
- `Tests/SwiftlyAIKitTests/ProviderTests/OpenAIProviderTests.swift`
- `Tests/SwiftlyAIKitTests/Mocks/MockOpenAIAPI.swift`
- `Tests/SwiftlyAIKitTests/Mocks/TestData/OpenAI/` (JSON files)

**Tasks:**
1. Create `MockOpenAIAPI` with sample responses
2. Create test data JSON files:
   - `chat_completion_response.json`
   - `stream_chunk.json`
   - `batch_response.json`
   - `batch_result.json`
   - `error_response.json`
3. Test request mapping:
   - System message prepending
   - Image content mapping
   - Tool definition mapping
4. Test response mapping:
   - Standard response parsing
   - Usage extraction
   - Finish reason mapping
5. Test streaming:
   - SSE parsing
   - Delta accumulation
   - [DONE] signal handling
6. Test batch operations:
   - File upload
   - Batch creation
   - Status polling
   - Results parsing
7. Test error handling:
   - Error response parsing
   - Error code mapping
   - Retry logic
8. Integration tests with mock HTTP client

**Commit Strategy:**
- Commit 12: Add test infrastructure and mock API
- Commit 13: Add request/response mapping tests
- Commit 14: Add streaming tests
- Commit 15: Add batch operation tests
- Commit 16: Add error handling tests

### Phase 5: Documentation

**Files:**
- `README.md`
- `CHANGELOG.md`
- `Examples/` (optional)

**Tasks:**
1. Update README.md:
   - Add OpenAI to supported providers list
   - Add OpenAI usage examples
   - Add configuration examples
   - Update features table
2. Update CHANGELOG.md:
   - Add entry under `[Unreleased]` section
   - List all new OpenAI features
   - Note GPT-4o, GPT-4 Turbo support
3. Add DocC comments to public APIs
4. Create example Vapor endpoint (optional)

**Commit Strategy:**
- Commit 17: Update README with OpenAI examples
- Commit 18: Update CHANGELOG.md with OpenAI features

### Phase 6: Integration & Polish

**Tasks:**
1. Run full test suite: `swift test`
2. Verify build: `swift build`
3. Check test coverage
4. Fix any issues or warnings
5. Update documentation if needed
6. Create GitHub tag if releasing

**Commit Strategy:**
- Commit 19: Fix any issues found during integration testing
- Commit 20: Final documentation polish

---

## Testing Strategy

### 8.1 Unit Tests

**Test Coverage Goals:** 100% for public APIs, 90%+ overall

#### Request Mapping Tests

```swift
@Test("System message is prepended to messages array")
func testSystemMessageMapping() async throws {
    let provider = OpenAIProvider()

    let request = AIRequest(
        model: "gpt-4o",
        messages: [
            AIMessage(role: .user, content: [.text("Hello")])
        ],
        systemPrompt: "You are a helpful assistant."
    )

    let openAIRequest = try provider.mapToOpenAIRequest(request)

    #expect(openAIRequest.messages.count == 2)
    #expect(openAIRequest.messages[0].role == .system)
    #expect(openAIRequest.messages[0].content == .text("You are a helpful assistant."))
    #expect(openAIRequest.messages[1].role == .user)
}

@Test("Image content is mapped to image_url format")
func testImageContentMapping() async throws {
    let provider = OpenAIProvider()

    let request = AIRequest(
        model: "gpt-4o",
        messages: [
            AIMessage(role: .user, content: [
                .text("What's in this image?"),
                .image(source: .url("https://example.com/image.jpg"), mediaType: "image/jpeg")
            ])
        ]
    )

    let openAIRequest = try provider.mapToOpenAIRequest(request)

    guard case .contentArray(let blocks) = openAIRequest.messages[0].content else {
        throw TestError("Expected content array")
    }

    #expect(blocks.count == 2)
    #expect(blocks[0] == .text("What's in this image?"))

    if case .imageUrl(let url, let detail) = blocks[1] {
        #expect(url == "https://example.com/image.jpg")
        #expect(detail == .auto)
    } else {
        throw TestError("Expected image_url block")
    }
}

@Test("Base64 image is converted to data URL")
func testBase64ImageMapping() async throws {
    let provider = OpenAIProvider()
    let base64Data = "iVBORw0KGgoAAAANSUhEUgA..."

    let request = AIRequest(
        model: "gpt-4o",
        messages: [
            AIMessage(role: .user, content: [
                .image(source: .base64(base64Data), mediaType: "image/png")
            ])
        ]
    )

    let openAIRequest = try provider.mapToOpenAIRequest(request)

    guard case .contentArray(let blocks) = openAIRequest.messages[0].content,
          case .imageUrl(let url, _) = blocks[0] else {
        throw TestError("Expected image_url block")
    }

    #expect(url.hasPrefix("data:image/png;base64,"))
    #expect(url.contains(base64Data))
}
```

#### Response Mapping Tests

```swift
@Test("Response is correctly mapped to AIResponse")
func testResponseMapping() async throws {
    let provider = OpenAIProvider()

    let openAIResponse = OpenAIResponse(
        id: "chatcmpl-123",
        object: "chat.completion",
        created: 1677652288,
        model: "gpt-4o",
        choices: [
            OpenAIResponse.Choice(
                index: 0,
                message: OpenAIMessage(
                    role: .assistant,
                    content: .text("Hello! How can I help you?")
                ),
                finishReason: "stop",
                logprobs: nil
            )
        ],
        usage: OpenAIResponse.Usage(
            promptTokens: 10,
            completionTokens: 20,
            totalTokens: 30
        ),
        systemFingerprint: "fp_123"
    )

    let aiResponse = provider.mapToAIResponse(openAIResponse)

    #expect(aiResponse.id == "chatcmpl-123")
    #expect(aiResponse.content == "Hello! How can I help you?")
    #expect(aiResponse.model == "gpt-4o")
    #expect(aiResponse.provider == .openai)
    #expect(aiResponse.stopReason == .endTurn)
    #expect(aiResponse.usage?.inputTokens == 10)
    #expect(aiResponse.usage?.outputTokens == 20)
    #expect(aiResponse.usage?.totalTokens == 30)
}

@Test("Finish reason is correctly mapped")
func testFinishReasonMapping() async throws {
    let testCases: [(String, AIStopReason)] = [
        ("stop", .endTurn),
        ("length", .maxTokens),
        ("tool_calls", .toolUse),
        ("content_filter", .contentFilter)
    ]

    let provider = OpenAIProvider()

    for (openAIReason, expectedReason) in testCases {
        let mapped = provider.mapFinishReason(openAIReason)
        #expect(mapped == expectedReason)
    }
}
```

#### Streaming Tests

```swift
@Test("Streaming correctly accumulates content")
func testStreamingAccumulation() async throws {
    let mockAPI = MockOpenAIAPI()
    let provider = OpenAIProvider(baseURL: mockAPI.baseURL)

    // Mock will return 3 chunks: "Hello", " there", "!"
    mockAPI.addStreamChunks([
        OpenAIStreamChunk(
            id: "chatcmpl-123",
            object: "chat.completion.chunk",
            created: 1677652288,
            model: "gpt-4o",
            choices: [
                OpenAIStreamChunk.StreamChoice(
                    index: 0,
                    delta: OpenAIStreamChunk.StreamChoice.Delta(
                        role: "assistant",
                        content: "Hello"
                    ),
                    finishReason: nil
                )
            ]
        ),
        // ... more chunks
    ])

    let request = AIRequest(
        model: "gpt-4o",
        messages: [AIMessage(role: .user, content: [.text("Hi")])]
    )

    var responses: [AIResponse] = []
    let stream = provider.streamMessage(request, apiKey: "test-key")

    for try await response in stream {
        responses.append(response)
    }

    #expect(responses.count == 3)
    #expect(responses[0].content == "Hello")
    #expect(responses[1].content == "Hello there")
    #expect(responses[2].content == "Hello there!")
}

@Test("Streaming handles [DONE] signal")
func testStreamingDoneSignal() async throws {
    let mockAPI = MockOpenAIAPI()
    mockAPI.addRawStreamData("data: [DONE]\n\n")

    let provider = OpenAIProvider(baseURL: mockAPI.baseURL)
    let request = AIRequest(
        model: "gpt-4o",
        messages: [AIMessage(role: .user, content: [.text("Hi")])]
    )

    let stream = provider.streamMessage(request, apiKey: "test-key")

    var completed = false
    for try await _ in stream {
        completed = true
    }

    #expect(completed)
}
```

#### Batch Tests

```swift
@Test("Batch creation uploads file and returns batch ID")
func testBatchCreation() async throws {
    let mockAPI = MockOpenAIAPI()
    let provider = OpenAIProvider(baseURL: mockAPI.baseURL)

    let requests = [
        AIRequest(model: "gpt-4o", messages: [
            AIMessage(role: .user, content: [.text("Hello")])
        ]),
        AIRequest(model: "gpt-4o", messages: [
            AIMessage(role: .user, content: [.text("Hi")])
        ])
    ]

    let batchId = try await provider.createBatch(requests, apiKey: "test-key")

    #expect(!batchId.isEmpty)
    #expect(batchId.hasPrefix("batch_"))
    #expect(mockAPI.uploadedFileCount == 1)
}

@Test("Batch results are correctly parsed")
func testBatchResultsParsing() async throws {
    let mockAPI = MockOpenAIAPI()
    mockAPI.mockBatchResults("""
    {"id":"batch_req_1","custom_id":"request-1","response":{"status_code":200,"body":{"id":"chatcmpl-1","choices":[{"message":{"content":"Response 1"}}],"usage":{"total_tokens":10}}}}
    {"id":"batch_req_2","custom_id":"request-2","response":{"status_code":200,"body":{"id":"chatcmpl-2","choices":[{"message":{"content":"Response 2"}}],"usage":{"total_tokens":12}}}}
    """)

    let provider = OpenAIProvider(baseURL: mockAPI.baseURL)
    let stream = provider.getBatchResults("batch_123", apiKey: "test-key")

    var results: [BatchResult] = []
    for try await result in stream {
        results.append(result)
    }

    #expect(results.count == 2)
    #expect(results[0].customId == "request-1")
    #expect(results[0].response?.content == "Response 1")
    #expect(results[1].customId == "request-2")
    #expect(results[1].response?.content == "Response 2")
}
```

#### Error Handling Tests

```swift
@Test("Invalid API key throws authentication error")
func testInvalidAPIKey() async throws {
    let mockAPI = MockOpenAIAPI()
    mockAPI.mockError(
        statusCode: 401,
        error: OpenAIErrorResponse(
            error: OpenAIErrorResponse.ErrorDetail(
                message: "Invalid API key",
                type: "authentication_error",
                param: nil,
                code: "invalid_api_key"
            )
        )
    )

    let provider = OpenAIProvider(baseURL: mockAPI.baseURL)
    let request = AIRequest(
        model: "gpt-4o",
        messages: [AIMessage(role: .user, content: [.text("Hi")])]
    )

    await #expect(throws: AIError.self) {
        try await provider.sendMessage(request, apiKey: "invalid-key")
    }
}

@Test("Rate limit error triggers retry with backoff")
func testRateLimitRetry() async throws {
    let mockAPI = MockOpenAIAPI()

    // First two attempts fail with 429, third succeeds
    mockAPI.mockErrorForAttempts(1...2,
        statusCode: 429,
        error: OpenAIErrorResponse(
            error: OpenAIErrorResponse.ErrorDetail(
                message: "Rate limit exceeded",
                type: "rate_limit_error",
                param: nil,
                code: nil
            )
        )
    )

    let provider = OpenAIProvider(
        baseURL: mockAPI.baseURL,
        maxRetries: 3
    )

    let request = AIRequest(
        model: "gpt-4o",
        messages: [AIMessage(role: .user, content: [.text("Hi")])]
    )

    let response = try await provider.sendMessage(request, apiKey: "test-key")

    #expect(mockAPI.requestCount == 3)
    #expect(!response.content.isEmpty)
}
```

### 8.2 Integration Tests

```swift
@Test("Full conversation flow with OpenAI provider")
func testConversationFlow() async throws {
    let mockAPI = MockOpenAIAPI()
    let provider = OpenAIProvider(baseURL: mockAPI.baseURL)

    // First message
    let request1 = AIRequest(
        model: "gpt-4o",
        messages: [AIMessage(role: .user, content: [.text("What is 2+2?")])],
        systemPrompt: "You are a math tutor."
    )

    let response1 = try await provider.sendMessage(request1, apiKey: "test-key")
    #expect(response1.content.contains("4"))

    // Follow-up message
    let request2 = AIRequest(
        model: "gpt-4o",
        messages: [
            AIMessage(role: .user, content: [.text("What is 2+2?")]),
            AIMessage(role: .assistant, content: [.text(response1.content)]),
            AIMessage(role: .user, content: [.text("What about 3+3?")])
        ],
        systemPrompt: "You are a math tutor."
    )

    let response2 = try await provider.sendMessage(request2, apiKey: "test-key")
    #expect(response2.content.contains("6"))
}
```

### 8.3 Test Data Files

Create test JSON files in `Tests/SwiftlyAIKitTests/Mocks/TestData/OpenAI/`:

**chat_completion_response.json:**
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "gpt-4o",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Hello! How can I help you today?"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 9,
    "completion_tokens": 12,
    "total_tokens": 21
  }
}
```

**stream_chunk.json:**
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion.chunk",
  "created": 1677652288,
  "model": "gpt-4o",
  "choices": [{
    "index": 0,
    "delta": {
      "content": "Hello"
    },
    "finish_reason": null
  }]
}
```

**batch_response.json:**
```json
{
  "id": "batch_abc123",
  "object": "batch",
  "endpoint": "/v1/chat/completions",
  "status": "completed",
  "input_file_id": "file-abc123",
  "output_file_id": "file-xyz789",
  "completion_window": "24h",
  "created_at": 1711471533,
  "completed_at": 1711493163,
  "request_counts": {
    "total": 100,
    "completed": 95,
    "failed": 5
  }
}
```

**error_response.json:**
```json
{
  "error": {
    "message": "Invalid API key provided",
    "type": "authentication_error",
    "code": "invalid_api_key"
  }
}
```

---

## Commit Strategy

Following CLAUDE.md guidelines for small, focused commits:

### Commit Sequence

1. **Add OpenAI message models**
   - `OpenAIMessage`, `OpenAIContentBlock`
   - 100-150 lines

2. **Add OpenAI request/response models**
   - `OpenAIRequest`, `OpenAIResponse`
   - 150-200 lines

3. **Add OpenAI tool calling models**
   - `OpenAIToolDefinition`, `OpenAIToolCall`, `OpenAIToolChoice`
   - 100-150 lines

4. **Add OpenAI streaming and batch models**
   - `OpenAIStreamChunk`, `OpenAIBatch`, `OpenAIBatchRequest`, `OpenAIBatchResult`
   - 200-250 lines

5. **Add OpenAI error models and helpers**
   - `OpenAIErrorResponse`, `AnyCodable`
   - 100-150 lines

6. **Implement OpenAIProvider structure**
   - Provider init, header building
   - 100-150 lines

7. **Implement sendMessage() and mapping**
   - Core message sending, request/response mapping
   - 150-200 lines

8. **Implement streaming support**
   - `streamMessage()`, SSE parsing
   - 100-150 lines

9. **Implement batch operations**
   - All batch methods, file upload/download
   - 200-250 lines

10. **Add error handling and retry logic**
    - Error mapping, rate limit handling
    - 50-100 lines

11. **Add OpenAI model definitions**
    - Update `ModelProvider.swift`
    - 50 lines

12. **Add test infrastructure**
    - `MockOpenAIAPI`, test data files
    - 100-150 lines

13. **Add request/response mapping tests**
    - Unit tests for mapping functions
    - 100-150 lines

14. **Add streaming tests**
    - SSE parsing, accumulation tests
    - 50-100 lines

15. **Add batch operation tests**
    - Batch creation, results parsing tests
    - 100-150 lines

16. **Add error handling tests**
    - Error mapping, retry logic tests
    - 50-100 lines

17. **Update README with OpenAI examples**
    - Usage examples, configuration
    - Documentation

18. **Update CHANGELOG.md**
    - Add OpenAI features to [Unreleased]
    - Documentation

19. **Fix integration issues**
    - Any fixes found during full test run
    - Variable

20. **Final polish**
    - Documentation cleanup, final review
    - Variable

### Example Commit Messages

```
Add OpenAI message models

- Add OpenAIMessage struct with role and content fields
- Add OpenAIContentBlock enum for text and image content
- Implement Codable conformance with snake_case mapping
- Add support for multi-part content (text + images)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

```
Implement OpenAIProvider streaming support

- Add streamMessage() method with SSE parsing
- Handle data: [DONE] termination signal
- Accumulate delta content across chunks
- Map streaming chunks to AIResponse objects
- Add comprehensive error handling for streaming

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## API References

### Official OpenAI Documentation

Research conducted on 2025-11-23. Sources used:

1. **Core API Documentation**
   - [OpenAI Platform - Chat Streaming](https://platform.openai.com/docs/api-reference/chat/streaming)
   - [Streaming API responses](https://platform.openai.com/docs/guides/streaming-responses)
   - [Complete Guide to the OpenAI API 2025 | Zuplo](https://zuplo.com/learning-center/openai-api)

2. **Embeddings**
   - [OpenAI Embedding Models](https://openai.com/index/new-embedding-models-and-api-updates/)
   - [OpenAI API Embeddings](https://platform.openai.com/docs/api-reference/embeddings)

3. **Rate Limiting**
   - [How to handle rate limits | OpenAI Cookbook](https://cookbook.openai.com/examples/how_to_handle_rate_limits)
   - [Rate limits - OpenAI API](https://platform.openai.com/docs/guides/rate-limits)
   - [Rate Limit Advice | OpenAI Help Center](https://help.openai.com/en/articles/6891753-rate-limit-advice)

4. **Function/Tool Calling**
   - [Using GPT4 Vision with Function Calling](https://cookbook.openai.com/examples/multimodal/using_gpt4_vision_with_function_calling)
   - [Function calling - OpenAI API](https://platform.openai.com/docs/guides/function-calling)
   - [Function calling updates | OpenAI](https://openai.com/index/function-calling-and-other-api-updates/)

5. **Models**
   - [Models - OpenAI API](https://platform.openai.com/docs/models)
   - [Best OpenAI Models 2025 | BrainChat](https://www.brainchat.ai/blog/openai-models-2025-guide)

6. **Batch API**
   - [Batch API Guide](https://platform.openai.com/docs/guides/batch)
   - [Batch API FAQ | OpenAI Help Center](https://help.openai.com/en/articles/9197833-batch-api-faq)
   - [Batch processing | OpenAI Cookbook](https://cookbook.openai.com/examples/batch_processing)

7. **Chat Completions**
   - [Work with chat completion - Azure OpenAI](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/chatgpt)
   - [Moving to Chat Completions | OpenAI Help Center](https://help.openai.com/en/articles/7042661-moving-from-completions-to-chat-completions)

8. **Authentication**
   - [OpenAI authentication 2025 | DataStudios](https://www.datastudios.org/post/openai-authentication-in-2025)
   - [API authentication | Milvus](https://milvus.io/ai-quick-reference/how-do-i-authenticate-api-requests-with-openai)

### Key API Endpoints

**Base URL:** `https://api.openai.com/v1`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/chat/completions` | POST | Create chat completion |
| `/models` | GET | List available models |
| `/models/{model}` | GET | Get model details |
| `/batches` | POST | Create batch job |
| `/batches/{batch_id}` | GET | Retrieve batch status |
| `/batches/{batch_id}/cancel` | POST | Cancel batch job |
| `/batches` | GET | List all batches |
| `/files` | POST | Upload file for batch |
| `/files/{file_id}/content` | GET | Download file content |

### Response Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Success | Process response |
| 400 | Bad request | Fix request format |
| 401 | Authentication failed | Check API key |
| 403 | Permission denied | Check account permissions |
| 404 | Not found | Verify endpoint/resource |
| 429 | Rate limit exceeded | Retry with backoff |
| 500 | Server error | Retry with backoff |
| 503 | Service unavailable | Retry with backoff |

---

## Summary

This implementation plan provides a comprehensive roadmap for adding full OpenAI API support to SwiftlyAIKit. The implementation follows established framework patterns from the Anthropic provider and includes:

- **~700 lines** of model definitions
- **~600 lines** of provider implementation
- **~400 lines** of tests
- **~50 lines** of model updates

Total: **~1,750 lines** across 20 focused commits

The plan covers all major OpenAI features including chat completions, streaming, batch processing, tool calling, and vision support, while maintaining consistency with the framework's design principles and development guidelines.
