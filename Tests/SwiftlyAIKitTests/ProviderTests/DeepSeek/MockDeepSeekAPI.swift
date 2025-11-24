import Foundation
@testable import SwiftlyAIKit

/// Mock DeepSeek API responses for testing
///
/// Provides pre-configured responses for DeepSeek API endpoints.
/// Includes SSE event sequences for streaming responses.
public enum MockDeepSeekAPI {
    // MARK: - Chat Completions API

    /// Sample successful chat completion response
    public static let chatCompletionResponse = """
    {
      "id": "chatcmpl-deepseek123",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "deepseek-chat",
      "system_fingerprint": "fp_deepseek_v32",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Hello! I'm DeepSeek AI. How can I assist you today?"
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

    /// Sample response with prompt caching
    public static let promptCachingResponse = """
    {
      "id": "chatcmpl-cache456",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "deepseek-chat",
      "system_fingerprint": "fp_deepseek_v32",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Using cached prompt tokens for faster response."
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 100,
        "completion_tokens": 12,
        "total_tokens": 112,
        "prompt_cache_hit_tokens": 80,
        "prompt_cache_miss_tokens": 20
      }
    }
    """

    /// Sample response from reasoning model with reasoning_content
    public static let reasoningResponse = """
    {
      "id": "chatcmpl-reasoning789",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "deepseek-reasoner",
      "system_fingerprint": "fp_deepseek_r1",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "The answer is 42.",
            "reasoning_content": "Let me think through this step by step:\\n1. First, I'll analyze the question\\n2. Consider various approaches\\n3. Calculate the result\\n4. Verify the answer"
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 25,
        "completion_tokens": 150,
        "total_tokens": 175
      }
    }
    """

    /// Sample response with max tokens reached
    public static let maxTokensResponse = """
    {
      "id": "chatcmpl-maxtokens",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "deepseek-chat",
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
        "completion_tokens": 8192,
        "total_tokens": 8202
      }
    }
    """

    /// Sample response with tool calls
    public static let toolCallResponse = """
    {
      "id": "chatcmpl-tools123",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "deepseek-chat",
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
                  "arguments": "{\\"location\\":\\"San Francisco\\",\\"unit\\":\\"celsius\\"}"
                }
              }
            ]
          },
          "finish_reason": "tool_calls"
        }
      ],
      "usage": {
        "prompt_tokens": 45,
        "completion_tokens": 20,
        "total_tokens": 65
      }
    }
    """

    /// Sample response with content filter
    public static let contentFilterResponse = """
    {
      "id": "chatcmpl-filter456",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "deepseek-chat",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "I cannot provide that information as it"
          },
          "finish_reason": "content_filter"
        }
      ],
      "usage": {
        "prompt_tokens": 15,
        "completion_tokens": 8,
        "total_tokens": 23
      }
    }
    """

    /// Sample empty response (error case)
    public static let emptyResponse = """
    {
      "id": "chatcmpl-empty",
      "object": "chat.completion",
      "created": 1677652288,
      "model": "deepseek-chat",
      "choices": [],
      "usage": {
        "prompt_tokens": 5,
        "completion_tokens": 0,
        "total_tokens": 5
      }
    }
    """

    // MARK: - Streaming Responses (SSE Events)

    /// Sample SSE streaming events for chat completion
    public static let streamingEvents = [
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"! I'm\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" DeepSeek\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" AI.\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":8,\"total_tokens\":20}}",
        "data: [DONE]"
    ]

    /// Sample SSE streaming events with reasoning content
    public static let reasoningStreamingEvents = [
        "data: {\"id\":\"chatcmpl-reasoning-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-reasoner\",\"system_fingerprint\":\"fp_deepseek_r1\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-reasoning-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-reasoner\",\"system_fingerprint\":\"fp_deepseek_r1\",\"choices\":[{\"index\":0,\"delta\":{\"reasoning_content\":\"Let me think:\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-reasoning-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-reasoner\",\"system_fingerprint\":\"fp_deepseek_r1\",\"choices\":[{\"index\":0,\"delta\":{\"reasoning_content\":\" Step 1...\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-reasoning-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-reasoner\",\"system_fingerprint\":\"fp_deepseek_r1\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"The answer\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-reasoning-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-reasoner\",\"system_fingerprint\":\"fp_deepseek_r1\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" is 42.\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-reasoning-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-reasoner\",\"system_fingerprint\":\"fp_deepseek_r1\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":25,\"completion_tokens\":120,\"total_tokens\":145}}",
        "data: [DONE]"
    ]

    /// Sample SSE streaming events with prompt caching
    public static let cachingStreamingEvents = [
        "data: {\"id\":\"chatcmpl-cache-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-cache-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Cached response\"},\"finish_reason\":null}]}",
        "data: {\"id\":\"chatcmpl-cache-stream\",\"object\":\"chat.completion.chunk\",\"created\":1677652288,\"model\":\"deepseek-chat\",\"system_fingerprint\":\"fp_deepseek_v32\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":100,\"completion_tokens\":10,\"total_tokens\":110,\"prompt_cache_hit_tokens\":80,\"prompt_cache_miss_tokens\":20}}",
        "data: [DONE]"
    ]

    // MARK: - Error Responses

    /// Sample authentication error (401)
    public static let authenticationError = """
    {
      "error": {
        "message": "Invalid API key provided",
        "type": "invalid_request_error",
        "code": "invalid_api_key"
      }
    }
    """

    /// Sample rate limit error (429)
    public static let rateLimitError = """
    {
      "error": {
        "message": "Rate limit exceeded. Please try again later.",
        "type": "rate_limit_error",
        "code": "rate_limit_exceeded"
      }
    }
    """

    /// Sample validation error (400)
    public static let validationError = """
    {
      "error": {
        "message": "Invalid parameter: temperature must be between 0 and 2",
        "type": "invalid_request_error",
        "param": "temperature",
        "code": "invalid_parameter"
      }
    }
    """

    /// Sample server error (500)
    public static let serverError = """
    {
      "error": {
        "message": "Internal server error",
        "type": "server_error",
        "code": "internal_error"
      }
    }
    """

    /// Sample context length error (400)
    public static let contextLengthError = """
    {
      "error": {
        "message": "Context length exceeded. Maximum context length is 128000 tokens.",
        "type": "invalid_request_error",
        "param": "messages",
        "code": "context_length_exceeded"
      }
    }
    """
}
