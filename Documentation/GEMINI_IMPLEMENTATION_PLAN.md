# Google Gemini Provider Implementation Plan for SwiftlyAIKit

**Research Date:** 2025-11-23
**Target Framework:** SwiftlyAIKit v0.4.0
**Pattern Reference:** AnthropicProvider.swift (~620 lines), OpenAIProvider.swift (~324 lines)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Gemini API Endpoints](#gemini-api-endpoints)
3. [Required Model Structures](#required-model-structures)
4. [Provider Implementation](#provider-implementation)
5. [Feature Comparison: Gemini vs OpenAI vs Anthropic](#feature-comparison)
6. [Special Considerations](#special-considerations)
7. [Implementation Phases](#implementation-phases)
8. [Testing Strategy](#testing-strategy)
9. [Commit Strategy](#commit-strategy)
10. [API References](#api-references)

---

## Executive Summary

This plan details the complete implementation of Google Gemini API support in SwiftlyAIKit, following the established framework patterns. The implementation will add approximately 1,600 lines of code across model definitions, provider implementation, and comprehensive tests.

**Key Deliverables:**
- Full Generate Content API support (standard + streaming)
- Native multimodal support (text, images, video, audio, PDFs)
- Function calling with JSON Schema support
- Advanced structured output with response schemas
- Vision capabilities for all Gemini 2.x models
- Comprehensive error handling and rate limiting
- Support for Gemini 2.5 Pro/Flash and 2.0 Flash models

**Unique Gemini Features:**
- Native multimodal processing (images, video up to 90 minutes, audio, PDFs)
- Structured outputs with JSON Schema validation
- Enhanced object detection and segmentation (2.5 models)
- Implicit property ordering in JSON responses
- Up to 1M token context window (2.0 Flash)
- Multiple safety settings categories

---

## Gemini API Endpoints

### Priority 1: Core Endpoints

#### 1.1 Generate Content API
**Endpoint:** `POST /v1beta/models/{model}:generateContent`
**Base URL:** `https://generativelanguage.googleapis.com`

**Features:**
- Standard content generation
- Multimodal inputs (text, images, video, audio, PDFs)
- Function calling with JSON Schema
- Structured output with response schemas
- Safety settings control
- System instructions support

**Authentication:**
```
x-goog-api-key: API_KEY
```

**Request Format:**
```json
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "Explain how AI works"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7,
    "topK": 40,
    "topP": 0.95,
    "maxOutputTokens": 8192,
    "responseMimeType": "text/plain"
  },
  "safetySettings": [
    {
      "category": "HARM_CATEGORY_HARASSMENT",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    }
  ]
}
```

**Response Format:**
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "AI works by..."
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP",
      "index": 0,
      "safetyRatings": [
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "probability": "NEGLIGIBLE"
        }
      ]
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 9,
    "candidatesTokenCount": 12,
    "totalTokenCount": 21
  }
}
```

#### 1.2 Stream Generate Content API
**Endpoint:** `POST /v1beta/models/{model}:streamGenerateContent?alt=sse`

**Features:**
- Server-Sent Events (SSE) streaming
- Real-time content generation
- Delta chunks as content is generated
- Same request format as generateContent
- Streaming function calls (Gemini 3 Pro+)

**SSE Format:**
```
data: {"candidates": [{"content": {"parts": [{"text": "AI "}]}}]}

data: {"candidates": [{"content": {"parts": [{"text": "works "}]}}]}

data: {"candidates": [{"content": {"parts": [{"text": "by..."}], "role": "model"}, "finishReason": "STOP"}]}
```

#### 1.3 Count Tokens API
**Endpoint:** `POST /v1beta/models/{model}:countTokens`

**Purpose:**
- Count tokens before sending request
- Avoid hitting context limits
- Estimate costs

**Request:**
```json
{
  "contents": [
    {
      "parts": [
        {
          "text": "How many tokens is this?"
        }
      ]
    }
  ]
}
```

**Response:**
```json
{
  "totalTokens": 7
}
```

#### 1.4 Models API
**Endpoint:** `GET /v1beta/models`

**Purpose:**
- List available models
- Get model capabilities and limits
- Check supported generation methods

**Response:**
```json
{
  "models": [
    {
      "name": "models/gemini-2.5-flash",
      "displayName": "Gemini 2.5 Flash",
      "description": "Fast and versatile performance across tasks",
      "inputTokenLimit": 1048576,
      "outputTokenLimit": 8192,
      "supportedGenerationMethods": [
        "generateContent",
        "streamGenerateContent"
      ]
    }
  ]
}
```

### Priority 2: Advanced Features

#### 2.1 File API (for large multimodal inputs)
**Endpoints:**
- `POST /upload/v1beta/files` - Upload files
- `GET /v1beta/files/{name}` - Get file metadata
- `DELETE /v1beta/files/{name}` - Delete file

**Use Cases:**
- Upload images/videos/audio for reuse
- Handle large files (up to 2GB)
- Process long videos (up to 90 minutes)
- Batch process multiple files

#### 2.2 Cached Content API (for prompt caching)
**Endpoints:**
- `POST /v1beta/cachedContents` - Create cached content
- `GET /v1beta/cachedContents/{name}` - Retrieve cached content
- `PATCH /v1beta/cachedContents/{name}` - Update TTL
- `DELETE /v1beta/cachedContents/{name}` - Delete cached content

**Benefits:**
- Reduce costs for repeated context
- Faster response times
- Support for large contexts (up to 1M tokens)

---

## Required Model Structures

### File: `Sources/SwiftlyAIKit/Models/Gemini/GeminiModels.swift`

**Estimated Size:** ~750 lines (similar to Anthropic/OpenAI)

#### 3.1 Content Parts

```swift
/// Represents different types of content parts in Gemini messages
public enum GeminiPart: Codable, Sendable, Equatable {
    case text(String)
    case inlineData(mimeType: String, data: String) // base64
    case fileData(mimeType: String, fileUri: String)
    case functionCall(FunctionCall)
    case functionResponse(FunctionResponse)

    public struct FunctionCall: Codable, Sendable, Equatable {
        public let name: String
        public let args: [String: AnyCodable]

        public init(name: String, args: [String: AnyCodable]) {
            self.name = name
            self.args = args
        }
    }

    public struct FunctionResponse: Codable, Sendable, Equatable {
        public let name: String
        public let response: [String: AnyCodable]

        public init(name: String, response: [String: AnyCodable]) {
            self.name = name
            self.response = response
        }
    }

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData
        case fileData
        case functionCall
        case functionResponse
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let content):
            try container.encode(content, forKey: .text)

        case .inlineData(let mimeType, let data):
            var inlineContainer = container.nestedContainer(keyedBy: InlineDataKeys.self, forKey: .inlineData)
            try inlineContainer.encode(mimeType, forKey: .mimeType)
            try inlineContainer.encode(data, forKey: .data)

        case .fileData(let mimeType, let fileUri):
            var fileContainer = container.nestedContainer(keyedBy: FileDataKeys.self, forKey: .fileData)
            try fileContainer.encode(mimeType, forKey: .mimeType)
            try fileContainer.encode(fileUri, forKey: .fileUri)

        case .functionCall(let call):
            try container.encode(call, forKey: .functionCall)

        case .functionResponse(let response):
            try container.encode(response, forKey: .functionResponse)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let text = try? container.decode(String.self, forKey: .text) {
            self = .text(text)
        } else if let inlineContainer = try? container.nestedContainer(keyedBy: InlineDataKeys.self, forKey: .inlineData) {
            let mimeType = try inlineContainer.decode(String.self, forKey: .mimeType)
            let data = try inlineContainer.decode(String.self, forKey: .data)
            self = .inlineData(mimeType: mimeType, data: data)
        } else if let fileContainer = try? container.nestedContainer(keyedBy: FileDataKeys.self, forKey: .fileData) {
            let mimeType = try fileContainer.decode(String.self, forKey: .mimeType)
            let fileUri = try fileContainer.decode(String.self, forKey: .fileUri)
            self = .fileData(mimeType: mimeType, fileUri: fileUri)
        } else if let call = try? container.decode(FunctionCall.self, forKey: .functionCall) {
            self = .functionCall(call)
        } else if let response = try? container.decode(FunctionResponse.self, forKey: .functionResponse) {
            self = .functionResponse(response)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .text,
                in: container,
                debugDescription: "Cannot decode GeminiPart"
            )
        }
    }

    private enum InlineDataKeys: String, CodingKey {
        case mimeType
        case data
    }

    private enum FileDataKeys: String, CodingKey {
        case mimeType
        case fileUri
    }
}
```

#### 3.2 Content Structure

```swift
/// Gemini content structure (message equivalent)
public struct GeminiContent: Codable, Sendable, Equatable {
    public let role: Role?
    public let parts: [GeminiPart]

    public enum Role: String, Codable, Sendable {
        case user
        case model
        case function
    }

    public init(role: Role? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}
```

#### 3.3 Generation Config

```swift
/// Generation configuration for Gemini models
public struct GeminiGenerationConfig: Codable, Sendable {
    public let stopSequences: [String]?
    public let responseMimeType: String?
    public let responseSchema: [String: AnyCodable]?
    public let candidateCount: Int?
    public let maxOutputTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?

    public init(
        stopSequences: [String]? = nil,
        responseMimeType: String? = nil,
        responseSchema: [String: AnyCodable]? = nil,
        candidateCount: Int? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil
    ) {
        self.stopSequences = stopSequences
        self.responseMimeType = responseMimeType
        self.responseSchema = responseSchema
        self.candidateCount = candidateCount
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
    }

    enum CodingKeys: String, CodingKey {
        case stopSequences
        case responseMimeType
        case responseSchema
        case candidateCount
        case maxOutputTokens
        case temperature
        case topP
        case topK
    }
}
```

#### 3.4 Safety Settings

```swift
/// Safety settings for Gemini content generation
public struct GeminiSafetySetting: Codable, Sendable, Equatable {
    public let category: HarmCategory
    public let threshold: HarmBlockThreshold

    public enum HarmCategory: String, Codable, Sendable {
        case harmCategoryUnspecified = "HARM_CATEGORY_UNSPECIFIED"
        case harmCategoryDerogatory = "HARM_CATEGORY_DEROGATORY"
        case harmCategoryToxicity = "HARM_CATEGORY_TOXICITY"
        case harmCategoryViolence = "HARM_CATEGORY_VIOLENCE"
        case harmCategorySexual = "HARM_CATEGORY_SEXUAL"
        case harmCategoryMedical = "HARM_CATEGORY_MEDICAL"
        case harmCategoryDangerous = "HARM_CATEGORY_DANGEROUS"
        case harmCategoryHarassment = "HARM_CATEGORY_HARASSMENT"
        case harmCategoryHateSpeech = "HARM_CATEGORY_HATE_SPEECH"
        case harmCategorySexuallyExplicit = "HARM_CATEGORY_SEXUALLY_EXPLICIT"
        case harmCategoryDangerousContent = "HARM_CATEGORY_DANGEROUS_CONTENT"
    }

    public enum HarmBlockThreshold: String, Codable, Sendable {
        case harmBlockThresholdUnspecified = "HARM_BLOCK_THRESHOLD_UNSPECIFIED"
        case blockLowAndAbove = "BLOCK_LOW_AND_ABOVE"
        case blockMediumAndAbove = "BLOCK_MEDIUM_AND_ABOVE"
        case blockOnlyHigh = "BLOCK_ONLY_HIGH"
        case blockNone = "BLOCK_NONE"
    }

    public init(category: HarmCategory, threshold: HarmBlockThreshold) {
        self.category = category
        self.threshold = threshold
    }
}

/// Safety rating in response
public struct GeminiSafetyRating: Codable, Sendable {
    public let category: GeminiSafetySetting.HarmCategory
    public let probability: HarmProbability
    public let blocked: Bool?

    public enum HarmProbability: String, Codable, Sendable {
        case harmProbabilityUnspecified = "HARM_PROBABILITY_UNSPECIFIED"
        case negligible = "NEGLIGIBLE"
        case low = "LOW"
        case medium = "MEDIUM"
        case high = "HIGH"
    }
}
```

#### 3.5 Tool/Function Calling

```swift
/// Tool definition for function calling
public struct GeminiTool: Codable, Sendable, Equatable {
    public let functionDeclarations: [FunctionDeclaration]

    public struct FunctionDeclaration: Codable, Sendable, Equatable {
        public let name: String
        public let description: String
        public let parameters: Schema?

        public struct Schema: Codable, Sendable, Equatable {
            public let type: String
            public let properties: [String: Property]
            public let required: [String]?

            public struct Property: Codable, Sendable, Equatable {
                public let type: String
                public let description: String?
                public let format: String?
                public let nullable: Bool?
                public let enumValues: [String]?

                enum CodingKeys: String, CodingKey {
                    case type
                    case description
                    case format
                    case nullable
                    case enumValues = "enum"
                }
            }
        }

        public init(name: String, description: String, parameters: Schema? = nil) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }

    public init(functionDeclarations: [FunctionDeclaration]) {
        self.functionDeclarations = functionDeclarations
    }
}

/// Tool configuration
public struct GeminiToolConfig: Codable, Sendable {
    public let functionCallingConfig: FunctionCallingConfig

    public struct FunctionCallingConfig: Codable, Sendable {
        public let mode: Mode
        public let allowedFunctionNames: [String]?

        public enum Mode: String, Codable, Sendable {
            case modeUnspecified = "MODE_UNSPECIFIED"
            case auto = "AUTO"
            case any = "ANY"
            case none = "NONE"
        }

        public init(mode: Mode, allowedFunctionNames: [String]? = nil) {
            self.mode = mode
            self.allowedFunctionNames = allowedFunctionNames
        }
    }

    public init(functionCallingConfig: FunctionCallingConfig) {
        self.functionCallingConfig = functionCallingConfig
    }
}
```

#### 3.6 Request Structure

```swift
/// Gemini generate content request
public struct GeminiRequest: Codable, Sendable {
    public let contents: [GeminiContent]
    public let systemInstruction: GeminiContent?
    public let tools: [GeminiTool]?
    public let toolConfig: GeminiToolConfig?
    public let safetySettings: [GeminiSafetySetting]?
    public let generationConfig: GeminiGenerationConfig?

    public init(
        contents: [GeminiContent],
        systemInstruction: GeminiContent? = nil,
        tools: [GeminiTool]? = nil,
        toolConfig: GeminiToolConfig? = nil,
        safetySettings: [GeminiSafetySetting]? = nil,
        generationConfig: GeminiGenerationConfig? = nil
    ) {
        self.contents = contents
        self.systemInstruction = systemInstruction
        self.tools = tools
        self.toolConfig = toolConfig
        self.safetySettings = safetySettings
        self.generationConfig = generationConfig
    }
}
```

#### 3.7 Response Structure

```swift
/// Gemini generate content response
public struct GeminiResponse: Codable, Sendable {
    public let candidates: [Candidate]
    public let promptFeedback: PromptFeedback?
    public let usageMetadata: UsageMetadata?

    public struct Candidate: Codable, Sendable {
        public let content: GeminiContent
        public let finishReason: FinishReason?
        public let safetyRatings: [GeminiSafetyRating]?
        public let citationMetadata: CitationMetadata?
        public let tokenCount: Int?
        public let avgLogprobs: Double?
        public let index: Int

        public enum FinishReason: String, Codable, Sendable {
            case finishReasonUnspecified = "FINISH_REASON_UNSPECIFIED"
            case stop = "STOP"
            case maxTokens = "MAX_TOKENS"
            case safety = "SAFETY"
            case recitation = "RECITATION"
            case other = "OTHER"
        }

        public struct CitationMetadata: Codable, Sendable {
            public let citationSources: [CitationSource]

            public struct CitationSource: Codable, Sendable {
                public let startIndex: Int?
                public let endIndex: Int?
                public let uri: String?
                public let license: String?
            }
        }
    }

    public struct PromptFeedback: Codable, Sendable {
        public let blockReason: BlockReason?
        public let safetyRatings: [GeminiSafetyRating]?

        public enum BlockReason: String, Codable, Sendable {
            case blockReasonUnspecified = "BLOCK_REASON_UNSPECIFIED"
            case safety = "SAFETY"
            case other = "OTHER"
        }
    }

    public struct UsageMetadata: Codable, Sendable {
        public let promptTokenCount: Int
        public let candidatesTokenCount: Int?
        public let totalTokenCount: Int

        enum CodingKeys: String, CodingKey {
            case promptTokenCount
            case candidatesTokenCount
            case totalTokenCount
        }
    }
}
```

#### 3.8 Count Tokens Request/Response

```swift
/// Count tokens request
public struct GeminiCountTokensRequest: Codable, Sendable {
    public let contents: [GeminiContent]

    public init(contents: [GeminiContent]) {
        self.contents = contents
    }
}

/// Count tokens response
public struct GeminiCountTokensResponse: Codable, Sendable {
    public let totalTokens: Int
}
```

#### 3.9 Error Response

```swift
/// Gemini error response
public struct GeminiErrorResponse: Codable, Sendable {
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let code: Int
        public let message: String
        public let status: String
        public let details: [ErrorDetailsItem]?

        public struct ErrorDetailsItem: Codable, Sendable {
            public let type: String?
            public let reason: String?
            public let domain: String?
            public let metadata: [String: String]?

            enum CodingKeys: String, CodingKey {
                case type = "@type"
                case reason
                case domain
                case metadata
            }
        }
    }
}
```

---

## Provider Implementation

### File: `Sources/SwiftlyAIKit/Providers/GeminiProvider.swift`

**Estimated Size:** ~400 lines

#### 4.1 Provider Structure

```swift
import Foundation
import Vapor

/// Google Gemini provider implementation
public struct GeminiProvider: ProviderProtocol {
    public let providerType: ProviderType = .google

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let apiVersion: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize Gemini provider
    /// - Parameters:
    ///   - baseURL: Base URL for Gemini API (default: https://generativelanguage.googleapis.com)
    ///   - apiVersion: API version (default: v1beta)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://generativelanguage.googleapis.com",
        apiVersion: String = "v1beta",
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = HTTPClientManager()
        self.baseURL = baseURL
        self.apiVersion = apiVersion
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        let geminiRequest = try mapToGeminiRequest(request)
        let modelName = request.model
        let headers = buildHeaders(apiKey: apiKey)

        let jsonData = try JSONEncoder().encode(geminiRequest)

        let responseData = try await httpClient.post(
            url: "\(baseURL)/\(apiVersion)/models/\(modelName):generateContent",
            headers: headers,
            body: jsonData
        )

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        return try mapToAIResponse(geminiResponse, model: modelName)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let geminiRequest = try mapToGeminiRequest(request)
                    let modelName = request.model
                    let headers = buildHeaders(apiKey: apiKey)
                    let jsonData = try JSONEncoder().encode(geminiRequest)

                    let stream = try await httpClient.streamPost(
                        url: "\(baseURL)/\(apiVersion)/models/\(modelName):streamGenerateContent?alt=sse",
                        headers: headers,
                        body: jsonData
                    )

                    var accumulatedText = ""

                    for try await chunk in stream {
                        let chunkString = String(data: chunk, encoding: .utf8) ?? ""
                        let lines = chunkString.split(separator: "\n")

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)

                            // Parse SSE format: "data: {...}"
                            guard trimmed.hasPrefix("data: ") else { continue }

                            let jsonString = String(trimmed.dropFirst(6))
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            let streamChunk = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)

                            guard let candidate = streamChunk.candidates.first else { continue }

                            // Extract text from parts
                            for part in candidate.content.parts {
                                if case .text(let text) = part {
                                    accumulatedText += text
                                }
                            }

                            // Create AIResponse for this chunk
                            let message = AIMessage(
                                role: .assistant,
                                content: [.text(accumulatedText)]
                            )

                            let usage: AIUsage?
                            if let metadata = streamChunk.usageMetadata {
                                usage = AIUsage(
                                    inputTokens: metadata.promptTokenCount,
                                    outputTokens: metadata.candidatesTokenCount ?? 0
                                )
                            } else {
                                usage = nil
                            }

                            let response = AIResponse(
                                id: "gemini-\(UUID().uuidString)",
                                model: modelName,
                                message: message,
                                stopReason: candidate.finishReason.map { mapFinishReason($0) },
                                usage: usage,
                                provider: .google
                            )

                            continuation.yield(response)

                            // Check for finish
                            if candidate.finishReason != nil {
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
        let contents = try mapToGeminiContents(request)
        let countRequest = GeminiCountTokensRequest(contents: contents)
        let modelName = request.model
        let headers = buildHeaders(apiKey: apiKey)

        let jsonData = try JSONEncoder().encode(countRequest)

        let responseData = try await httpClient.post(
            url: "\(baseURL)/\(apiVersion)/models/\(modelName):countTokens",
            headers: headers,
            body: jsonData
        )

        let countResponse = try JSONDecoder().decode(GeminiCountTokensResponse.self, from: responseData)
        return countResponse.totalTokens
    }

    // MARK: - Private Helper Methods

    private func buildHeaders(apiKey: String) -> [(String, String)] {
        return [
            ("x-goog-api-key", apiKey),
            ("Content-Type", "application/json")
        ]
    }

    private func mapToGeminiRequest(_ request: AIRequest) throws -> GeminiRequest {
        let contents = try mapToGeminiContents(request)

        // System instruction (Gemini 1.5+)
        let systemInstruction: GeminiContent?
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            systemInstruction = GeminiContent(
                role: nil, // system instruction has no role
                parts: [.text(systemPrompt)]
            )
        } else {
            systemInstruction = nil
        }

        // Generation config
        let generationConfig = GeminiGenerationConfig(
            stopSequences: request.stopSequences,
            responseMimeType: nil,
            responseSchema: nil,
            candidateCount: nil,
            maxOutputTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            topK: nil
        )

        // Default safety settings (permissive)
        let safetySettings: [GeminiSafetySetting] = [
            .init(category: .harmCategoryHarassment, threshold: .blockOnlyHigh),
            .init(category: .harmCategoryHateSpeech, threshold: .blockOnlyHigh),
            .init(category: .harmCategorySexuallyExplicit, threshold: .blockOnlyHigh),
            .init(category: .harmCategoryDangerousContent, threshold: .blockOnlyHigh)
        ]

        return GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            tools: nil, // TODO: Implement tool mapping
            toolConfig: nil,
            safetySettings: safetySettings,
            generationConfig: generationConfig
        )
    }

    private func mapToGeminiContents(_ request: AIRequest) throws -> [GeminiContent] {
        var contents: [GeminiContent] = []

        for message in request.messages {
            let role: GeminiContent.Role = message.role == .user ? .user : .model

            var parts: [GeminiPart] = []

            for content in message.content {
                switch content {
                case .text(let text):
                    parts.append(.text(text))

                case .image(let source, let mediaType):
                    let mimeType = mediaType ?? "image/jpeg"

                    switch source {
                    case .url(let urlString):
                        // For URLs, need to download and convert to inline data
                        // Or use File API if large
                        throw AIError.unsupportedFeature(
                            feature: "Image URL (use base64 or File API)",
                            provider: .google
                        )

                    case .base64(let data):
                        parts.append(.inlineData(mimeType: mimeType, data: data))
                    }

                case .document(let source, let mediaType):
                    // Gemini supports PDFs via inlineData or fileData
                    let mimeType = mediaType ?? "application/pdf"

                    switch source {
                    case .url:
                        throw AIError.unsupportedFeature(
                            feature: "Document URL (use base64 or File API)",
                            provider: .google
                        )

                    case .base64(let data):
                        parts.append(.inlineData(mimeType: mimeType, data: data))
                    }

                case .custom:
                    throw AIError.unsupportedFeature(feature: "Custom content", provider: .google)
                }
            }

            contents.append(GeminiContent(role: role, parts: parts))
        }

        return contents
    }

    private func mapToAIResponse(_ response: GeminiResponse, model: String) throws -> AIResponse {
        // Check for prompt feedback blocking
        if let feedback = response.promptFeedback, feedback.blockReason != nil {
            throw AIError.contentBlocked(
                provider: .google,
                reason: "Content blocked by safety filters"
            )
        }

        guard let candidate = response.candidates.first else {
            throw AIError.invalidResponse(message: "No candidates in response")
        }

        // Extract text content
        var textContent: [AIMessageContent] = []
        for part in candidate.content.parts {
            switch part {
            case .text(let text):
                textContent.append(.text(text))
            case .functionCall:
                // TODO: Handle function calls
                break
            default:
                break
            }
        }

        let message = AIMessage(role: .assistant, content: textContent)

        let usage: AIUsage?
        if let metadata = response.usageMetadata {
            usage = AIUsage(
                inputTokens: metadata.promptTokenCount,
                outputTokens: metadata.candidatesTokenCount ?? 0
            )
        } else {
            usage = nil
        }

        return AIResponse(
            id: "gemini-\(UUID().uuidString)",
            model: model,
            message: message,
            stopReason: candidate.finishReason.map { mapFinishReason($0) },
            usage: usage,
            provider: .google
        )
    }

    private func mapFinishReason(_ reason: GeminiResponse.Candidate.FinishReason) -> AIStopReason {
        switch reason {
        case .stop:
            return .endTurn
        case .maxTokens:
            return .maxTokens
        case .safety, .recitation:
            return .stopSequence
        case .other, .finishReasonUnspecified:
            return .endTurn
        }
    }
}
```

---

## Feature Comparison

### 5.1 Similar Features

| Feature | Gemini | OpenAI | Anthropic | Implementation Notes |
|---------|--------|--------|-----------|---------------------|
| Chat Completions | ✅ | ✅ | ✅ | All use message/content format |
| Streaming | ✅ SSE | ✅ SSE | ✅ SSE | Different end signals |
| Vision (Images) | ✅ | ✅ | ✅ | Gemini: inline/file, others: URL/base64 |
| Function Calling | ✅ | ✅ | ✅ | Gemini uses JSON Schema format |
| Token Counting | ✅ Endpoint | ⚠️ In response | ✅ Endpoint | Gemini has dedicated endpoint |
| Stop Sequences | ✅ | ✅ | ✅ | Custom stop strings |
| Temperature Control | ✅ | ✅ | ✅ | 0.0 - 2.0 range |
| Top-P Sampling | ✅ | ✅ | ✅ | Nucleus sampling |

### 5.2 Gemini-Specific Features

**Present in Gemini, Not in Others:**

| Feature | Description | Parameter |
|---------|-------------|-----------|
| Top-K Sampling | Limit to top K tokens | `topK: Int` |
| Native Video Support | Up to 90 minutes | `parts: [.fileData(...)]` |
| Native Audio Support | Audio file processing | `parts: [.inlineData(audio)]` |
| Native PDF Support | Built-in PDF parsing | `parts: [.inlineData(pdf)]` |
| File API | Reusable file uploads | Separate endpoint |
| Safety Settings | Multi-category control | `safetySettings: [...]` |
| Response Schema | Structured JSON output | `responseSchema: {...}` |
| System Instruction | Separate from messages | `systemInstruction: {...}` |
| Candidate Count | Multiple response options | `candidateCount: Int` |
| Citation Metadata | Source attribution | In response |
| Safety Ratings | Per-category ratings | In response |

### 5.3 Key Implementation Differences

| Aspect | Gemini | OpenAI | Anthropic | Impact |
|--------|--------|--------|-----------|--------|
| **Auth Header** | `x-goog-api-key: <key>` | `Authorization: Bearer <key>` | `x-api-key: <key>` | Different header name |
| **API Version** | In URL path (`/v1beta/`) | In URL path (`/v1/`) | Header (`anthropic-version`) | URL structure |
| **Model in URL** | Yes (`/models/{model}:action`) | No | No | URL template |
| **System Message** | `systemInstruction` field | Part of messages | Separate parameter | Different structure |
| **Content Structure** | `parts` array in `contents` | `content` in messages | `content` array | Nested differently |
| **Roles** | `user`, `model`, `function` | `user`, `assistant`, `system`, `tool` | `user`, `assistant` | Different naming |
| **Stop Reason** | `finishReason` (STOP, MAX_TOKENS) | `finish_reason` (stop, length) | `stop_reason` | Different values |
| **Streaming End** | `finishReason` presence | `data: [DONE]` | `message_stop` event | Different signals |
| **Error Format** | Nested `error.error` | `error.type` | HTTP status | Structure differs |

---

## Special Considerations

### 6.1 Rate Limiting & Error Handling

#### Rate Limit Strategy

**Free Tier:**
- 5 requests per minute (RPM)
- 25 requests per day (RPD)
- Rate limits per project, not per API key

**Paid Tier 1:**
- 2,000 RPM
- 10,000 requests per day

**Retry Logic:**
```swift
private func handleRateLimitError(_ error: GeminiErrorResponse) -> AIError {
    // 429 RESOURCE_EXHAUSTED
    return .rateLimitExceeded(
        provider: .google,
        retryAfter: nil // Gemini doesn't provide Retry-After header
    )
}
```

**Exponential Backoff:**
- Initial delay: 1 second
- Max delay: 60 seconds
- Jitter: ±25% randomization

#### Error Code Mapping

```swift
private func mapGeminiError(_ error: GeminiErrorResponse) -> AIError {
    switch error.error.code {
    case 400:
        return .invalidRequest(message: error.error.message)
    case 401, 403:
        return .invalidAPIKey(provider: .google, message: error.error.message)
    case 404:
        return .notFound(resource: "model or endpoint", provider: .google)
    case 429:
        return .rateLimitExceeded(provider: .google, retryAfter: nil)
    case 500, 503:
        return .internalError(provider: .google, message: error.error.message)
    default:
        return .providerError(
            provider: .google,
            statusCode: error.error.code,
            message: error.error.message
        )
    }
}
```

### 6.2 Multimodal Input Handling

#### Image Processing Strategy

**Option 1: Inline Data (< 20MB)**
```swift
case .image(let source, let mediaType):
    switch source {
    case .base64(let data):
        parts.append(.inlineData(
            mimeType: mediaType ?? "image/jpeg",
            data: data
        ))
    }
```

**Option 2: File API (> 20MB or reusable)**
```swift
// Upload file first
let fileId = try await uploadFile(imageData, mimeType: "image/jpeg")

// Use in request
parts.append(.fileData(
    mimeType: "image/jpeg",
    fileUri: "https://generativelanguage.googleapis.com/v1beta/files/\(fileId)"
))
```

#### Video Processing

```swift
// Upload video via File API
let videoFileId = try await uploadFile(videoData, mimeType: "video/mp4")

parts.append(.fileData(
    mimeType: "video/mp4",
    fileUri: "https://generativelanguage.googleapis.com/v1beta/files/\(videoFileId)"
))
```

### 6.3 Safety Settings Configuration

#### Default Safe Settings

```swift
let defaultSafetySettings: [GeminiSafetySetting] = [
    .init(category: .harmCategoryHarassment, threshold: .blockOnlyHigh),
    .init(category: .harmCategoryHateSpeech, threshold: .blockOnlyHigh),
    .init(category: .harmCategorySexuallyExplicit, threshold: .blockOnlyHigh),
    .init(category: .harmCategoryDangerousContent, threshold: .blockOnlyHigh)
]
```

#### Handling Safety Blocks

```swift
// Check prompt feedback
if let feedback = response.promptFeedback {
    if let blockReason = feedback.blockReason {
        throw AIError.contentBlocked(
            provider: .google,
            reason: "Prompt blocked: \(blockReason.rawValue)"
        )
    }
}

// Check candidate safety
if let candidate = response.candidates.first {
    if candidate.finishReason == .safety {
        throw AIError.contentBlocked(
            provider: .google,
            reason: "Response blocked by safety filters"
        )
    }
}
```

### 6.4 Context Window Management

**Model Limits (2025):**
- Gemini 2.5 Pro: 2M tokens input, 8K output
- Gemini 2.5 Flash: 1M tokens input, 8K output
- Gemini 2.0 Flash: 1M tokens input, 8K output

**Strategy:**
```swift
// Use countTokens before sending
let tokenCount = try await countTokens(request, apiKey: apiKey)

if tokenCount > modelContextLimit {
    throw AIError.invalidRequest(
        message: "Request exceeds model context limit (\(tokenCount) > \(modelContextLimit))"
    )
}
```

---

## Implementation Phases

### Phase 1: Core Models (~750 lines)

**File:** `Sources/SwiftlyAIKit/Models/Gemini/GeminiModels.swift`

**Tasks:**
1. Define `GeminiPart` enum with all content types
2. Define `GeminiContent` struct with roles
3. Define `GeminiGenerationConfig` with all parameters
4. Define `GeminiSafetySetting` and `GeminiSafetyRating`
5. Define tool types: `GeminiTool`, `GeminiToolConfig`
6. Define `GeminiRequest` struct
7. Define `GeminiResponse` with candidates and metadata
8. Define `GeminiCountTokensRequest/Response`
9. Define `GeminiErrorResponse` struct
10. Implement comprehensive `Codable` conformance

**Commit Strategy:**
- Commit 1: Add content and part models
- Commit 2: Add generation config and safety settings
- Commit 3: Add tool/function calling models
- Commit 4: Add request and response models
- Commit 5: Add error and utility models

### Phase 2: Provider Implementation (~400 lines)

**File:** `Sources/SwiftlyAIKit/Providers/GeminiProvider.swift`

**Tasks:**
1. Implement provider struct with initialization
2. Implement `sendMessage()` method
3. Implement `streamMessage()` method with SSE parsing
4. Implement `countTokens()` method
5. Implement mapping functions:
   - `mapToGeminiRequest()` - handle system instruction
   - `mapToGeminiContents()` - map messages to contents
   - `mapToAIResponse()` - map Gemini response
   - `mapFinishReason()`
6. Implement `buildHeaders()` helper
7. Add error handling for safety blocks
8. Add comprehensive logging

**Commit Strategy:**
- Commit 6: Implement provider structure and initialization
- Commit 7: Implement sendMessage() and core mapping
- Commit 8: Implement streaming support
- Commit 9: Implement countTokens() method
- Commit 10: Add error handling and safety filters

### Phase 3: Model Definitions (~50 lines)

**File:** `Sources/SwiftlyAIKit/Models/ModelProvider.swift`

**Tasks:**
1. Add Gemini 2.5 Pro model case
2. Add Gemini 2.5 Flash model case
3. Add Gemini 2.0 Flash model case
4. Add Gemini 1.5 Pro/Flash (legacy, if needed)
5. Update model capabilities:
   - Vision support flags (all Gemini 2.x)
   - Function calling support
   - Context window sizes (up to 2M tokens)
   - Max output token limits (8K-32K)
6. Update provider type mapping

**Commit Strategy:**
- Commit 11: Add Gemini model definitions and capabilities

### Phase 4: Testing (~400 lines)

**Files:**
- `Tests/SwiftlyAIKitTests/ProviderTests/GeminiProviderTests.swift`
- `Tests/SwiftlyAIKitTests/Mocks/MockGeminiAPI.swift`
- `Tests/SwiftlyAIKitTests/Mocks/TestData/Gemini/` (JSON files)

**Tasks:**
1. Create `MockGeminiAPI` with sample responses
2. Create test data JSON files:
   - `generate_content_response.json`
   - `stream_chunk.json`
   - `count_tokens_response.json`
   - `error_response.json`
   - `safety_blocked_response.json`
3. Test request mapping:
   - System instruction handling
   - Multimodal content mapping
   - Safety settings configuration
4. Test response mapping:
   - Standard response parsing
   - Usage extraction
   - Safety ratings handling
5. Test streaming:
   - SSE chunk parsing
   - Text accumulation
   - Finish reason detection
6. Test error scenarios:
   - Rate limiting (429)
   - Safety blocks
   - Invalid API key
   - Model not found
7. Test token counting

**Commit Strategy:**
- Commit 12: Create MockGeminiAPI and test data
- Commit 13: Add request mapping tests (20 tests)
- Commit 14: Add response mapping tests (20 tests)
- Commit 15: Add streaming tests (15 tests)
- Commit 16: Add error handling tests (15 tests)
- Commit 17: Add integration tests (10 tests)

---

## Testing Strategy

### 7.1 Unit Tests Structure

**GeminiProviderTests (80 tests total)**

```swift
import Testing
@testable import SwiftlyAIKit

@Suite("Gemini Provider Tests")
struct GeminiProviderTests {
    @Test("sendMessage returns valid response")
    func testSendMessage() async throws {
        // Test standard generate content
    }

    @Test("streamMessage yields chunks")
    func testStreamMessage() async throws {
        // Test SSE streaming
    }

    @Test("countTokens returns token count")
    func testCountTokens() async throws {
        // Test token counting endpoint
    }

    @Test("handles safety blocked response")
    func testSafetyBlock() async throws {
        // Test safety filter blocking
    }

    @Test("maps multimodal content correctly")
    func testMultimodalMapping() async throws {
        // Test image/video/audio content
    }

    @Test("handles rate limit error")
    func testRateLimiting() async throws {
        // Test 429 error handling
    }
}
```

### 7.2 Integration Tests

```swift
@Suite("Gemini Integration Tests")
struct GeminiIntegrationTests {
    @Test("end-to-end text generation")
    func testEndToEndGeneration() async throws {
        let gateway = AIGateway(/* ... */)
        let request = AIRequest(model: "gemini-2.5-flash", ...)
        let response = try await gateway.sendMessage(request)
        #expect(response.message.content.count > 0)
    }

    @Test("end-to-end streaming")
    func testEndToEndStreaming() async throws {
        // Test real streaming with gateway
    }

    @Test("vision capabilities")
    func testVisionGeneration() async throws {
        // Test image understanding
    }
}
```

### 7.3 Mock Data Examples

**generate_content_response.json:**
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "AI works by processing data through neural networks..."
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP",
      "index": 0,
      "safetyRatings": [
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "probability": "NEGLIGIBLE"
        }
      ]
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 9,
    "candidatesTokenCount": 12,
    "totalTokenCount": 21
  }
}
```

---

## Commit Strategy

### Small, Focused Commits (Following SwiftlyAIKit Best Practices)

**Phase 1 Commits (Models):**
1. "Add Gemini content and part models"
2. "Add Gemini generation config and safety settings"
3. "Add Gemini tool/function calling models"
4. "Add Gemini request and response models"
5. "Add Gemini error and utility models"

**Phase 2 Commits (Provider):**
6. "Implement GeminiProvider structure and initialization"
7. "Implement sendMessage() and core mapping"
8. "Implement streaming support with SSE"
9. "Implement countTokens() method"
10. "Add error handling and safety filters"

**Phase 3 Commits (Models):**
11. "Add Gemini models to ModelProvider enum"

**Phase 4 Commits (Testing):**
12. "Create MockGeminiAPI with sample responses"
13. "Add GeminiProvider request mapping tests"
14. "Add GeminiProvider response mapping tests"
15. "Add GeminiProvider streaming tests"
16. "Add GeminiProvider error handling tests"
17. "Add GeminiProvider integration tests"

**Phase 5 Commits (Documentation):**
18. "Update CHANGELOG.md with Gemini implementation"
19. "Update CLAUDE.md with Gemini provider status"

**Git Best Practices:**
- Each commit builds successfully
- Each commit is atomic and focused
- Clear commit messages explaining what and why
- No large commits (keep under 300 lines per commit)
- Test after each commit

---

## API References

### Official Documentation

- [Gemini API Reference](https://ai.google.dev/api)
- [Gemini API Documentation](https://ai.google.dev/gemini-api/docs)
- [Generate Content Guide](https://ai.google.dev/api/generate-content)
- [Gemini Models](https://ai.google.dev/gemini-api/docs/models)
- [Function Calling](https://ai.google.dev/gemini-api/docs/function-calling)
- [Vision Capabilities](https://ai.google.dev/gemini-api/docs/vision)
- [Structured Output](https://ai.google.dev/gemini-api/docs/structured-output)
- [Rate Limits](https://ai.google.dev/gemini-api/docs/rate-limits)
- [Using API Keys](https://ai.google.dev/gemini-api/docs/api-key)

### Additional Resources

- [Gemini API Quickstart](https://ai.google.dev/gemini-api/docs/quickstart)
- [Gemini Cookbook (GitHub)](https://github.com/google-gemini/cookbook)
- [Release Notes](https://ai.google.dev/gemini-api/docs/changelog)
- [Vertex AI Gemini Docs](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference)

---

## Estimated Implementation Time

**Total Estimated Lines:** ~1,600 lines

- **Models:** ~750 lines (5 commits, 3-4 hours)
- **Provider:** ~400 lines (5 commits, 3-4 hours)
- **Model Enum:** ~50 lines (1 commit, 30 minutes)
- **Tests:** ~400 lines (6 commits, 4-5 hours)
- **Documentation:** (2 commits, 1 hour)

**Total Time:** ~12-15 hours of development

**Dependencies:**
- Existing HTTPClientManager (reuse)
- Existing AnyCodable helper (reuse)
- Existing test infrastructure (reuse)

---

## Next Steps After Implementation

1. **Advanced Features (Future):**
   - File API integration for large multimodal files
   - Cached Content API for prompt caching
   - Embeddings API (text-embedding-004)
   - Batch processing (if Gemini adds support)
   - Live API for real-time bidirectional streaming

2. **Optimizations:**
   - Implement automatic File API usage for large images
   - Add response caching for repeated prompts
   - Implement retry strategies for specific error codes
   - Add custom safety setting configurations per request

3. **Testing Enhancements:**
   - Add performance benchmarks
   - Test edge cases with 1M+ token contexts
   - Test multimodal combinations (text+image+video)
   - Test safety filter edge cases

---

**End of Gemini Implementation Plan**

This plan provides a complete roadmap for implementing Google Gemini API support in SwiftlyAIKit, following established patterns and best practices from the Anthropic and OpenAI implementations.
