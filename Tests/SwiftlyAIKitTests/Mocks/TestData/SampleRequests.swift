import Foundation
@testable import SwiftlyAIKit

/// Sample AI requests for testing
public enum SampleRequests {
    // MARK: - Simple Requests

    /// Basic text request
    public static let simpleText = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [.text("Hello, Claude!")])
        ]
    )

    /// Request with system message
    public static let withSystemMessage = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .system, content: [.text("You are a helpful assistant.")]),
            AIMessage(role: .user, content: [.text("What is 2+2?")])
        ]
    )

    /// Multi-turn conversation
    public static let multiTurn = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [.text("What is the capital of France?")]),
            AIMessage(role: .assistant, content: [.text("The capital of France is Paris.")]),
            AIMessage(role: .user, content: [.text("What is its population?")])
        ]
    )

    // MARK: - Vision Requests

    /// Request with base64 image
    public static let withBase64Image = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [
                .text("What do you see in this image?"),
                .image(
                    source: .base64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="),
                    mediaType: "image/png"
                )
            ])
        ]
    )

    /// Request with image URL
    public static let withImageURL = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [
                .text("Describe this image"),
                .image(
                    source: .url("https://example.com/image.jpg"),
                    mediaType: "image/jpeg"
                )
            ])
        ]
    )

    // MARK: - Document Requests

    /// Request with PDF document
    public static let withPDFDocument = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [
                .text("Summarize this PDF"),
                .document(
                    data: Data("Mock PDF content".utf8),
                    mediaType: "application/pdf",
                    filename: "document.pdf"
                )
            ])
        ]
    )

    // MARK: - Complex Content

    /// Mixed content types in one message
    public static let mixedContent = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [
                .text("Analyze this:"),
                .image(
                    source: .url("https://example.com/chart.png"),
                    mediaType: "image/png"
                ),
                .text("What trends do you see?")
            ])
        ]
    )

    // MARK: - Configuration Options

    /// Request with temperature and tokens
    public static let withOptions = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [.text("Write a creative story")])
        ],
        maxTokens: 1000,
        temperature: 0.9,
        topP: 0.95,
        topK: 40
    )

    /// Request with streaming enabled
    public static let withStreaming = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [.text("Tell me a joke")])
        ],
        stream: true
    )

    /// Request with stop sequences
    public static let withStopSequences = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [.text("Count to 10")])
        ],
        stopSequences: ["5", "10"]
    )

    // MARK: - Edge Cases

    /// Empty user message (should fail validation)
    public static let emptyMessage = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [])
        ]
    )

    /// Very long text
    public static let longText = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [
                .text(String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000))
            ])
        ]
    )

    /// Unicode and emoji
    public static let unicodeEmoji = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [
                .text("Hello 👋 世界 🌍 مرحبا")
            ])
        ]
    )

    /// Multiple system messages
    public static let multipleSystem = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .system, content: [.text("You are helpful.")]),
            AIMessage(role: .system, content: [.text("You are concise.")]),
            AIMessage(role: .user, content: [.text("Hello")])
        ]
    )

    // MARK: - Provider-Specific Options

    /// Request with Anthropic-specific metadata
    public static let withMetadata = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [.text("Hello")])
        ],
        providerOptions: [
            "user_id": AnyCodable("user-123"),
            "request_id": AnyCodable("req-456")
        ]
    )

    // MARK: - Batch Requests

    /// Array of requests for batch processing
    public static let batchRequests: [AIRequest] = [
        AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [
                AIMessage(role: .user, content: [.text("What is 2+2?")])
            ]
        ),
        AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [
                AIMessage(role: .user, content: [.text("What is the capital of France?")])
            ]
        ),
        AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [
                AIMessage(role: .user, content: [.text("Name a color")])
            ]
        )
    ]

    // MARK: - Invalid Requests

    /// Invalid model name
    public static let invalidModel = AIRequest(
        model: "invalid-model-name",
        messages: [
            AIMessage(role: .user, content: [.text("Hello")])
        ]
    )

    /// Negative max tokens (should fail validation)
    public static let negativeMaxTokens = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [.text("Hello")])
        ],
        maxTokens: -100
    )

    /// Temperature out of range
    public static let invalidTemperature = AIRequest(
        model: "claude-sonnet-4-20250514",
        messages: [
            AIMessage(role: .user, content: [.text("Hello")])
        ],
        temperature: 2.5
    )
}
