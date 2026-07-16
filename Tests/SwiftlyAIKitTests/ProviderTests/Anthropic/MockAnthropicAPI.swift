import Foundation
@testable import SwiftlyAIKit

/// Mock Anthropic API responses for testing
///
/// Provides pre-configured responses for all 8 Anthropic API endpoints.
/// Includes SSE event sequences for streaming and JSONL data for batch results.
public enum MockAnthropicAPI {
    // MARK: - Messages API

    /// Sample successful message response
    public static let messageResponse = """
    {
      "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "text",
          "text": "Hello! I'm Claude, an AI assistant. How can I help you today?"
        }
      ],
      "model": "claude-sonnet-4-20250514",
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "usage": {
        "input_tokens": 10,
        "output_tokens": 25
      }
    }
    """

    /// Sample message with thinking
    public static let messageWithThinking = """
    {
      "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "thinking",
          "thinking": "Let me think about this problem step by step..."
        },
        {
          "type": "text",
          "text": "Based on my analysis, the answer is 42."
        }
      ],
      "model": "claude-sonnet-4-20250514",
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "usage": {
        "input_tokens": 15,
        "output_tokens": 50,
        "cache_creation_input_tokens": 0,
        "cache_read_input_tokens": 0
      }
    }
    """

    /// Sample message with tool use
    public static let messageWithToolUse = """
    {
      "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "text",
          "text": "I'll check the weather for you."
        },
        {
          "type": "tool_use",
          "id": "toolu_01A09q90qw90lq917835lq9",
          "name": "get_weather",
          "input": {
            "location": "San Francisco, CA",
            "unit": "fahrenheit"
          }
        }
      ],
      "model": "claude-sonnet-4-20250514",
      "stop_reason": "tool_use",
      "stop_sequence": null,
      "usage": {
        "input_tokens": 20,
        "output_tokens": 30
      }
    }
    """

    /// Sample message with cached tokens
    public static let messageWithCaching = """
    {
      "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "text",
          "text": "Here's the summary based on the cached document."
        }
      ],
      "model": "claude-sonnet-4-20250514",
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "usage": {
        "input_tokens": 50,
        "output_tokens": 20,
        "cache_creation_input_tokens": 2000,
        "cache_read_input_tokens": 1950
      }
    }
    """

    // MARK: - Streaming Events

    /// SSE event sequence for streaming
    // swiftlint:disable line_length
    public static let streamEvents: [String] = [
        "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_01XFDUDYJgAACzvnptvVoYEL\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[],\"model\":\"claude-sonnet-4-20250514\",\"stop_reason\":null,\"stop_sequence\":null,\"usage\":{\"input_tokens\":10,\"output_tokens\":0}}}\n\n",
        "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\" world\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"!\"}}\n\n",
        "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n",
        "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":3}}\n\n",
        "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
    ]
    // swiftlint:enable line_length

    /// SSE events with thinking block
    // swiftlint:disable line_length
    public static let streamEventsWithThinking: [String] = [
        "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_thinking\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[],\"model\":\"claude-sonnet-4-20250514\",\"stop_reason\":null,\"stop_sequence\":null,\"usage\":{\"input_tokens\":15,\"output_tokens\":0}}}\n\n",
        "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"thinking\",\"thinking\":\"\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"thinking_delta\",\"thinking\":\"Let me think...\"}}\n\n",
        "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n",
        "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"text_delta\",\"text\":\"The answer is 42.\"}}\n\n",
        "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":1}\n\n",
        "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":20}}\n\n",
        "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
    ]
    // swiftlint:enable line_length

    /// SSE events with a tool_use block (streamed input_json_delta fragments)
    // swiftlint:disable line_length
    public static let streamEventsWithToolUse: [String] = [
        "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_tool_stream\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[],\"model\":\"claude-sonnet-4-20250514\",\"stop_reason\":null,\"stop_sequence\":null,\"usage\":{\"input_tokens\":20,\"output_tokens\":0}}}\n\n",
        "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Let me check the weather.\"}}\n\n",
        "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n",
        "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\",\"id\":\"toolu_01A09q90qw90lq917835lq9\",\"name\":\"get_weather\",\"input\":{}}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{\\\"location\\\":\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\" \\\"San Francisco, CA\\\"}\"}}\n\n",
        "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":1}\n\n",
        "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":30}}\n\n",
        "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
    ]
    // swiftlint:enable line_length

    /// Sample message with a web_search server-tool result
    public static let messageWithWebSearch = """
    {
      "id": "msg_websearch",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "server_tool_use",
          "id": "srvtoolu_01",
          "name": "web_search",
          "input": {"query": "swift concurrency"}
        },
        {
          "type": "web_search_tool_result",
          "tool_use_id": "srvtoolu_01",
          "content": [
            {"type": "web_search_result", "url": "https://swift.org/", "title": "Swift.org"}
          ]
        },
        {
          "type": "text",
          "text": "Swift has structured concurrency."
        }
      ],
      "model": "claude-sonnet-4-20250514",
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "usage": {
        "input_tokens": 30,
        "output_tokens": 40
      }
    }
    """

    // MARK: - Token Counting

    /// Sample token count response
    public static let tokenCountResponse = """
    {
      "input_tokens": 2095
    }
    """

    // MARK: - Batch API

    /// Sample batch creation response
    public static let batchCreateResponse = """
    {
      "id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
      "type": "message_batch",
      "processing_status": "in_progress",
      "request_counts": {
        "processing": 100,
        "succeeded": 0,
        "errored": 0,
        "canceled": 0,
        "expired": 0
      },
      "ended_at": null,
      "created_at": "2025-11-23T00:00:00Z",
      "expires_at": "2025-11-24T00:00:00Z",
      "cancel_initiated_at": null,
      "results_url": null
    }
    """

    /// Sample batch retrieval response (in progress)
    public static let batchInProgressResponse = """
    {
      "id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
      "type": "message_batch",
      "processing_status": "in_progress",
      "request_counts": {
        "processing": 50,
        "succeeded": 40,
        "errored": 5,
        "canceled": 0,
        "expired": 0
      },
      "ended_at": null,
      "created_at": "2025-11-23T00:00:00Z",
      "expires_at": "2025-11-24T00:00:00Z",
      "cancel_initiated_at": null,
      "results_url": null
    }
    """

    /// Sample batch retrieval response (ended)
    public static let batchEndedResponse = """
    {
      "id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
      "type": "message_batch",
      "processing_status": "ended",
      "request_counts": {
        "processing": 0,
        "succeeded": 90,
        "errored": 5,
        "canceled": 0,
        "expired": 5
      },
      "ended_at": "2025-11-23T01:00:00Z",
      "created_at": "2025-11-23T00:00:00Z",
      "expires_at": "2025-11-24T00:00:00Z",
      "cancel_initiated_at": null,
      "results_url": "https://api.anthropic.com/v1/messages/batches/msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d/results"
    }
    """

    /// Sample batch cancellation response
    public static let batchCanceledResponse = """
    {
      "id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
      "type": "message_batch",
      "processing_status": "canceling",
      "request_counts": {
        "processing": 30,
        "succeeded": 40,
        "errored": 5,
        "canceled": 20,
        "expired": 0
      },
      "ended_at": null,
      "created_at": "2025-11-23T00:00:00Z",
      "expires_at": "2025-11-24T00:00:00Z",
      "cancel_initiated_at": "2025-11-23T00:30:00Z",
      "results_url": null
    }
    """

    /// Sample batch list response
    public static let batchListResponse = """
    {
      "data": [
        {
          "id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
          "type": "message_batch",
          "processing_status": "ended",
          "request_counts": {
            "processing": 0,
            "succeeded": 90,
            "errored": 5,
            "canceled": 0,
            "expired": 5
          },
          "ended_at": "2025-11-23T01:00:00Z",
          "created_at": "2025-11-23T00:00:00Z",
          "expires_at": "2025-11-24T00:00:00Z",
          "cancel_initiated_at": null,
          "results_url": "https://api.anthropic.com/v1/messages/batches/msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d/results"
        },
        {
          "id": "msgbatch_02AnotherBatchId123456",
          "type": "message_batch",
          "processing_status": "in_progress",
          "request_counts": {
            "processing": 50,
            "succeeded": 40,
            "errored": 5,
            "canceled": 0,
            "expired": 0
          },
          "ended_at": null,
          "created_at": "2025-11-23T02:00:00Z",
          "expires_at": "2025-11-24T02:00:00Z",
          "cancel_initiated_at": null,
          "results_url": null
        }
      ],
      "has_more": false,
      "first_id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
      "last_id": "msgbatch_02AnotherBatchId123456"
    }
    """

    /// Sample batch results (JSONL format)
    // swiftlint:disable line_length
    public static let batchResultsJSONL = """
    {"custom_id":"request-1","result":{"type":"succeeded","message":{"id":"msg_01XFDUDYJgAACzvnptvVoYEL","type":"message","role":"assistant","content":[{"type":"text","text":"Hello from batch request 1!"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":15}}}}
    {"custom_id":"request-2","result":{"type":"succeeded","message":{"id":"msg_02AnotherMessageId567890","type":"message","role":"assistant","content":[{"type":"text","text":"Hello from batch request 2!"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":15}}}}
    {"custom_id":"request-3","result":{"type":"errored","error":{"type":"invalid_request_error","message":"Invalid request"}}}
    """
    // swiftlint:enable line_length

    // MARK: - Error Responses

    /// Sample 400 Bad Request error
    public static let error400 = """
    {
      "type": "error",
      "error": {
        "type": "invalid_request_error",
        "message": "Invalid request: missing required field 'model'"
      }
    }
    """

    /// Sample 401 Unauthorized error
    public static let error401 = """
    {
      "type": "error",
      "error": {
        "type": "authentication_error",
        "message": "Invalid API key"
      }
    }
    """

    /// Sample 403 Forbidden error
    public static let error403 = """
    {
      "type": "error",
      "error": {
        "type": "permission_error",
        "message": "Your API key does not have permission to use the specified model"
      }
    }
    """

    /// Sample 429 Rate Limit error
    public static let error429 = """
    {
      "type": "error",
      "error": {
        "type": "rate_limit_error",
        "message": "Rate limit exceeded"
      }
    }
    """

    /// Sample 500 Internal Server error
    public static let error500 = """
    {
      "type": "error",
      "error": {
        "type": "api_error",
        "message": "Internal server error"
      }
    }
    """

    /// Sample 529 Overloaded error
    public static let error529 = """
    {
      "type": "error",
      "error": {
        "type": "overloaded_error",
        "message": "API is temporarily overloaded"
      }
    }
    """

    // MARK: - Helper Methods

    /// Get SSE event data chunks
    public static func getStreamChunks() -> [Data] {
        streamEvents.map { Data($0.utf8) }
    }

    /// Get thinking SSE event data chunks
    public static func getThinkingStreamChunks() -> [Data] {
        streamEventsWithThinking.map { Data($0.utf8) }
    }

    /// Get batch results as data chunks (one line per chunk)
    public static func getBatchResultChunks() -> [Data] {
        batchResultsJSONL.split(separator: "\n").map { Data(String($0).utf8) }
    }
}
