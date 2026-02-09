import Foundation
@testable import SwiftlyAIKit

/// Sample AI responses for testing
public enum SampleResponses {
    // MARK: - Simple Responses

    /// Basic text response
    public static let simpleText = AIResponse(
        id: "msg_01XFDUDYJgAACzvnptvVoYEL",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("Hello! How can I help you today?")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 10, outputTokens: 15),
        provider: .anthropic
    )

    /// Multi-part response
    public static let multiPart = AIResponse(
        id: "msg_02MultiPartResponse",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [
            .text("Here's the information you requested:"),
            .text("1. First point"),
            .text("2. Second point")
        ]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 20, outputTokens: 30),
        provider: .anthropic
    )

    // MARK: - Stop Reasons

    /// Response stopped by max tokens
    public static let stoppedMaxTokens = AIResponse(
        id: "msg_03MaxTokens",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("This is a very long response that was cut off...")]),
        stopReason: .maxTokens,
        usage: AIUsage(inputTokens: 50, outputTokens: 1000),
        provider: .anthropic
    )

    /// Response stopped by stop sequence
    public static let stoppedStopSequence = AIResponse(
        id: "msg_04StopSeq",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("1, 2, 3, 4, 5")]),
        stopReason: .stopSequence,
        usage: AIUsage(inputTokens: 15, outputTokens: 10),
        provider: .anthropic
    )

    /// Response with tool use
    public static let stoppedToolUse = AIResponse(
        id: "msg_05ToolUse",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [
            .text("I'll check the weather for you."),
            .custom(data: [
                "type": AnyCodable("tool_use"),
                "id": AnyCodable("toolu_01A09q90qw90lq917835lq9"),
                "name": AnyCodable("get_weather"),
                "input": AnyCodable([
                    "location": "San Francisco, CA",
                    "unit": "fahrenheit"
                ])
            ])
        ]),
        stopReason: .toolUse,
        usage: AIUsage(inputTokens: 20, outputTokens: 30),
        provider: .anthropic
    )

    // MARK: - Token Usage Scenarios

    /// Response with basic usage
    public static let basicUsage = AIResponse(
        id: "msg_06BasicUsage",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("Response text")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 100, outputTokens: 50),
        provider: .anthropic
    )

    /// Response with cached tokens (cache creation)
    public static let cacheCreation = AIResponse(
        id: "msg_07CacheCreate",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("Processing large document...")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 100, outputTokens: 20, cachedTokens: 50000),
        provider: .anthropic
    )

    /// Response with cached tokens (cache read)
    public static let cacheRead = AIResponse(
        id: "msg_08CacheRead",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("Using cached document...")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 100, outputTokens: 20, cachedTokens: 49900),
        provider: .anthropic
    )

    /// Response with mixed cache usage
    public static let mixedCache = AIResponse(
        id: "msg_09MixedCache",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("Updated cache...")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 200, outputTokens: 30, cachedTokens: 50000),
        provider: .anthropic
    )

    // MARK: - Streaming Responses

    /// First chunk in stream
    public static let streamStart = AIResponse(
        id: "msg_10Stream",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("Hello")]),
        stopReason: nil,
        usage: AIUsage(inputTokens: 10, outputTokens: 1),
        provider: .anthropic
    )

    /// Middle chunk in stream
    public static let streamChunk = AIResponse(
        id: "msg_10Stream",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text(" world")]),
        stopReason: nil,
        usage: AIUsage(inputTokens: 0, outputTokens: 1),
        provider: .anthropic
    )

    /// Final chunk in stream
    public static let streamEnd = AIResponse(
        id: "msg_10Stream",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("!")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 0, outputTokens: 1),
        provider: .anthropic
    )

    /// Complete stream sequence
    public static let streamSequence: [AIResponse] = [
        streamStart,
        streamChunk,
        streamEnd
    ]

    // MARK: - Provider Data

    /// Response with provider-specific data
    public static let withProviderData = AIResponse(
        id: "msg_11ProviderData",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("Response")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 10, outputTokens: 5),
        provider: .anthropic,
        providerData: [
            "request_id": AnyCodable("req-123"),
            "model_version": AnyCodable("2025-05-14")
        ]
    )

    // MARK: - Edge Cases

    /// Empty response content
    public static let emptyContent = AIResponse(
        id: "msg_12Empty",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: []),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 10, outputTokens: 0),
        provider: .anthropic
    )

    /// Very large token count
    public static let largeTokens = AIResponse(
        id: "msg_13LargeTokens",
        model: "claude-opus-4-20250514",
        message: AIMessage(role: .assistant, content: [.text(String(repeating: "word ", count: 10000))]),
        stopReason: .maxTokens,
        usage: AIUsage(inputTokens: 100000, outputTokens: 50000),
        provider: .anthropic
    )

    /// Unicode and emoji in response
    public static let unicodeEmoji = AIResponse(
        id: "msg_14Unicode",
        model: "claude-sonnet-4-20250514",
        message: AIMessage(role: .assistant, content: [.text("Hello 👋 世界 🌍 مرحبا")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 15, outputTokens: 10),
        provider: .anthropic
    )

    // MARK: - Batch Results

    /// Successful batch result
    public static func batchSuccess(requestId: String) -> BatchResult {
        BatchResult(
            requestId: requestId,
            response: simpleText,
            error: nil
        )
    }

    /// Failed batch result
    public static func batchError(requestId: String, errorMessage: String) -> BatchResult {
        BatchResult(
            requestId: requestId,
            response: nil,
            error: errorMessage
        )
    }

    /// Multiple batch results
    public static let batchResults: [BatchResult] = [
        batchSuccess(requestId: "request-1"),
        batchSuccess(requestId: "request-2"),
        batchError(requestId: "request-3", errorMessage: "Invalid request"),
        batchSuccess(requestId: "request-4")
    ]
}
