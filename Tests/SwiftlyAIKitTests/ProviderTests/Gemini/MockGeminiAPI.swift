import Foundation
@testable import SwiftlyAIKit

/// Mock Gemini API responses for testing
///
/// Provides pre-configured responses for Gemini API endpoints.
/// Includes SSE event sequences for streaming.
public enum MockGeminiAPI {
    // MARK: - GenerateContent API

    /// Sample successful generate content response
    public static let generateContentResponse = """
    {
      "candidates": [
        {
          "content": {
            "parts": [
              {
                "text": "Hello! I'm Gemini, an AI assistant. How can I help you today?"
              }
            ],
            "role": "model"
          },
          "finishReason": "STOP",
          "safetyRatings": [
            {
              "category": "HARM_CATEGORY_HARASSMENT",
              "probability": "NEGLIGIBLE"
            },
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "probability": "NEGLIGIBLE"
            }
          ]
        }
      ],
      "usageMetadata": {
        "promptTokenCount": 10,
        "candidatesTokenCount": 25,
        "totalTokenCount": 35
      },
      "modelVersion": "gemini-2.5-pro"
    }
    """

    /// Sample response with multimodal content
    public static let multimodalResponse = """
    {
      "candidates": [
        {
          "content": {
            "parts": [
              {
                "text": "This image shows a beautiful sunset over the ocean."
              }
            ],
            "role": "model"
          },
          "finishReason": "STOP"
        }
      ],
      "usageMetadata": {
        "promptTokenCount": 258,
        "candidatesTokenCount": 15,
        "totalTokenCount": 273
      }
    }
    """

    /// Sample response with function call
    public static let functionCallResponse = """
    {
      "candidates": [
        {
          "content": {
            "parts": [
              {
                "text": "I'll check the weather for you."
              },
              {
                "functionCall": {
                  "name": "get_weather",
                  "args": {
                    "location": "San Francisco, CA",
                    "unit": "fahrenheit"
                  }
                }
              }
            ],
            "role": "model"
          },
          "finishReason": "STOP"
        }
      ],
      "usageMetadata": {
        "promptTokenCount": 20,
        "candidatesTokenCount": 30,
        "totalTokenCount": 50
      }
    }
    """

    /// Sample response with safety filtering
    public static let safetyFilteredResponse = """
    {
      "candidates": [
        {
          "content": {
            "parts": [
              {
                "text": "I cannot provide that information."
              }
            ],
            "role": "model"
          },
          "finishReason": "SAFETY",
          "safetyRatings": [
            {
              "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
              "probability": "HIGH"
            }
          ]
        }
      ],
      "usageMetadata": {
        "promptTokenCount": 15,
        "candidatesTokenCount": 8,
        "totalTokenCount": 23
      }
    }
    """

    /// Sample response with max tokens reached
    public static let maxTokensResponse = """
    {
      "candidates": [
        {
          "content": {
            "parts": [
              {
                "text": "This is a partial response that was cut off due to"
              }
            ],
            "role": "model"
          },
          "finishReason": "MAX_TOKENS"
        }
      ],
      "usageMetadata": {
        "promptTokenCount": 10,
        "candidatesTokenCount": 100,
        "totalTokenCount": 110
      }
    }
    """

    /// Sample empty response
    public static let emptyResponse = """
    {
      "candidates": [],
      "usageMetadata": {
        "promptTokenCount": 5,
        "candidatesTokenCount": 0,
        "totalTokenCount": 5
      }
    }
    """

    // MARK: - Streaming API

    /// SSE streaming events for a complete response
    public static let streamEvents = [
        // swiftlint:disable:next line_length
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hello\"}],\"role\":\"model\"}}],\"usageMetadata\":{\"promptTokenCount\":10,\"candidatesTokenCount\":1,\"totalTokenCount\":11}}",
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"! How\"}],\"role\":\"model\"}}]}",
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\" can\"}],\"role\":\"model\"}}]}",
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\" I\"}],\"role\":\"model\"}}]}",
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\" help\"}],\"role\":\"model\"}}]}",
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\" you\"}],\"role\":\"model\"}}]}",
        // swiftlint:disable:next line_length
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"?\"}],\"role\":\"model\"},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":10,\"candidatesTokenCount\":8,\"totalTokenCount\":18}}",
        "data: [DONE]"
    ]

    /// SSE streaming with function call
    public static let streamWithFunctionCall = [
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Let me check that for you.\"}],\"role\":\"model\"}}]}",
        // swiftlint:disable:next line_length
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"functionCall\":{\"name\":\"get_weather\",\"args\":{\"location\":\"Boston\"}}}],\"role\":\"model\"},\"finishReason\":\"STOP\"}]}",
        "data: [DONE]"
    ]

    // MARK: - Models List API

    /// Sample models.list response (mirrors Google's `GET /v1beta/models` shape).
    ///
    /// Includes a chat-capable model (`generateContent`), a non-chat model (`embedContent`)
    /// so filtering can be exercised, and a `nextPageToken` for optional pagination. Keys are
    /// camelCase, matching the real Gemini API.
    public static let listModelsResponse = """
    {
      "models": [
        {
          "name": "models/gemini-2.5-pro",
          "version": "2.5",
          "displayName": "Gemini 2.5 Pro",
          "description": "Our most capable model for complex reasoning tasks.",
          "inputTokenLimit": 2097152,
          "outputTokenLimit": 65536,
          "supportedGenerationMethods": ["generateContent", "countTokens"],
          "temperature": 1.0,
          "topP": 0.95,
          "topK": 64
        },
        {
          "name": "models/embedding-001",
          "displayName": "Embedding 001",
          "description": "Obtain a distributed representation of a text.",
          "inputTokenLimit": 2048,
          "outputTokenLimit": 1,
          "supportedGenerationMethods": ["embedContent"]
        }
      ],
      "nextPageToken": "abc123"
    }
    """

    // MARK: - Token Counting API

    /// Sample token count response
    public static let countTokensResponse = """
    {
      "totalTokens": 42
    }
    """

    /// Sample token count for long text
    public static let countTokensLongResponse = """
    {
      "totalTokens": 1523
    }
    """

    // MARK: - Error Responses

    /// Sample 400 Bad Request error
    public static let badRequestError = """
    {
      "error": {
        "code": 400,
        "message": "Invalid request: Missing required field 'contents'",
        "status": "INVALID_ARGUMENT"
      }
    }
    """

    /// Sample 401 Unauthorized error
    public static let unauthorizedError = """
    {
      "error": {
        "code": 401,
        "message": "API key not valid. Please pass a valid API key.",
        "status": "UNAUTHENTICATED",
        "details": [
          {
            "@type": "type.googleapis.com/google.rpc.ErrorInfo",
            "reason": "API_KEY_INVALID",
            "domain": "googleapis.com",
            "metadata": {
              "service": "generativelanguage.googleapis.com"
            }
          }
        ]
      }
    }
    """

    /// Sample 403 Forbidden error
    public static let permissionDeniedError = """
    {
      "error": {
        "code": 403,
        "message": "API key does not have permission to use this model",
        "status": "PERMISSION_DENIED"
      }
    }
    """

    /// Sample 404 Not Found error
    public static let notFoundError = """
    {
      "error": {
        "code": 404,
        "message": "Model not found: invalid-model",
        "status": "NOT_FOUND"
      }
    }
    """

    /// Sample 429 Rate Limit error
    public static let rateLimitError = """
    {
      "error": {
        "code": 429,
        "message": "Resource has been exhausted (e.g. check quota).",
        "status": "RESOURCE_EXHAUSTED",
        "details": [
          {
            "@type": "type.googleapis.com/google.rpc.ErrorInfo",
            "reason": "RATE_LIMIT_EXCEEDED",
            "domain": "googleapis.com"
          }
        ]
      }
    }
    """

    /// Sample 500 Internal Server error
    public static let internalServerError = """
    {
      "error": {
        "code": 500,
        "message": "An internal error has occurred. Please retry or report in https://developers.generativeai.google/guide/troubleshooting",
        "status": "INTERNAL"
      }
    }
    """

    /// Sample 503 Service Unavailable error
    public static let serviceUnavailableError = """
    {
      "error": {
        "code": 503,
        "message": "The service is currently unavailable.",
        "status": "UNAVAILABLE"
      }
    }
    """
}
