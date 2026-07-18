import Foundation
@testable import SwiftlyAIKit

/// Mock Cohere API responses for testing
///
/// Provides pre-configured responses for Cohere v2 API endpoints.
/// Includes SSE event sequences for streaming responses.
public enum MockCohereAPI {
    // MARK: - Chat Completions API

    /// Sample successful chat completion response
    public static let chatCompletionResponse = """
    {
      "id": "chat-abc123def456",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "Hello! I'm Cohere AI. How can I help you today?"
          }
        ]
      },
      "usage": {
        "billed_units": {
          "input_tokens": 12,
          "output_tokens": 15
        },
        "tokens": {
          "input_tokens": 12,
          "output_tokens": 15
        }
      }
    }
    """

    /// Sample response with RAG and citations
    public static let ragResponse = """
    {
      "id": "chat-rag123",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "According to the provided documents, Cohere was founded in 2019 by Aidan Gomez, Ivan Zhang, and Nick Frosst."
          }
        ]
      },
      "usage": {
        "billed_units": {
          "input_tokens": 50,
          "output_tokens": 25
        },
        "tokens": {
          "input_tokens": 50,
          "output_tokens": 25
        }
      },
      "citations": [
        {
          "start": 0,
          "end": 50,
          "text": "Cohere was founded in 2019 by Aidan Gomez",
          "document_ids": ["doc_0"]
        }
      ]
    }
    """

    /// Sample response with max tokens reached
    public static let maxTokensResponse = """
    {
      "id": "chat-maxtokens",
      "finish_reason": "MAX_TOKENS",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "This is a partial response that was cut off due to"
          }
        ]
      },
      "usage": {
        "billed_units": {
          "input_tokens": 10,
          "output_tokens": 100
        },
        "tokens": {
          "input_tokens": 10,
          "output_tokens": 100
        }
      }
    }
    """

    /// Sample response with stop sequence
    public static let stopSequenceResponse = """
    {
      "id": "chat-stop",
      "finish_reason": "STOP_SEQUENCE",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "Here is the answer you requested."
          }
        ]
      },
      "usage": {
        "billed_units": {
          "input_tokens": 15,
          "output_tokens": 8
        },
        "tokens": {
          "input_tokens": 15,
          "output_tokens": 8
        }
      }
    }
    """

    /// Sample response with tool calls
    public static let toolCallResponse = """
    {
      "id": "chat-tools456",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": ""
          }
        ],
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
      "usage": {
        "billed_units": {
          "input_tokens": 50,
          "output_tokens": 20
        },
        "tokens": {
          "input_tokens": 50,
          "output_tokens": 20
        }
      }
    }
    """

    /// Sample vision response (Command A Vision)
    public static let visionResponse = """
    {
      "id": "chat-vision123",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "This image shows a beautiful sunset over the ocean with vibrant orange and purple colors reflecting on the water."
          }
        ]
      },
      "usage": {
        "billed_units": {
          "input_tokens": 250,
          "output_tokens": 30
        },
        "tokens": {
          "input_tokens": 250,
          "output_tokens": 30
        }
      }
    }
    """

    /// Sample JSON structured output response
    public static let jsonResponse = """
    {
      "id": "chat-json123",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "{\\"title\\": \\"The Great Gatsby\\", \\"author\\": \\"F. Scott Fitzgerald\\", \\"publication_year\\": 1925}"
          }
        ]
      },
      "usage": {
        "billed_units": {
          "input_tokens": 30,
          "output_tokens": 25
        },
        "tokens": {
          "input_tokens": 30,
          "output_tokens": 25
        }
      }
    }
    """

    /// Sample empty response
    public static let emptyResponse = """
    {
      "id": "chat-empty",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": []
      },
      "usage": {
        "billed_units": {
          "input_tokens": 5,
          "output_tokens": 0
        },
        "tokens": {
          "input_tokens": 5,
          "output_tokens": 0
        }
      }
    }
    """

    // MARK: - Streaming Responses

    /// Sample streaming response sequence (SSE format)
    public static let streamingResponse = [
        "data: {\"type\":\"message-start\",\"id\":\"chat-stream123\"}",
        "data: {\"type\":\"content-start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\"Hello\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\"!\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" How\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" can\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" I\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" help\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" you\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\"?\"}}}}",
        "data: {\"type\":\"content-end\",\"index\":0}",
        // swiftlint:disable:next line_length
        "data: {\"type\":\"message-end\",\"delta\":{\"finish_reason\":\"COMPLETE\",\"usage\":{\"billed_units\":{\"input_tokens\":8,\"output_tokens\":6},\"tokens\":{\"input_tokens\":8,\"output_tokens\":6}}}}"
    ]

    /// Sample streaming response with RAG citations
    public static let streamingRAGResponse = [
        "data: {\"type\":\"message-start\",\"id\":\"chat-stream-rag\"}",
        "data: {\"type\":\"content-start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\"According\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" to\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" the\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" documents\"}}}}",
        // swiftlint:disable:next line_length
        "data: {\"type\":\"citation-start\",\"index\":0,\"citation\":{\"start\":0,\"end\":25,\"text\":\"According to the documents\",\"document_ids\":[\"doc_0\"]}}",
        "data: {\"type\":\"citation-end\",\"index\":0}",
        "data: {\"type\":\"content-end\",\"index\":0}",
        // swiftlint:disable:next line_length
        "data: {\"type\":\"message-end\",\"delta\":{\"finish_reason\":\"COMPLETE\",\"usage\":{\"billed_units\":{\"input_tokens\":40,\"output_tokens\":10},\"tokens\":{\"input_tokens\":40,\"output_tokens\":10}}}}"
    ]

    /// Sample streaming response with max tokens
    public static let streamingMaxTokensResponse = [
        "data: {\"type\":\"message-start\",\"id\":\"chat-stream-max\"}",
        "data: {\"type\":\"content-start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\"This\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" is\"}}}}",
        "data: {\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\" cut\"}}}}",
        "data: {\"type\":\"content-end\",\"index\":0}",
        // swiftlint:disable:next line_length
        "data: {\"type\":\"message-end\",\"delta\":{\"finish_reason\":\"MAX_TOKENS\",\"usage\":{\"billed_units\":{\"input_tokens\":5,\"output_tokens\":100},\"tokens\":{\"input_tokens\":5,\"output_tokens\":100}}}}"
    ]

    // MARK: - Tokenize API

    /// Sample tokenize response
    public static let tokenizeResponse = """
    {
      "tokens": [31587, 11, 1577, 525, 564, 30],
      "token_strings": ["Hello", ",", " how", " are", " you", "?"]
    }
    """

    /// Sample tokenize response for longer text
    // swiftlint:disable line_length
    public static let tokenizeLongResponse = """
    {
      "tokens": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
      "token_strings": ["The", " quick", " brown", " fox", " jumps", " over", " the", " lazy", " dog", ".", " This", " is", " a", " longer", " text", " used", " for", " testing", " token", " counting", " functionality", " with", " multiple", " sentences", " and", " various", " words", " of", " different", " lengths"]
    }
    """
    // swiftlint:enable line_length

    // MARK: - Error Responses

    /// Authentication error (401)
    public static let authenticationError = """
    {
      "message": "invalid api key",
      "status_code": 401
    }
    """

    /// Rate limit error (429)
    public static let rateLimitError = """
    {
      "message": "rate limit exceeded - please try again later",
      "status_code": 429
    }
    """

    /// Invalid request error (400)
    public static let invalidRequestError = """
    {
      "message": "invalid request: model parameter is required",
      "status_code": 400
    }
    """

    /// Validation error (422)
    public static let validationError = """
    {
      "message": "validation error: temperature must be between 0 and 1",
      "status_code": 422
    }
    """

    /// Server error (500)
    public static let serverError = """
    {
      "message": "internal server error",
      "status_code": 500
    }
    """

    /// Service unavailable error (503)
    public static let serviceUnavailableError = """
    {
      "message": "service temporarily unavailable",
      "status_code": 503
    }
    """

    // MARK: - Edge Cases

    /// Response with missing optional fields
    public static let minimalResponse = """
    {
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "Minimal response"
          }
        ]
      }
    }
    """

    /// Response with null values
    public static let nullFieldsResponse = """
    {
      "id": null,
      "finish_reason": null,
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "Response with nulls"
          }
        ]
      },
      "usage": null,
      "citations": null
    }
    """

    /// Response with empty content array but valid structure
    public static let emptyContentResponse = """
    {
      "id": "chat-empty-content",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": []
      },
      "usage": {
        "billed_units": {
          "input_tokens": 10,
          "output_tokens": 0
        },
        "tokens": {
          "input_tokens": 10,
          "output_tokens": 0
        }
      }
    }
    """

    // MARK: - Model-Specific Responses

    /// Response from Command A model
    public static let commandAResponse = """
    {
      "id": "chat-commanda123",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "I am Command A, Cohere's most capable model. I excel at complex reasoning, RAG workflows, and multilingual tasks."
          }
        ]
      },
      "usage": {
        "billed_units": {
          "input_tokens": 20,
          "output_tokens": 30
        },
        "tokens": {
          "input_tokens": 20,
          "output_tokens": 30
        }
      }
    }
    """

    /// Response from Command R model
    public static let commandRResponse = """
    {
      "id": "chat-commandr123",
      "finish_reason": "COMPLETE",
      "message": {
        "role": "assistant",
        "content": [
          {
            "type": "text",
            "text": "I am Command R, optimized for RAG and tool use with high efficiency and speed."
          }
        ]
      },
      "usage": {
        "billed_units": {
          "input_tokens": 15,
          "output_tokens": 20
        },
        "tokens": {
          "input_tokens": 15,
          "output_tokens": 20
        }
      }
    }
    """

    // MARK: - Models List API

    /// Sample response from the GET /models endpoint (paginated)
    public static let modelsListResponse = """
    {
      "models": [
        {
          "name": "command-a-03-2025",
          "endpoints": ["chat"],
          "context_length": 256000,
          "is_deprecated": false,
          "finetuned": false,
          "tokenizer_url": "https://storage.googleapis.com/cohere-tokenizers/command-a.json",
          "default_endpoints": ["chat"],
          "features": ["json_mode", "json_schema", "tools", "strict_tools"]
        },
        {
          "name": "command-r-plus-08-2024",
          "endpoints": ["chat"],
          "context_length": 256000,
          "is_deprecated": false,
          "finetuned": false,
          "default_endpoints": ["chat"]
        },
        {
          "name": "command-r-08-2024",
          "endpoints": ["chat"],
          "context_length": 256000,
          "is_deprecated": false,
          "finetuned": false,
          "default_endpoints": ["chat"]
        },
        {
          "name": "command-r7b-12-2024",
          "endpoints": ["chat"],
          "context_length": 256000,
          "is_deprecated": false,
          "finetuned": false,
          "default_endpoints": ["chat"]
        },
        {
          "name": "embed-english-v3.0",
          "endpoints": ["embed"],
          "context_length": 512,
          "is_deprecated": false,
          "finetuned": false
        }
      ],
      "next_page_token": "abc123nextpage"
    }
    """

    // MARK: - Helper Methods

    /// Convert streaming response array to Data
    public static func streamingResponseAsData(_ events: [String]) -> Data {
        let combined = events.joined(separator: "\n") + "\n"
        return combined.data(using: .utf8) ?? Data()
    }
}
