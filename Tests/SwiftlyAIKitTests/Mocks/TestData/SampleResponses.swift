import Foundation
@testable import SwiftlyAIKit

/// Sample AI responses for testing
public enum SampleResponses {
    // MARK: - Simple Responses

    /// Basic text response
    public static let simpleText = AIResponse(
        id: "msg_01XFDUDYJgAACzvnptvVoYEL",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("Hello! How can I help you today?")])
        ],
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 10, outputTokens: 15)
    )

    /// Multi-part response
    public static let multiPart = AIResponse(
        id: "msg_02MultiPartResponse",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [
                .text("Here's the information you requested:"),
                .text("1. First point"),
                .text("2. Second point")
            ])
        ],
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 20, outputTokens: 30)
    )

    // MARK: - Stop Reasons

    /// Response stopped by max tokens
    public static let stoppedMaxTokens = AIResponse(
        id: "msg_03MaxTokens",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("This is a very long response that was cut off...")])
        ],
        stopReason: .maxTokens,
        usage: AIUsage(inputTokens: 50, outputTokens: 1000)
    )

    /// Response stopped by stop sequence
    public static let stoppedStopSequence = AIResponse(
        id: "msg_04StopSeq",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("1, 2, 3, 4, 5")])
        ],
        stopReason: .stopSequence,
        stopSequence: "5",
        usage: AIUsage(inputTokens: 15, outputTokens: 10)
    )

    /// Response with tool use
    public static let stoppedToolUse = AIResponse(
        id: "msg_05ToolUse",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [
                .text("I'll check the weather for you."),
                .custom(data: [
                    "type": "tool_use",
                    "id": "toolu_01A09q90qw90lq917835lq9",
                    "name": "get_weather",
                    "input": [
                        "location": "San Francisco, CA",
                        "unit": "fahrenheit"
                    ]
                ])
            ])
        ],
        stopReason: .toolUse,
        usage: AIUsage(inputTokens: 20, outputTokens: 30)
    )

    // MARK: - Token Usage Scenarios

    /// Response with basic usage
    public static let basicUsage = AIResponse(
        id: "msg_06BasicUsage",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("Response text")])
        ],
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 100, outputTokens: 50)
    )

    /// Response with cached tokens (cache creation)
    public static let cacheCreation = AIResponse(
        id: "msg_07CacheCreate",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("Processing large document...")])
        ],
        stopReason: .endTurn,
        usage: AIUsage(
            inputTokens: 100,
            outputTokens: 20,
            cacheCreationInputTokens: 50000,
            cacheReadInputTokens: 0
        )
    )

    /// Response with cached tokens (cache read)
    public static let cacheRead = AIResponse(
        id: "msg_08CacheRead",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("Using cached document...")])
        ],
        stopReason: .endTurn,
        usage: AIUsage(
            inputTokens: 100,
            outputTokens: 20,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: 49900
        )
    )

    /// Response with mixed cache usage
    public static let mixedCache = AIResponse(
        id: "msg_09MixedCache",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("Updated cache...")])
        ],
        stopReason: .endTurn,
        usage: AIUsage(
            inputTokens: 200,
            outputTokens: 30,
            cacheCreationInputTokens: 1000,
            cacheReadInputTokens: 49000
        )
    )

    // MARK: - Streaming Responses

    /// First chunk in stream
    public static let streamStart = AIResponse(
        id: "msg_10Stream",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("Hello")])
        ],
        stopReason: nil,
        usage: AIUsage(inputTokens: 10, outputTokens: 1)
    )

    /// Middle chunk in stream
    public static let streamChunk = AIResponse(
        id: "msg_10Stream",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text(" world")])
        ],
        stopReason: nil,
        usage: AIUsage(inputTokens: 0, outputTokens: 1)
    )

    /// Final chunk in stream
    public static let streamEnd = AIResponse(
        id: "msg_10Stream",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("!")])
        ],
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 0, outputTokens: 1)
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
        content: [
            AIMessage(role: .assistant, content: [.text("Response")])
        ],
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 10, outputTokens: 5),
        providerData: [
            "request_id": "req-123",
            "model_version": "2025-05-14"
        ]
    )

    // MARK: - Edge Cases

    /// Empty response content
    public static let emptyContent = AIResponse(
        id: "msg_12Empty",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [])
        ],
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 10, outputTokens: 0)
    )

    /// Very large token count
    public static let largeTokens = AIResponse(
        id: "msg_13LargeTokens",
        model: "claude-opus-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text(String(repeating: "word ", count: 10000))])
        ],
        stopReason: .maxTokens,
        usage: AIUsage(inputTokens: 100000, outputTokens: 50000)
    )

    /// Unicode and emoji in response
    public static let unicodeEmoji = AIResponse(
        id: "msg_14Unicode",
        model: "claude-sonnet-4-20250514",
        content: [
            AIMessage(role: .assistant, content: [.text("Hello 👋 世界 🌍 مرحبا")])
        ],
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 15, outputTokens: 10)
    )

    // MARK: - Batch Results

    /// Successful batch result
    public static func batchSuccess(customId: String) -> BatchResult {
        BatchResult(
            customId: customId,
            result: .success(simpleText)
        )
    }

    /// Failed batch result
    public static func batchError(customId: String, error: AIError) -> BatchResult {
        BatchResult(
            customId: customId,
            result: .failure(error)
        )
    }

    /// Multiple batch results
    public static let batchResults: [BatchResult] = [
        batchSuccess(customId: "request-1"),
        batchSuccess(customId: "request-2"),
        batchError(customId: "request-3", error: .invalidRequest(message: "Invalid request")),
        batchSuccess(customId: "request-4")
    ]

    // MARK: - Batch Status

    /// In-progress batch
    public static let batchInProgress = BatchStatus(
        id: "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
        status: .inProgress,
        requestCounts: BatchStatus.RequestCounts(
            processing: 50,
            succeeded: 40,
            errored: 5,
            canceled: 0,
            expired: 0
        ),
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(86400)
    )

    /// Ended batch
    public static let batchEnded = BatchStatus(
        id: "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
        status: .ended,
        requestCounts: BatchStatus.RequestCounts(
            processing: 0,
            succeeded: 90,
            errored: 5,
            canceled: 0,
            expired: 5
        ),
        createdAt: Date().addingTimeInterval(-3600),
        endedAt: Date(),
        expiresAt: Date().addingTimeInterval(86400),
        resultsURL: "https://api.anthropic.com/v1/messages/batches/msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d/results"
    )

    /// Canceled batch
    public static let batchCanceled = BatchStatus(
        id: "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
        status: .canceling,
        requestCounts: BatchStatus.RequestCounts(
            processing: 30,
            succeeded: 40,
            errored: 5,
            canceled: 20,
            expired: 0
        ),
        createdAt: Date().addingTimeInterval(-1800),
        expiresAt: Date().addingTimeInterval(86400),
        cancelInitiatedAt: Date().addingTimeInterval(-900)
    )

    /// Expired batch
    public static let batchExpired = BatchStatus(
        id: "msgbatch_expired123",
        status: .expired,
        requestCounts: BatchStatus.RequestCounts(
            processing: 0,
            succeeded: 50,
            errored: 5,
            canceled: 0,
            expired: 45
        ),
        createdAt: Date().addingTimeInterval(-90000),
        endedAt: Date().addingTimeInterval(-3600),
        expiresAt: Date().addingTimeInterval(-1)
    )
}
