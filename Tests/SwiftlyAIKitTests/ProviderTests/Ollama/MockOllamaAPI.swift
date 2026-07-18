import Foundation
@testable import SwiftlyAIKit

/// Mock Ollama API responses for testing
///
/// Provides pre-configured responses for Ollama's native `/api/chat` and `/api/tags` endpoints.
/// Ollama streaming is **newline-delimited JSON** (each line a full `OllamaChatResponse`), not SSE —
/// there is no `data:` prefix and no `[DONE]` sentinel.
public enum MockOllamaAPI {
    // MARK: - Chat API (non-streaming)

    /// Sample successful chat response with token usage.
    public static let chatResponse = """
    {
      "model": "llama3.2:latest",
      "created_at": "2026-07-18T12:00:00.000000Z",
      "message": {
        "role": "assistant",
        "content": "Hello! I'm running locally via Ollama."
      },
      "done": true,
      "done_reason": "stop",
      "prompt_eval_count": 26,
      "eval_count": 12
    }
    """

    /// Sample response cut off at the token limit (`done_reason == "length"`).
    public static let maxTokensResponse = """
    {
      "model": "llama3.2:latest",
      "created_at": "2026-07-18T12:00:01.000000Z",
      "message": {
        "role": "assistant",
        "content": "This is a partial response that was cut off due to"
      },
      "done": true,
      "done_reason": "length",
      "prompt_eval_count": 10,
      "eval_count": 100
    }
    """

    /// Sample response carrying a tool call.
    ///
    /// Ollama's `tool_calls[].function.arguments` is a JSON **object** (not a stringified JSON).
    public static let toolCallResponse = """
    {
      "model": "llama3.2:latest",
      "created_at": "2026-07-18T12:00:02.000000Z",
      "message": {
        "role": "assistant",
        "content": "",
        "tool_calls": [
          {
            "function": {
              "name": "get_weather",
              "arguments": {
                "location": "San Francisco, CA",
                "unit": "fahrenheit"
              }
            }
          }
        ]
      },
      "done": true,
      "done_reason": "stop",
      "prompt_eval_count": 40,
      "eval_count": 18
    }
    """

    // MARK: - Streaming (newline-delimited JSON)

    /// Streaming content response using **real Ollama framing**: each line is a full
    /// `OllamaChatResponse`. Intermediate lines carry `done == false` and a partial
    /// `message.content`; the final line carries `done == true`, `done_reason`, and the
    /// `prompt_eval_count`/`eval_count` token counts. No `data:` prefix, no `[DONE]` sentinel.
    // swiftlint:disable line_length
    public static let streamingResponseLines = [
        "{\"model\":\"llama3.2:latest\",\"created_at\":\"2026-07-18T12:00:03.000000Z\",\"message\":{\"role\":\"assistant\",\"content\":\"Hello\"},\"done\":false}",
        "{\"model\":\"llama3.2:latest\",\"created_at\":\"2026-07-18T12:00:03.100000Z\",\"message\":{\"role\":\"assistant\",\"content\":\", \"},\"done\":false}",
        "{\"model\":\"llama3.2:latest\",\"created_at\":\"2026-07-18T12:00:03.200000Z\",\"message\":{\"role\":\"assistant\",\"content\":\"world!\"},\"done\":false}",
        "{\"model\":\"llama3.2:latest\",\"created_at\":\"2026-07-18T12:00:03.300000Z\",\"message\":{\"role\":\"assistant\",\"content\":\"\"},\"done\":true,\"done_reason\":\"stop\",\"prompt_eval_count\":11,\"eval_count\":3}"
    ]

    /// Streaming tool-call response using **real Ollama framing**. Ollama delivers a tool call as a
    /// single complete object (arguments are a JSON object, not fragmented across lines); the final
    /// line carries usage and `done == true`.
    public static let streamingToolCallLines = [
        "{\"model\":\"llama3.2:latest\",\"created_at\":\"2026-07-18T12:00:04.000000Z\",\"message\":{\"role\":\"assistant\",\"content\":\"\",\"tool_calls\":[{\"function\":{\"name\":\"get_weather\",\"arguments\":{\"location\":\"NYC\"}}}]},\"done\":false}",
        "{\"model\":\"llama3.2:latest\",\"created_at\":\"2026-07-18T12:00:04.100000Z\",\"message\":{\"role\":\"assistant\",\"content\":\"\"},\"done\":true,\"done_reason\":\"stop\",\"prompt_eval_count\":25,\"eval_count\":15}"
    ]
    // swiftlint:enable line_length

    // MARK: - Models List (`/api/tags`)

    /// Sample `/api/tags` models-list response with a few locally-available models.
    public static let modelsListResponse = """
    {
      "models": [
        {
          "name": "llama3.2:latest",
          "model": "llama3.2:latest",
          "modified_at": "2026-07-01T09:00:00.000000Z",
          "size": 2019393189,
          "digest": "a80c4f17acd5b0f8e1a1c2d3e4f5a6b7c8d9e0f1",
          "details": {
            "format": "gguf",
            "family": "llama",
            "families": ["llama"],
            "parameter_size": "3.2B",
            "quantization_level": "Q4_K_M"
          }
        },
        {
          "name": "qwen2.5:latest",
          "model": "qwen2.5:latest",
          "modified_at": "2026-07-02T09:00:00.000000Z",
          "size": 4683075271,
          "digest": "b91d5e28bde6c1f9f2b2d3e4f5a6b7c8d9e0f1a2",
          "details": {
            "format": "gguf",
            "family": "qwen2",
            "families": ["qwen2"],
            "parameter_size": "7.6B",
            "quantization_level": "Q4_K_M"
          }
        },
        {
          "name": "mistral:latest",
          "model": "mistral:latest",
          "modified_at": "2026-07-03T09:00:00.000000Z",
          "size": 4113301824,
          "digest": "c02e6f39cef7d2a0a3c3d4e5f6a7b8c9d0e1f2a3",
          "details": {
            "format": "gguf",
            "family": "llama",
            "families": ["llama"],
            "parameter_size": "7.2B",
            "quantization_level": "Q4_0"
          }
        }
      ]
    }
    """

    // MARK: - Error Responses

    /// Model-not-found error (Ollama returns a bare `{"error": "..."}`).
    public static let modelNotFoundError = """
    {
      "error": "model 'nonexistent' not found, try pulling it first"
    }
    """

    // MARK: - Helper Methods

    /// Join newline-JSON streaming lines into a single `Data` blob (trailing newline included).
    public static func streamingResponseAsData(_ lines: [String]) -> Data {
        let combined = lines.joined(separator: "\n") + "\n"
        return combined.data(using: .utf8) ?? Data()
    }

    /// Get a response string as `Data`.
    public static func responseAsData(_ response: String) -> Data {
        response.data(using: .utf8) ?? Data()
    }
}
