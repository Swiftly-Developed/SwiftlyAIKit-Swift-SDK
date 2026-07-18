import Foundation
@testable import SwiftlyAIKit

/// Mock ElevenLabs API responses for testing.
///
/// Provides canned JSON for the Scribe speech-to-text endpoint (`POST /speech-to-text`) and the
/// voices-list endpoint (`GET /voices`). Text-to-speech responses are raw audio bytes, so they are
/// exercised directly in the tests rather than modeled here.
public enum MockElevenLabsAPI {
    // MARK: - Speech-to-Text (Scribe)

    /// A canned Scribe transcription response.
    ///
    /// Includes `word`, `spacing`, and `audio_event` token types. Spacing tokens carry timing but
    /// should be dropped; the `audio_event` token has no timing and must be dropped defensively.
    public static let transcriptionResponse = """
    {
      "language_code": "en",
      "language_probability": 0.98,
      "text": "Hello world.",
      "words": [
        { "text": "Hello", "start": 0.0, "end": 0.5, "type": "word" },
        { "text": " ", "start": 0.5, "end": 0.55, "type": "spacing" },
        { "text": "world", "start": 0.55, "end": 1.1, "type": "word" },
        { "text": ".", "start": 1.1, "end": 1.2, "type": "word" },
        { "text": "(laughter)", "type": "audio_event" }
      ]
    }
    """

    // MARK: - Voices List (`/voices`)

    /// A canned voices-list response with a few premade voices.
    public static let voicesResponse = """
    {
      "voices": [
        { "voice_id": "21m00Tcm4TlvDq8ikWAM", "name": "Rachel", "category": "premade" },
        { "voice_id": "AZnzlk1XvdvUeBnXmlld", "name": "Domi", "category": "premade" },
        { "voice_id": "EXAVITQu4vr4xnSDxMaL", "name": "Bella", "category": "premade" }
      ]
    }
    """

    // MARK: - Add Voice (`/voices/add`)

    /// A canned add-voice / clone response.
    public static let addVoiceResponse = """
    {
      "voice_id": "cloned123voiceid456"
    }
    """

    // MARK: - Helper Methods

    /// Get a response string as `Data`.
    public static func responseAsData(_ response: String) -> Data {
        response.data(using: .utf8) ?? Data()
    }
}
