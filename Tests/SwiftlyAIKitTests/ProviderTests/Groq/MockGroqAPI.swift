// swiftlint:disable file_length
import Foundation
@testable import SwiftlyAIKit

/// Mock Groq API responses for testing
///
/// Provides pre-configured responses for Groq's OpenAI-compatible API endpoints.
/// Includes SSE event sequences for streaming responses.
// swiftlint:disable:next type_body_length
public enum MockGroqAPI {
    // MARK: - Chat Completions API

    /// Sample successful chat completion response
    public static let chatCompletionResponse = """
    {
      "id": "chatcmpl-abc123def456",
      "object": "chat.completion",
      "created": 1700000000,
      "model": "openai/gpt-oss-120b",
      "system_fingerprint": "fp_xyz123",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Hello! I'm running on Groq. How can I help you today?"
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

    /// Sample response with reasoning tokens
    public static let reasoningResponse = """
    {
      "id": "chatcmpl-reasoning123",
      "object": "chat.completion",
      "created": 1700000001,
      "model": "openai/gpt-oss-120b",
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
      "model": "qwen/qwen3-32b",
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
      "model": "gemma2-9b-it",
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
      "model": "openai/gpt-oss-120b",
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
      "model": "openai/gpt-oss-120b",
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

    /// Sample vision response (multimodal, OpenAI-compatible)
    public static let visionResponse = """
    {
      "id": "chatcmpl-vision123",
      "object": "chat.completion",
      "created": 1700000006,
      "model": "meta-llama/llama-4-scout-17b-16e-instruct",
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
      "model": "openai/gpt-oss-120b",
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
      "model": "openai/gpt-oss-120b",
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

    // MARK: - Streaming Responses

    /// Streaming response using **real Groq framing** (OpenAI-compatible `include_usage`).
    ///
    /// `finish_reason` and `usage` do NOT co-locate on a single `delta:{}` chunk. Instead:
    /// content-delta chunks, then a `finish_reason` chunk (empty delta, no usage), then a
    /// **separate trailing `{"choices":[],"usage":{…}}` chunk** carrying the terminal token
    /// usage, then `data: [DONE]`. This exercises the delta-less usage path.
    // swiftlint:disable line_length
    public static let streamingResponseRealFraming = [
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\", world\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"!\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}",
        "data: {\"id\":\"chatcmpl-real123\",\"object\":\"chat.completion.chunk\",\"created\":1700000030,\"model\":\"openai/gpt-oss-120b\",\"choices\":[],\"usage\":{\"prompt_tokens\":11,\"completion_tokens\":3,\"total_tokens\":14,\"completion_tokens_details\":{\"reasoning_tokens\":7,\"text_tokens\":3}}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    /// Streaming tool-call response using **real Groq framing**.
    ///
    /// Tool-call fragments stream in, then a `finish_reason:"tool_calls"` chunk (empty
    /// delta), then a **separate trailing `{"choices":[],"usage":{…}}` chunk**, then
    /// `data: [DONE]`.
    // swiftlint:disable line_length
    public static let streamingToolCallResponseRealFraming = [
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_real123\",\"type\":\"function\",\"function\":{\"name\":\"get_weather\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"{\\\"loc\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"ation\\\": \\\"NYC\\\"}\"}}]},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"openai/gpt-oss-120b\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"tool_calls\"}]}",
        "data: {\"id\":\"chatcmpl-real-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000031,\"model\":\"openai/gpt-oss-120b\",\"choices\":[],\"usage\":{\"prompt_tokens\":25,\"completion_tokens\":15,\"total_tokens\":40}}",
        "data: [DONE]"
    ]
    // swiftlint:enable line_length

    // MARK: - Models List

    /// Sample models list response
    ///
    /// Uses currently-valid Groq model ids (as of 2026-07-18).
    public static let modelsListResponse = """
    {
      "object": "list",
      "data": [
        {
          "id": "openai/gpt-oss-120b",
          "object": "model",
          "created": 1710000000,
          "owned_by": "OpenAI"
        },
        {
          "id": "openai/gpt-oss-20b",
          "object": "model",
          "created": 1710000000,
          "owned_by": "OpenAI"
        },
        {
          "id": "qwen/qwen3-32b",
          "object": "model",
          "created": 1710000000,
          "owned_by": "Alibaba Cloud"
        },
        {
          "id": "moonshotai/kimi-k2-instruct-0905",
          "object": "model",
          "created": 1710000000,
          "owned_by": "Moonshot AI"
        },
        {
          "id": "meta-llama/llama-4-scout-17b-16e-instruct",
          "object": "model",
          "created": 1710000000,
          "owned_by": "Meta"
        },
        {
          "id": "meta-llama/llama-4-maverick-17b-128e-instruct",
          "object": "model",
          "created": 1710000000,
          "owned_by": "Meta"
        },
        {
          "id": "deepseek-r1-distill-llama-70b",
          "object": "model",
          "created": 1710000000,
          "owned_by": "DeepSeek"
        },
        {
          "id": "gemma2-9b-it",
          "object": "model",
          "created": 1710000000,
          "owned_by": "Google"
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
        "message": "The model 'nonexistent-model' does not exist",
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
      "model": "openai/gpt-oss-120b",
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
      "model": "openai/gpt-oss-120b",
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
      "model": "openai/gpt-oss-120b",
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
