import Foundation

/// OpenAI voice provider implementation for text-to-speech and speech-to-text
///
/// `OpenAIVoiceProvider` conforms to ``TextToSpeech`` and ``SpeechToText``, reusing OpenAI's
/// API key and base URL (`https://api.openai.com/v1`, `Authorization: Bearer sk-…`). It is keyed
/// to the ``VoiceProviderType/openai`` voice token.
///
/// It is kept entirely **separate** from the chat ``OpenAIProvider``: it does not conform to
/// `ProviderProtocol`, adds no `ProviderType` case, and is never routed through
/// `AIGateway.sendMessage`. Voice is a distinct capability axis.
///
/// ## Overview
///
/// `OpenAIVoiceProvider` implements:
/// - Text-to-speech via `POST /audio/speech` (``synthesize(_:apiKey:)``,
///   ``streamSynthesize(_:apiKey:)``)
/// - Speech-to-text via `POST /audio/transcriptions` (``transcribe(_:apiKey:)``,
///   ``streamTranscribe(_:apiKey:)``)
///
/// Streaming transcription is gated to `gpt-4o-transcribe`/`gpt-4o-mini-transcribe`; `whisper-1`
/// has no SSE endpoint and finishes with `AIError.unsupportedFeature`.
///
/// ## Basic Usage
///
/// ```swift
/// let provider = OpenAIVoiceProvider()
/// let request = SpeechSynthesisRequest(text: "Hello, world.", model: "tts-1", voice: "alloy")
/// let response = try await provider.synthesize(request, apiKey: "sk-...")
/// try response.audio.write(to: fileURL)
/// ```
///
/// ## Topics
///
/// ### Creating Providers
/// - ``init(baseURL:organizationId:timeout:maxRetries:enableLogging:)``
/// - ``init(httpClient:baseURL:organizationId:timeout:maxRetries:enableLogging:)``
///
/// ### TextToSpeech Implementation
/// - ``supportsTextToSpeech``
/// - ``textToSpeechModels``
/// - ``synthesize(_:apiKey:)``
/// - ``streamSynthesize(_:apiKey:)``
///
/// ### SpeechToText Implementation
/// - ``supportsSpeechToText``
/// - ``speechToTextModels``
/// - ``transcribe(_:apiKey:)``
/// - ``streamTranscribe(_:apiKey:)``
///
/// ### Registries
/// - ``ttsModels``
/// - ``sttModels``
/// - ``voices``
/// - ``streamingTranscriptionModels``
public struct OpenAIVoiceProvider: TextToSpeech, SpeechToText, Sendable {
    /// The voice provider identity (distinct from the chat `ProviderType.openai`)
    public let voiceProviderType: VoiceProviderType = .openai

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let organizationId: String?
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize OpenAI voice provider with default HTTPClientManager
    /// - Parameters:
    ///   - baseURL: Base URL for the OpenAI API (default: https://api.openai.com/v1)
    ///   - organizationId: Optional organization ID for multi-tenant accounts
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = VoiceProviderType.openai.baseURL,
        organizationId: String? = nil,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = HTTPClientManager()
        self.baseURL = baseURL
        self.organizationId = organizationId
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    /// Initialize with custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for the OpenAI API
    ///   - organizationId: Optional organization ID
    ///   - timeout: Request timeout in seconds
    ///   - maxRetries: Maximum retry attempts
    ///   - enableLogging: Enable logging
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = VoiceProviderType.openai.baseURL,
        organizationId: String? = nil,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.organizationId = organizationId
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    // MARK: - Static Registries

    /// The default voice used when a ``SpeechSynthesisRequest`` omits one
    public static let defaultVoice = "alloy"

    /// Available text-to-speech models
    public static let ttsModels = ["tts-1", "tts-1-hd", "gpt-4o-mini-tts"]

    /// Available speech-to-text models
    public static let sttModels = ["whisper-1", "gpt-4o-transcribe", "gpt-4o-mini-transcribe"]

    /// Available voice identifiers usable in ``SpeechSynthesisRequest/voice``
    public static let voices = [
        "alloy", "ash", "ballad", "coral", "echo",
        "fable", "onyx", "nova", "sage", "shimmer", "verse"
    ]

    /// Models that support streaming transcription via SSE (`whisper-1` does not)
    public static let streamingTranscriptionModels = ["gpt-4o-transcribe", "gpt-4o-mini-transcribe"]

    // MARK: - TextToSpeech Capability

    public var supportsTextToSpeech: Bool { true }

    public var textToSpeechModels: [String] { Self.ttsModels }

    // MARK: - SpeechToText Capability

    public var supportsSpeechToText: Bool { true }

    public var speechToTextModels: [String] { Self.sttModels }

    // MARK: - Endpoints

    /// The `POST /audio/speech` endpoint
    var speechURL: String { "\(baseURL)/audio/speech" }

    /// The `POST /audio/transcriptions` endpoint
    var transcriptionsURL: String { "\(baseURL)/audio/transcriptions" }

    // MARK: - TextToSpeech Implementation

    public func synthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) async throws -> SpeechSynthesisResponse {
        let body = try JSONEncoder().encode(makeSpeechRequest(request))
        let headers = buildHeaders(apiKey: apiKey, contentType: "application/json")

        let responseData = try await httpClient.post(
            url: speechURL,
            headers: headers,
            body: body
        )

        return SpeechSynthesisResponse(
            audio: responseData,
            format: request.format,
            model: request.model
        )
    }

    public func streamSynthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = try JSONEncoder().encode(makeSpeechRequest(request))
                    let headers = buildHeaders(apiKey: apiKey, contentType: "application/json")

                    let stream = httpClient.streamPost(
                        url: speechURL,
                        headers: headers,
                        body: body
                    )

                    for try await chunk in stream {
                        continuation.yield(SpeechAudioChunk(audio: chunk))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - SpeechToText Implementation

    public func transcribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) async throws -> TranscriptionResponse {
        let boundary = Self.makeBoundary()
        let body = buildMultipartBody(request, boundary: boundary, stream: false)
        let headers = buildHeaders(apiKey: apiKey, contentType: multipartContentType(boundary: boundary))

        let responseData = try await httpClient.post(
            url: transcriptionsURL,
            headers: headers,
            body: body
        )

        let decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: responseData)
        return Self.mapTranscription(decoded)
    }

    public func streamTranscribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) -> AsyncThrowingStream<TranscriptionChunk, Error> {
        AsyncThrowingStream { continuation in
            // Gate: only gpt-4o-transcribe / gpt-4o-mini-transcribe stream over SSE.
            guard Self.streamingTranscriptionModels.contains(request.model) else {
                continuation.finish(throwing: AIError.unsupportedFeature(
                    feature: "streaming-transcription",
                    provider: .openai
                ))
                return
            }

            Task {
                do {
                    let boundary = Self.makeBoundary()
                    let body = buildMultipartBody(request, boundary: boundary, stream: true)
                    let headers = buildHeaders(
                        apiKey: apiKey,
                        contentType: multipartContentType(boundary: boundary),
                        accept: "text/event-stream"
                    )

                    let stream = httpClient.streamPost(
                        url: transcriptionsURL,
                        headers: headers,
                        body: body
                    )

                    for try await chunk in stream {
                        let chunkString = String(data: chunk, encoding: .utf8) ?? ""
                        let lines = chunkString.split(separator: "\n")

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)

                            // Check for stream end signal
                            if trimmed == "data: [DONE]" {
                                continuation.finish()
                                return
                            }

                            // Parse SSE format: "data: {...}"
                            guard trimmed.hasPrefix("data: ") else { continue }

                            let jsonString = String(trimmed.dropFirst(6))
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            let event = try JSONDecoder().decode(
                                OpenAITranscriptionStreamEvent.self,
                                from: jsonData
                            )

                            switch event.type {
                            case "transcript.text.delta":
                                if let delta = event.delta {
                                    continuation.yield(TranscriptionChunk(text: delta, isFinal: false))
                                }
                            case "transcript.text.done":
                                continuation.yield(TranscriptionChunk(text: event.text ?? "", isFinal: true))
                                continuation.finish()
                                return
                            default:
                                continue
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Request Builders (pure, testable)

    /// Build the request headers, always carrying `Authorization: Bearer <apiKey>`.
    ///
    /// - Parameters:
    ///   - apiKey: The OpenAI API key
    ///   - contentType: The `Content-Type` header value
    ///   - accept: Optional `Accept` header value (e.g. `text/event-stream` for streaming)
    /// - Returns: The header tuples
    func buildHeaders(apiKey: String, contentType: String, accept: String? = nil) -> [(String, String)] {
        var headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", contentType)
        ]

        if let orgId = organizationId {
            headers.append(("OpenAI-Organization", orgId))
        }

        if let accept = accept {
            headers.append(("Accept", accept))
        }

        return headers
    }

    /// Map a neutral ``SpeechSynthesisRequest`` to the OpenAI wire request.
    ///
    /// Falls back to ``defaultVoice`` when the request omits a voice; maps ``AudioFormat``
    /// directly to `response_format` (OpenAI's accepted values match the enum's raw values).
    func makeSpeechRequest(_ request: SpeechSynthesisRequest) -> OpenAISpeechRequest {
        OpenAISpeechRequest(
            model: request.model,
            input: request.text,
            voice: request.voice ?? Self.defaultVoice,
            responseFormat: request.format.rawValue,
            speed: request.speed
        )
    }

    /// The `Content-Type` header value for a multipart body with the given boundary.
    func multipartContentType(boundary: String) -> String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// Build a `multipart/form-data` body for the transcriptions endpoint from scratch.
    ///
    /// Parts: `file` (with a filename derived from the request's MIME type and a
    /// `Content-Type`), `model`, optional `language`, `response_format=json`, and
    /// `stream=true` when streaming.
    ///
    /// - Parameters:
    ///   - request: The transcription request
    ///   - boundary: The multipart boundary token
    ///   - stream: Whether to include the `stream=true` field
    /// - Returns: The encoded multipart body
    func buildMultipartBody(_ request: TranscriptionRequest, boundary: String, stream: Bool) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"

        func appendField(name: String, value: String) {
            body.appendString(boundaryPrefix)
            body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }

        // File part (raw audio bytes)
        let mimeType = request.mimeType ?? "application/octet-stream"
        let filename = "audio.\(Self.fileExtension(forMimeType: request.mimeType))"
        body.appendString(boundaryPrefix)
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(request.audio)
        body.appendString("\r\n")

        // Model
        appendField(name: "model", value: request.model)

        // Optional language hint
        if let language = request.language {
            appendField(name: "language", value: language)
        }

        // Response format (keep it simple: JSON)
        appendField(name: "response_format", value: "json")

        // Streaming flag
        if stream {
            appendField(name: "stream", value: "true")
        }

        // Closing boundary
        body.appendString("--\(boundary)--\r\n")

        return body
    }

    // MARK: - Private Helpers

    /// Map the OpenAI transcription wire response to the neutral ``TranscriptionResponse``.
    static func mapTranscription(_ response: OpenAITranscriptionResponse) -> TranscriptionResponse {
        let segments = response.segments?.map { segment in
            TranscriptionSegment(
                text: segment.text,
                startSeconds: segment.start,
                endSeconds: segment.end
            )
        }

        let words = response.words?.map { word in
            TranscriptionWord(
                word: word.word,
                startSeconds: word.start,
                endSeconds: word.end
            )
        }

        return TranscriptionResponse(
            text: response.text,
            segments: segments,
            words: words,
            language: response.language,
            durationSeconds: response.duration
        )
    }

    /// Derive a filename extension from an audio MIME type (best effort).
    static func fileExtension(forMimeType mimeType: String?) -> String {
        switch mimeType {
        case "audio/wav", "audio/x-wav", "audio/wave":
            return "wav"
        case "audio/mpeg", "audio/mp3":
            return "mp3"
        case "audio/mp4", "audio/m4a", "audio/x-m4a":
            return "m4a"
        case "audio/aac":
            return "aac"
        case "audio/flac", "audio/x-flac":
            return "flac"
        case "audio/ogg", "audio/opus":
            return "ogg"
        case "audio/webm":
            return "webm"
        default:
            return "wav"
        }
    }

    /// Generate a unique multipart boundary token.
    private static func makeBoundary() -> String {
        "swiftlyai-boundary-\(UUID().uuidString)"
    }
}

// MARK: - Data Helper

private extension Data {
    /// Append a string as UTF-8 bytes (non-failing).
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
