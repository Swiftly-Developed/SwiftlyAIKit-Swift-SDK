import Foundation

/// Canned Cartesia API payloads for offline unit tests.
///
/// The SDK has no HTTP-mock injection path (providers hold a concrete `HTTPClientManager`), so
/// tests decode these fixtures directly and feed synthetic streams to the provider's internal
/// parsing helpers — no network.
enum MockCartesiaAPI {
    // MARK: - Streaming (SSE)

    /// Wrap a JSON object string in a Cartesia SSE frame (`data: {json}\n\n`).
    static func sseFrame(_ json: String) -> String { "data: \(json)\n\n" }

    /// A `"chunk"` SSE frame carrying the given audio as base64.
    static func chunkFrame(_ audio: Data) -> String {
        sseFrame("{\"type\":\"chunk\",\"done\":false,\"data\":\"\(audio.base64EncodedString())\"}")
    }

    /// The terminating `"done"` SSE frame.
    static let doneFrame = sseFrame("{\"type\":\"done\",\"done\":true}")

    /// An informational `"timestamps"` frame the audio stream must ignore.
    static let timestampsFrame = sseFrame(
        "{\"type\":\"timestamps\",\"done\":false,\"word_timestamps\":{\"words\":[\"hi\"],\"start\":[0.0],\"end\":[0.4]}}"
    )

    /// An `"error"` SSE frame.
    static func errorFrame(_ message: String) -> String {
        sseFrame("{\"type\":\"error\",\"done\":true,\"error\":\"\(message)\"}")
    }

    // MARK: - Speech-to-Text

    /// A batch Ink-Whisper `/stt` response with per-word timing.
    static let transcriptionResponse = """
    {
      "type": "transcript",
      "request_id": "req_abc123",
      "text": "Hello world",
      "language": "en",
      "duration": 1.25,
      "words": [
        { "word": "Hello", "start": 0.0, "end": 0.5 },
        { "word": "world", "start": 0.5, "end": 1.0 }
      ]
    }
    """

    // MARK: - Voices

    /// A `GET /voices` response envelope with a single voice.
    static let voicesResponse = """
    {
      "data": [
        {
          "id": "a0e99841-438c-4a64-b679-ae501e7d6091",
          "name": "Barbershop Man",
          "description": "A calm, warm narrator voice",
          "language": "en",
          "is_owner": false
        }
      ],
      "has_more": false,
      "next_page": null
    }
    """
}
