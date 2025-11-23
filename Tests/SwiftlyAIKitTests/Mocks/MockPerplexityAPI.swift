import Foundation

/// Mock responses for Perplexity AI API endpoints
///
/// This enum provides sample JSON responses for testing the Perplexity provider
/// without making actual API calls.
public enum MockPerplexityAPI {
    // MARK: - Standard Responses

    /// Simple text completion response
    public static let chatCompletionResponse = """
    {
      "id": "pplx-12345678-abcd-1234-abcd-123456789abc",
      "model": "sonar",
      "created": 1234567890,
      "object": "chat.completion",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Hello! I'm Perplexity AI, an AI assistant with real-time web search capabilities. How can I help you today?"
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 15,
        "completion_tokens": 28,
        "total_tokens": 43
      }
    }
    """

    /// Response with citations
    public static let chatCompletionWithCitationsResponse = """
    {
      "id": "pplx-87654321-dcba-4321-dcba-987654321cba",
      "model": "sonar-pro",
      "created": 1234567891,
      "object": "chat.completion",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "The latest AI research shows significant advances in large language models. According to recent studies, transformer architectures continue to dominate the field."
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 20,
        "completion_tokens": 35,
        "total_tokens": 55
      },
      "citations": [
        "https://arxiv.org/abs/2023.12345",
        "https://ai.google/research/pubs/pub54321",
        "https://openai.com/research/transformer-models"
      ]
    }
    """

    /// Response with max tokens reached
    public static let maxTokensResponse = """
    {
      "id": "pplx-11111111-aaaa-1111-aaaa-111111111111",
      "model": "sonar",
      "created": 1234567892,
      "object": "chat.completion",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "This is a partial response that was cut off because"
          },
          "finish_reason": "length"
        }
      ],
      "usage": {
        "prompt_tokens": 50,
        "completion_tokens": 1024,
        "total_tokens": 1074
      }
    }
    """

    /// Response with content filter
    public static let contentFilteredResponse = """
    {
      "id": "pplx-22222222-bbbb-2222-bbbb-222222222222",
      "model": "sonar",
      "created": 1234567893,
      "object": "chat.completion",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": ""
          },
          "finish_reason": "content_filter"
        }
      ],
      "usage": {
        "prompt_tokens": 25,
        "completion_tokens": 0,
        "total_tokens": 25
      }
    }
    """

    // MARK: - Streaming Responses

    /// SSE stream events for a simple message
    public static let streamEvents = [
        "data: {\\"id\\":\\"pplx-stream-1\\",\\"model\\":\\"sonar\\",\\"created\\":1234567890,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"role\\":\\"assistant\\",\\"content\\":\\"Hello\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-1\\",\\"model\\":\\"sonar\\",\\"created\\":1234567890,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\"! How\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-1\\",\\"model\\":\\"sonar\\",\\"created\\":1234567890,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\" can\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-1\\",\\"model\\":\\"sonar\\",\\"created\\":1234567890,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\" I\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-1\\",\\"model\\":\\"sonar\\",\\"created\\":1234567890,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\" help\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-1\\",\\"model\\":\\"sonar\\",\\"created\\":1234567890,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\" you\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-1\\",\\"model\\":\\"sonar\\",\\"created\\":1234567890,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\"?\\"},\\"finish_reason\\":\\"stop\\"}]}",
        "data: [DONE]"
    ]

    /// Stream events with citations
    public static let streamEventsWithCitations = [
        "data: {\\"id\\":\\"pplx-stream-2\\",\\"model\\":\\"sonar-pro\\",\\"created\\":1234567891,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"role\\":\\"assistant\\",\\"content\\":\\"According\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-2\\",\\"model\\":\\"sonar-pro\\",\\"created\\":1234567891,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\" to\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-2\\",\\"model\\":\\"sonar-pro\\",\\"created\\":1234567891,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\" recent\\"},\\"finish_reason\\":null}]}",
        "data: {\\"id\\":\\"pplx-stream-2\\",\\"model\\":\\"sonar-pro\\",\\"created\\":1234567891,\\"object\\":\\"chat.completion.chunk\\",\\"choices\\":[{\\"index\\":0,\\"delta\\":{\\"content\\":\\" research...\\"},\\"finish_reason\\":\\"stop\\"}]}",
        "data: [DONE]"
    ]

    // MARK: - Error Responses

    /// 400 Bad Request error
    public static let badRequestError = """
    {
      "error": {
        "message": "Invalid request: missing required field 'model'",
        "type": "invalid_request_error",
        "code": "invalid_request"
      }
    }
    """

    /// 401 Unauthorized error
    public static let unauthorizedError = """
    {
      "error": {
        "message": "Invalid API key provided",
        "type": "authentication_error",
        "code": "invalid_api_key"
      }
    }
    """

    /// 403 Forbidden error
    public static let forbiddenError = """
    {
      "error": {
        "message": "Access denied to this resource",
        "type": "permission_error",
        "code": "forbidden"
      }
    }
    """

    /// 404 Not Found error
    public static let notFoundError = """
    {
      "error": {
        "message": "The requested model does not exist",
        "type": "not_found_error",
        "code": "model_not_found"
      }
    }
    """

    /// 429 Rate Limit error
    public static let rateLimitError = """
    {
      "error": {
        "message": "Rate limit exceeded. Please try again later.",
        "type": "rate_limit_error",
        "code": "rate_limit_exceeded"
      }
    }
    """

    /// 500 Internal Server error
    public static let internalServerError = """
    {
      "error": {
        "message": "An internal server error occurred",
        "type": "server_error",
        "code": "internal_error"
      }
    }
    """

    /// 503 Service Unavailable error
    public static let serviceUnavailableError = """
    {
      "error": {
        "message": "Service temporarily unavailable",
        "type": "server_error",
        "code": "service_unavailable"
      }
    }
    """

    // MARK: - Search-Specific Responses

    /// Response with domain filtering
    public static let domainFilteredResponse = """
    {
      "id": "pplx-33333333-cccc-3333-cccc-333333333333",
      "model": "sonar",
      "created": 1234567894,
      "object": "chat.completion",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Here's information specifically from arxiv.org and github.com about transformer models."
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 30,
        "completion_tokens": 20,
        "total_tokens": 50
      },
      "citations": [
        "https://arxiv.org/abs/2023.54321",
        "https://github.com/transformer-research/paper"
      ]
    }
    """

    /// Response with recency filtering
    public static let recencyFilteredResponse = """
    {
      "id": "pplx-44444444-dddd-4444-dddd-444444444444",
      "model": "sonar-pro",
      "created": 1234567895,
      "object": "chat.completion",
      "choices": [
        {
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Based on news from the past week, there have been major AI announcements from several companies."
          },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 25,
        "completion_tokens": 22,
        "total_tokens": 47
      },
      "citations": [
        "https://techcrunch.com/2025/11/20/ai-news",
        "https://venturebeat.com/ai/latest-models-2025-11-21"
      ]
    }
    """
}
