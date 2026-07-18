import Foundation

/// Canned OpenRouter API payloads for decode/mapping tests.
///
/// Fixtures are decoded directly into the `OpenRouter*` response types (mirroring the
/// repo's provider-test convention — there is no mock-HTTP injection path). The `/models`
/// fixture is deliberately multi-vendor so tests can assert namespaced `"vendor/model"`
/// ids survive verbatim.
enum MockOpenRouterAPI {
    /// A successful chat completion response.
    static let chatCompletionResponse = """
    {
      "id": "gen-abc123",
      "object": "chat.completion",
      "created": 1730000000,
      "model": "anthropic/claude-3.5-sonnet",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Hello from OpenRouter!"
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 12,
        "completion_tokens": 5,
        "total_tokens": 17
      }
    }
    """

    /// A response whose assistant turn is a single tool call.
    static let toolCallResponse = """
    {
      "id": "gen-tool1",
      "object": "chat.completion",
      "created": 1730000001,
      "model": "openai/gpt-4o",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": null,
            "tool_calls": [
              {
                "id": "call_1",
                "type": "function",
                "function": {
                  "name": "get_weather",
                  "arguments": "{\\"location\\":\\"SF\\"}"
                }
              }
            ]
          },
          "finish_reason": "tool_calls"
        }
      ],
      "usage": {
        "prompt_tokens": 10,
        "completion_tokens": 8,
        "total_tokens": 18
      }
    }
    """

    /// A multi-vendor `GET /models` catalog with namespaced ids, names, context lengths,
    /// and pricing blocks. Includes the four seed models plus one minimal (id-only) entry.
    static let modelsListResponse = """
    {
      "data": [
        {
          "id": "openai/gpt-4o",
          "name": "OpenAI: GPT-4o",
          "context_length": 128000,
          "pricing": { "prompt": "0.0000025", "completion": "0.00001", "request": "0", "image": "0.003613" }
        },
        {
          "id": "anthropic/claude-3.5-sonnet",
          "name": "Anthropic: Claude 3.5 Sonnet",
          "context_length": 200000,
          "pricing": { "prompt": "0.000003", "completion": "0.000015" }
        },
        {
          "id": "google/gemini-2.0-flash",
          "name": "Google: Gemini 2.0 Flash",
          "context_length": 1000000,
          "pricing": { "prompt": "0.0000001", "completion": "0.0000004" }
        },
        {
          "id": "meta-llama/llama-3.3-70b-instruct",
          "name": "Meta: Llama 3.3 70B Instruct",
          "context_length": 131072,
          "pricing": { "prompt": "0.00000012", "completion": "0.0000003" }
        },
        {
          "id": "mistralai/mistral-large"
        }
      ]
    }
    """

    /// An OpenRouter error response.
    static let authenticationError = """
    {
      "error": {
        "message": "No auth credentials found",
        "code": 401
      }
    }
    """

    /// Streaming SSE events (OpenAI-compatible framing): incremental content then a
    /// delta-less finish chunk, terminated by `[DONE]`.
    static let streamingContentEvents: [String] = [
        #"data: {"id":"gen-s1","model":"anthropic/claude-3.5-sonnet","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}"#,
        #"data: {"id":"gen-s1","model":"anthropic/claude-3.5-sonnet","choices":[{"index":0,"delta":{"content":", world!"},"finish_reason":null}]}"#,
        #"data: {"id":"gen-s1","model":"anthropic/claude-3.5-sonnet","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#,
        "data: [DONE]"
    ]
}
