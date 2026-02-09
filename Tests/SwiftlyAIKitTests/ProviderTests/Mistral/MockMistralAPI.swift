import Foundation
@testable import SwiftlyAIKit

/// Mock Mistral AI API responses for testing
///
/// Provides pre-configured responses for Mistral API endpoints.
/// Includes SSE event sequences for streaming responses.
public enum MockMistralAPI {
    // MARK: - Chat Completions API

    /// Sample successful chat completion response
    public static let chatCompletionResponse = """
    {
      "id": "cmpl-abc123def456",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "mistral-large-latest",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Hello! I'm Mistral AI. How can I help you today?"
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 12,
        "completion_tokens": 15,
        "total_tokens": 27
      }
    }
    """

    /// Sample response with vision (image analysis)
    public static let visionResponse = """
    {
      "id": "cmpl-vision123",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "mistral-large-latest",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "This image shows a beautiful sunset over the ocean with vibrant orange and purple colors."
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 150,
        "completion_tokens": 20,
        "total_tokens": 170
      }
    }
    """

    /// Sample response with max tokens reached
    public static let maxTokensResponse = """
    {
      "id": "cmpl-maxtokens",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "mistral-small-latest",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "This is a partial response that was cut off due to"
          },
          "finish_reason": "length"
        }
      ],
      "usage": {
        "prompt_tokens": 10,
        "completion_tokens": 100,
        "total_tokens": 110
      }
    }
    """

    /// Sample response with tool calls
    public static let toolCallResponse = """
    {
      "id": "cmpl-tools456",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "mistral-large-latest",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": null,
            "tool_calls": [
              {
                "id": "call_abc123",
                "type": "function",
                "function": {
                  "name": "get_weather",
                  "arguments": "{\\"location\\": \\"San Francisco, CA\\"}"
                }
              }
            ]
          },
          "finish_reason": "tool_calls"
        }
      ],
      "usage": {
        "prompt_tokens": 50,
        "completion_tokens": 20,
        "total_tokens": 70
      }
    }
    """

    /// Sample response filtered by safety system
    public static let contentFilterResponse = """
    {
      "id": "cmpl-filtered",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "mistral-large-latest",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "I cannot provide information on that topic."
          },
          "finish_reason": "content_filter"
        }
      ],
      "usage": {
        "prompt_tokens": 25,
        "completion_tokens": 10,
        "total_tokens": 35
      }
    }
    """

    // MARK: - Streaming Responses

    /// Sample streaming response sequence (SSE format)
    // swiftlint:disable line_length
    public static let streamingResponse = [
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"!\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" How\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" can\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" I\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" help\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"?\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-large-latest\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":8,\"total_tokens\":18}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    /// Sample streaming response with usage at the end
    // swiftlint:disable line_length
    public static let streamingResponseWithUsage = [
        "data: {\"id\":\"cmpl-stream456\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-small-latest\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream456\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-small-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Response\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream456\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-small-latest\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" text\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"cmpl-stream456\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"mistral-small-latest\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":5,\"completion_tokens\":2,\"total_tokens\":7}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    // MARK: - Error Responses

    /// Sample authentication error
    public static let authenticationError = """
    {
      "error": {
        "message": "Invalid API key provided",
        "type": "invalid_request_error",
        "code": "invalid_api_key"
      }
    }
    """

    /// Sample rate limit error
    public static let rateLimitError = """
    {
      "error": {
        "message": "Rate limit exceeded. Please try again later.",
        "type": "rate_limit_error",
        "code": "rate_limit_exceeded"
      }
    }
    """

    /// Sample validation error
    public static let validationError = """
    {
      "error": {
        "message": "Invalid request: temperature must be between 0 and 2",
        "type": "invalid_request_error",
        "code": "invalid_parameter"
      }
    }
    """

    /// Sample model not found error
    public static let modelNotFoundError = """
    {
      "error": {
        "message": "Model 'invalid-model' not found",
        "type": "invalid_request_error",
        "code": "model_not_found"
      }
    }
    """

    /// Sample server error
    public static let serverError = """
    {
      "error": {
        "message": "Internal server error. Please try again.",
        "type": "server_error",
        "code": "internal_error"
      }
    }
    """

    /// Sample context length exceeded error
    public static let contextLengthError = """
    {
      "error": {
        "message": "Maximum context length exceeded. Please reduce input length.",
        "type": "invalid_request_error",
        "code": "context_length_exceeded"
      }
    }
    """

    // MARK: - Sample Requests

    /// Sample chat request with system prompt
    public static let sampleRequest = MistralRequest(
        model: "mistral-large-latest",
        messages: [
            MistralMessage(
                role: .system,
                content: .text("You are a helpful AI assistant.")
            ),
            MistralMessage(
                role: .user,
                content: .text("Hello, how are you?")
            )
        ],
        maxTokens: 100,
        temperature: 0.7,
        topP: nil,
        stream: false
    )

    /// Sample streaming request
    public static let streamRequest = MistralRequest(
        model: "mistral-large-latest",
        messages: [
            MistralMessage(
                role: .user,
                content: .text("Tell me a short story.")
            )
        ],
        maxTokens: 500,
        temperature: 0.9,
        stream: true
    )

    /// Sample vision request with image
    public static let visionRequest = MistralRequest(
        model: "mistral-large-latest",
        messages: [
            MistralMessage(
                role: .user,
                content: .contentArray([
                    .text("What's in this image?"),
                    .imageUrl(url: "https://example.com/image.jpg", detail: "high")
                ])
            )
        ],
        maxTokens: 200
    )

    /// Sample request with tools
    public static let toolRequest = MistralRequest(
        model: "mistral-large-latest",
        messages: [
            MistralMessage(
                role: .user,
                content: .text("What's the weather in Paris?")
            )
        ],
        tools: [
            MistralToolDefinition(
                type: "function",
                function: .init(
                    name: "get_weather",
                    description: "Get the current weather",
                    parameters: [
                        "type": AnyCodable("object"),
                        "properties": AnyCodable([
                            "location": [
                                "type": "string",
                                "description": "City name"
                            ]
                        ]),
                        "required": AnyCodable(["location"])
                    ]
                )
            )
        ],
        toolChoice: .auto
    )

    /// Sample request with safe prompt enabled
    public static let safePromptRequest = MistralRequest(
        model: "mistral-large-latest",
        messages: [
            MistralMessage(
                role: .user,
                content: .text("Help me with this task.")
            )
        ],
        maxTokens: 150,
        safePrompt: true
    )

    /// Sample request with deterministic sampling
    public static let deterministicRequest = MistralRequest(
        model: "mistral-small-latest",
        messages: [
            MistralMessage(
                role: .user,
                content: .text("Generate a random number.")
            )
        ],
        temperature: 1.0,
        randomSeed: 42
    )
}
