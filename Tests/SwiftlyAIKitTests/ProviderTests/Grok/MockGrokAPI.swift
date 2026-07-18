// swiftlint:disable file_length
import Foundation
@testable import SwiftlyAIKit

/// Mock Grok API responses for testing
///
/// Provides pre-configured responses for xAI Grok API endpoints.
/// Includes SSE event sequences for streaming responses.
// swiftlint:disable:next type_body_length
public enum MockGrokAPI {
    // MARK: - Chat Completions API

    /// Sample successful chat completion response
    public static let chatCompletionResponse = """
    {
      "id": "chatcmpl-abc123def456",
      "object": "chat.completion",
      "created": 1700000000,
      "model": "grok-4-0709",
      "system_fingerprint": "fp_xyz123",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Hello! I'm Grok, made by xAI. How can I help you today?"
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

    /// Sample response with reasoning tokens (Grok 4)
    public static let reasoningResponse = """
    {
      "id": "chatcmpl-reasoning123",
      "object": "chat.completion",
      "created": 1700000001,
      "model": "grok-4-0709",
      "system_fingerprint": "fp_reasoning",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "After careful analysis, the answer is 42."
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 50,
        "completion_tokens": 100,
        "total_tokens": 150,
        "prompt_tokens_details": {
          "cached_tokens": 10,
          "text_tokens": 40
        },
        "completion_tokens_details": {
          "reasoning_tokens": 80,
          "text_tokens": 20
        }
      }
    }
    """

    /// Sample response with cached tokens
    public static let cachedTokensResponse = """
    {
      "id": "chatcmpl-cached123",
      "object": "chat.completion",
      "created": 1700000002,
      "model": "grok-3",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Response with cached tokens benefit."
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 100,
        "completion_tokens": 10,
        "total_tokens": 110,
        "prompt_tokens_details": {
          "cached_tokens": 75,
          "text_tokens": 25
        }
      }
    }
    """

    /// Sample response with max tokens reached
    public static let maxTokensResponse = """
    {
      "id": "chatcmpl-maxtokens",
      "object": "chat.completion",
      "created": 1700000003,
      "model": "grok-3-mini",
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
      "id": "chatcmpl-tools456",
      "object": "chat.completion",
      "created": 1700000004,
      "model": "grok-4",
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
                  "arguments": "{\\"location\\": \\"San Francisco, CA\\", \\"unit\\": \\"fahrenheit\\"}"
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

    /// Sample response with multiple tool calls
    public static let multipleToolCallsResponse = """
    {
      "id": "chatcmpl-multitools",
      "object": "chat.completion",
      "created": 1700000005,
      "model": "grok-4",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": null,
            "tool_calls": [
              {
                "id": "call_weather1",
                "type": "function",
                "function": {
                  "name": "get_weather",
                  "arguments": "{\\"location\\": \\"New York\\"}"
                }
              },
              {
                "id": "call_weather2",
                "type": "function",
                "function": {
                  "name": "get_weather",
                  "arguments": "{\\"location\\": \\"Los Angeles\\"}"
                }
              }
            ]
          },
          "finish_reason": "tool_calls"
        }
      ],
      "usage": {
        "prompt_tokens": 60,
        "completion_tokens": 40,
        "total_tokens": 100
      }
    }
    """

    /// Sample vision response (Grok 2 Vision)
    public static let visionResponse = """
    {
      "id": "chatcmpl-vision123",
      "object": "chat.completion",
      "created": 1700000006,
      "model": "grok-2-vision-1212",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "This image shows a beautiful sunset over the ocean with vibrant orange and purple colors reflecting on the water."
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 250,
        "completion_tokens": 30,
        "total_tokens": 280,
        "prompt_tokens_details": {
          "image_tokens": 200,
          "text_tokens": 50
        }
      }
    }
    """

    /// Sample response with content filter
    public static let contentFilterResponse = """
    {
      "id": "chatcmpl-filtered",
      "object": "chat.completion",
      "created": 1700000007,
      "model": "grok-4",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": null,
            "refusal": "I'm unable to assist with this request."
          },
          "finish_reason": "content_filter"
        }
      ],
      "usage": {
        "prompt_tokens": 20,
        "completion_tokens": 0,
        "total_tokens": 20
      }
    }
    """

    /// Sample JSON structured output response
    public static let jsonResponse = """
    {
      "id": "chatcmpl-json123",
      "object": "chat.completion",
      "created": 1700000008,
      "model": "grok-4",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "{\\"title\\": \\"The Great Gatsby\\", \\"author\\": \\"F. Scott Fitzgerald\\", \\"publication_year\\": 1925}"
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 30,
        "completion_tokens": 25,
        "total_tokens": 55
      }
    }
    """

    /// Sample code completion response (Grok Code Fast)
    public static let codeResponse = """
    {
      "id": "chatcmpl-code123",
      "object": "chat.completion",
      "created": 1700000009,
      "model": "grok-code-fast-1",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "```python\\ndef fibonacci(n):\\n    if n <= 1:\\n        return n\\n    return fibonacci(n-1) + fibonacci(n-2)\\n```"
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 15,
        "completion_tokens": 45,
        "total_tokens": 60
      }
    }
    """

    // MARK: - Streaming Responses

    /// Sample streaming response sequence (SSE format)
    // swiftlint:disable line_length
    public static let streamingResponse = [
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"!\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" How\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" can\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" I\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" help\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" you?\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":6,\"total_tokens\":14}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    /// Sample streaming response with tool calls
    // swiftlint:disable line_length
    public static let streamingToolCallResponse = [
        "data: {\"id\":\"chatcmpl-stream-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000011,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000011,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_stream123\",\"type\":\"function\",\"function\":{\"name\":\"get_weather\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000011,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"{\\\"loc\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000011,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"ation\\\"\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000011,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\": \\\"NYC\\\"}\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000011,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":25,\"completion_tokens\":15,\"total_tokens\":40}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    /// Sample streaming response with reasoning tokens
    // swiftlint:disable line_length
    public static let streamingReasoningResponse = [
        "data: {\"id\":\"chatcmpl-stream-reason\",\"object\":\"chat.completion.chunk\",\"created\":1700000012,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream-reason\",\"object\":\"chat.completion.chunk\",\"created\":1700000012,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"The answer is 42.\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream-reason\",\"object\":\"chat.completion.chunk\",\"created\":1700000012,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":30,\"completion_tokens\":50,\"total_tokens\":80,\"completion_tokens_details\":{\"reasoning_tokens\":40,\"text_tokens\":10}}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    /// Streaming response using **real xAI framing** (OpenAI-compatible `include_usage`).
    ///
    /// Unlike ``streamingResponse``, `finish_reason` and `usage` do NOT co-locate on a
    /// single `delta:{}` chunk. Instead: content-delta chunks, then a `finish_reason`
    /// chunk (empty delta, no usage), then a **separate trailing `{"choices":[],"usage":{…}}`
    /// chunk** carrying the terminal token usage, then `data: [DONE]`. This mirrors how
    /// xAI actually frames a streamed completion and exercises the delta-less usage path.
    // swiftlint:disable line_length
    public static let streamingResponseRealFraming = [
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\", world\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"!\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"grok-4\",\"choices\":[],\"usage\":{\"prompt_tokens\":11,\"completion_tokens\":3,\"total_tokens\":14,\"completion_tokens_details\":{\"reasoning_tokens\":7,\"text_tokens\":3}}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    /// Streaming tool-call response using **real xAI framing**.
    ///
    /// Tool-call fragments stream in, then a `finish_reason:"tool_calls"` chunk (empty
    /// delta), then a **separate trailing `{"choices":[],"usage":{…}}` chunk**, then
    /// `data: [DONE]`.
    // swiftlint:disable line_length
    public static let streamingToolCallResponseRealFraming = [
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_real123\",\"type\":\"function\",\"function\":{\"name\":\"get_weather\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"{\\\"loc\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"ation\\\": \\\"NYC\\\"}\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"tool_calls\"}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"grok-4\",\"choices\":[],\"usage\":{\"prompt_tokens\":25,\"completion_tokens\":15,\"total_tokens\":40}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    // MARK: - Tokenization API

    /// Sample tokenize response
    public static let tokenizeResponse = """
    {
      "tokens": [
        {"token_id": 31587, "string_token": "Hello"},
        {"token_id": 11, "string_token": ","},
        {"token_id": 1577, "string_token": " how"},
        {"token_id": 525, "string_token": " are"},
        {"token_id": 564, "string_token": " you"},
        {"token_id": 30, "string_token": "?"}
      ]
    }
    """

    /// Sample tokenize response for longer text
    public static let tokenizeLongResponse = """
    {
      "tokens": [
        {"token_id": 1, "string_token": "The"},
        {"token_id": 2, "string_token": " quick"},
        {"token_id": 3, "string_token": " brown"},
        {"token_id": 4, "string_token": " fox"},
        {"token_id": 5, "string_token": " jumps"},
        {"token_id": 6, "string_token": " over"},
        {"token_id": 7, "string_token": " the"},
        {"token_id": 8, "string_token": " lazy"},
        {"token_id": 9, "string_token": " dog"},
        {"token_id": 10, "string_token": "."}
      ]
    }
    """

    // MARK: - Deferred Completions

    /// Sample deferred completion initial response
    public static let deferredInitialResponse = """
    {
      "request_id": "req_deferred123"
    }
    """

    /// Sample deferred completion pending status
    public static let deferredPendingResponse = """
    {
      "status": "pending",
      "result": null,
      "error": null
    }
    """

    /// Sample deferred completion success status
    public static let deferredSuccessResponse = """
    {
      "status": "complete",
      "result": {
        "id": "chatcmpl-deferred123",
        "object": "chat.completion",
        "created": 1700000013,
        "model": "grok-4",
        "choices": [
          {
            "index": 0,
            "message": {
              "role": "assistant",
              "content": "This is the result of a deferred completion."
            },
            "finish_reason": "stop"
          }
        ],
        "usage": {
          "prompt_tokens": 100,
          "completion_tokens": 50,
          "total_tokens": 150
        }
      },
      "error": null
    }
    """

    /// Sample deferred completion failed status
    public static let deferredFailedResponse = """
    {
      "status": "failed",
      "result": null,
      "error": {
        "message": "Request timed out",
        "type": "timeout_error",
        "code": "timeout"
      }
    }
    """

    // MARK: - Image Generation

    /// Sample image generation response
    public static let imageGenerationResponse = """
    {
      "created": 1700000014,
      "data": [
        {
          "url": "https://example.com/generated-image-1.png",
          "revised_prompt": "A cat sitting in a tree, digital art style"
        }
      ]
    }
    """

    /// Sample image generation response with multiple images
    public static let multipleImagesResponse = """
    {
      "created": 1700000015,
      "data": [
        {
          "url": "https://example.com/image-1.png",
          "revised_prompt": "A serene mountain landscape at sunset, vibrant colors"
        },
        {
          "url": "https://example.com/image-2.png",
          "revised_prompt": "A serene mountain landscape at sunset, vibrant colors"
        }
      ]
    }
    """

    /// Sample image generation response with base64
    public static let imageBase64Response = """
    {
      "created": 1700000016,
      "data": [
        {
          "b64_json": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
          "revised_prompt": "A minimalist red square"
        }
      ]
    }
    """

    // MARK: - Models List

    /// Sample models list response
    public static let modelsListResponse = """
    {
      "object": "list",
      "data": [
        {
          "id": "grok-4-0709",
          "object": "model",
          "created": 1699900000,
          "owned_by": "xai"
        },
        {
          "id": "grok-4",
          "object": "model",
          "created": 1699900000,
          "owned_by": "xai"
        },
        {
          "id": "grok-3",
          "object": "model",
          "created": 1699800000,
          "owned_by": "xai"
        },
        {
          "id": "grok-3-mini",
          "object": "model",
          "created": 1699800000,
          "owned_by": "xai"
        },
        {
          "id": "grok-2-vision-1212",
          "object": "model",
          "created": 1699700000,
          "owned_by": "xai"
        },
        {
          "id": "grok-code-fast-1",
          "object": "model",
          "created": 1699600000,
          "owned_by": "xai"
        },
        {
          "id": "grok-2-image",
          "object": "model",
          "created": 1699500000,
          "owned_by": "xai"
        }
      ]
    }
    """

    // MARK: - Error Responses

    /// Authentication error (401)
    public static let authenticationError = """
    {
      "error": {
        "message": "Invalid API key provided",
        "type": "invalid_api_key",
        "code": "invalid_api_key"
      }
    }
    """

    /// Rate limit error (429)
    public static let rateLimitError = """
    {
      "error": {
        "message": "Rate limit exceeded. Please slow down your requests.",
        "type": "rate_limit_error",
        "code": "rate_limit_exceeded"
      }
    }
    """

    /// Invalid request error (400)
    public static let invalidRequestError = """
    {
      "error": {
        "message": "Invalid request: model parameter is required",
        "type": "invalid_request_error",
        "code": "invalid_request",
        "param": "model"
      }
    }
    """

    /// Model not found error (404)
    public static let modelNotFoundError = """
    {
      "error": {
        "message": "The model 'grok-99' does not exist",
        "type": "invalid_request_error",
        "code": "model_not_found",
        "param": "model"
      }
    }
    """

    /// Context length exceeded error (400)
    public static let contextLengthError = """
    {
      "error": {
        "message": "This model's maximum context length is 128000 tokens. However, your messages resulted in 150000 tokens.",
        "type": "invalid_request_error",
        "code": "context_length_exceeded"
      }
    }
    """

    /// Server error (500)
    public static let serverError = """
    {
      "error": {
        "message": "Internal server error",
        "type": "server_error",
        "code": "internal_error"
      }
    }
    """

    /// Service unavailable error (503)
    public static let serviceUnavailableError = """
    {
      "error": {
        "message": "The server is currently overloaded. Please try again later.",
        "type": "server_error",
        "code": "service_unavailable"
      }
    }
    """

    // MARK: - Edge Cases

    /// Response with empty content
    public static let emptyContentResponse = """
    {
      "id": "chatcmpl-empty",
      "object": "chat.completion",
      "created": 1700000020,
      "model": "grok-4",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": ""
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 5,
        "completion_tokens": 0,
        "total_tokens": 5
      }
    }
    """

    /// Response with null content
    public static let nullContentResponse = """
    {
      "id": "chatcmpl-null",
      "object": "chat.completion",
      "created": 1700000021,
      "model": "grok-4",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": null
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 5,
        "completion_tokens": 0,
        "total_tokens": 5
      }
    }
    """

    /// Response with logprobs
    public static let logprobsResponse = """
    {
      "id": "chatcmpl-logprobs",
      "object": "chat.completion",
      "created": 1700000022,
      "model": "grok-4",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Hello"
          },
          "logprobs": {
            "content": [
              {
                "token": "Hello",
                "logprob": -0.5,
                "bytes": [72, 101, 108, 108, 111],
                "top_logprobs": [
                  {"token": "Hello", "logprob": -0.5, "bytes": [72, 101, 108, 108, 111]},
                  {"token": "Hi", "logprob": -1.2, "bytes": [72, 105]}
                ]
              }
            ]
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 5,
        "completion_tokens": 1,
        "total_tokens": 6
      }
    }
    """

    // MARK: - Helper Methods

    /// Convert streaming response array to Data
    public static func streamingResponseAsData(_ events: [String]) -> Data {
        let combined = events.joined(separator: "\n") + "\n"
        return combined.data(using: .utf8) ?? Data()
    }

    /// Get chat completion response as Data
    public static func responseAsData(_ response: String) -> Data {
        response.data(using: .utf8) ?? Data()
    }
}
