import Foundation
@testable import SwiftlyAIKit

/// Mock Deepgram API responses for testing.
///
/// Provides a realistic nested `POST /listen` (Nova speech-to-text) response fixture. Deepgram
/// nests the transcript under `results.channels[].alternatives[]`, with per-word timing and a
/// top-level `metadata.duration`; field names on the wire are snake_case
/// (`detected_language`, `punctuated_word`).
public enum MockDeepgramAPI {
    // MARK: - Listen API (speech-to-text)

    /// Sample successful `POST /listen` response: transcript "hello world" with two timed words
    /// (each carrying a `punctuated_word` display form), a detected language, and audio duration.
    public static let listenResponse = """
    {
      "metadata": {
        "duration": 3.48
      },
      "results": {
        "channels": [
          {
            "detected_language": "en",
            "alternatives": [
              {
                "transcript": "hello world",
                "confidence": 0.99,
                "words": [
                  {
                    "word": "hello",
                    "start": 0.16,
                    "end": 0.48,
                    "confidence": 0.98,
                    "punctuated_word": "Hello"
                  },
                  {
                    "word": "world",
                    "start": 0.52,
                    "end": 0.96,
                    "confidence": 0.99,
                    "punctuated_word": "world."
                  }
                ]
              }
            ]
          }
        ]
      }
    }
    """

    // MARK: - Helper Methods

    /// Get a response string as `Data`.
    public static func responseAsData(_ response: String) -> Data {
        Data(response.utf8)
    }
}
