import Foundation

/// Deepgram voice provider implementation (Nova speech-to-text + Aura-2 text-to-speech)
///
/// Deepgram is a **voice-axis** provider: it conforms to ``SpeechToText`` and ``TextToSpeech``
/// but is *not* a chat ``ProviderProtocol`` and is never routed through
/// ``ProviderProtocol/sendMessage(_:apiKey:)``.
///
/// Deepgram differs from the OpenAI-compatible chat providers in a few important ways:
/// - **`Authorization: Token <key>` authentication.** The scheme is literally `Token`, *not*
///   `Bearer`.
/// - **Raw audio bytes for transcription.** `POST /listen` takes the audio body directly (no
///   multipart form); the model and formatting options ride as query parameters.
/// - **Query-parameter synthesis options.** `POST /speak` carries only `{"text": "..."}` in the
///   body; the voice model, encoding, container, and sample rate are query parameters.
///
/// Live/streaming speech-to-text is intentionally unsupported: Deepgram's live transcription
/// requires a WebSocket connection, which ``HTTPClientManager`` cannot open. Use the one-shot
/// ``transcribe(_:apiKey:)`` instead.
///
/// ## Topics
///
/// ### SpeechToText
/// - ``supportsSpeechToText``
/// - ``speechToTextModels``
/// - ``transcribe(_:apiKey:)``
/// - ``streamTranscribe(_:apiKey:)``
///
/// ### TextToSpeech
/// - ``supportsTextToSpeech``
/// - ``textToSpeechModels``
/// - ``synthesize(_:apiKey:)``
/// - ``streamSynthesize(_:apiKey:)``
public struct DeepgramVoiceProvider: SpeechToText, TextToSpeech {
    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// The Aura-2 voice models offered by this provider.
    ///
    /// These identifiers are usable both as `SpeechSynthesisRequest.model` and as
    /// `SpeechSynthesisRequest.voice`, and are surfaced by ``VoiceCapabilities`` for the
    /// `.deepgram` arm.
    public static let auraVoices = [
        "aura-2-thalia-en",
        "aura-2-andromeda-en",
        "aura-2-apollo-en",
        "aura-2-arcas-en",
        "aura-2-aurora-en",
        "aura-2-luna-en",
        "aura-2-orion-en",
        "aura-2-zeus-en"
    ]

    /// Initialize a Deepgram voice provider with a default HTTPClientManager.
    /// - Parameters:
    ///   - baseURL: Base URL for the Deepgram API (default: `https://api.deepgram.com/v1`)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = VoiceProviderType.deepgram.baseURL,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = HTTPClientManager()
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    /// Initialize a Deepgram voice provider with a custom HTTP client.
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for the Deepgram API (default: `https://api.deepgram.com/v1`)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = VoiceProviderType.deepgram.baseURL,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    // MARK: - Capabilities

    public var supportsSpeechToText: Bool { true }

    public var speechToTextModels: [String] { ["nova-3", "nova-2"] }

    public var supportsTextToSpeech: Bool { true }

    public var textToSpeechModels: [String] { Self.auraVoices }

    // MARK: - Speech-to-Text

    /// Transcribe recorded audio into text with Deepgram Nova (`POST /listen`).
    ///
    /// The raw audio bytes are posted directly as the request body; the model, smart formatting,
    /// punctuation, and optional language hint ride as query parameters.
    ///
    /// - Parameters:
    ///   - request: The transcription request (raw audio, model, optional language + MIME type)
    ///   - apiKey: Deepgram API key (sent as `Authorization: Token <key>`)
    /// - Returns: The transcript, with per-word timing and detected language when available
    /// - Throws: ``AIError/invalidResponse(message:)`` if Deepgram returns no alternatives, or
    ///   ``AIError/decodingError(message:)`` if the response cannot be decoded
    public func transcribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) async throws -> TranscriptionResponse {
        let data = try await httpClient.post(
            url: listenURL(for: request),
            headers: buildListenHeaders(apiKey: apiKey, mimeType: request.mimeType),
            body: request.audio
        )

        let decoded: DeepgramListenResponse
        do {
            decoded = try JSONDecoder().decode(DeepgramListenResponse.self, from: data)
        } catch let error as DecodingError {
            throw AIError.decodingError(message: "Failed to decode Deepgram listen response: \(error)")
        }

        return try transformListenResponse(decoded)
    }

    /// Streaming speech-to-text is unsupported for Deepgram.
    ///
    /// One-shot ``transcribe(_:apiKey:)`` is supported, but live/streaming transcription requires a
    /// WebSocket connection that ``HTTPClientManager`` cannot open — so this finishes the stream
    /// with ``AIError/unsupportedFeature(feature:provider:)``. The `.openai` provider label matches
    /// the voice foundation's documented fallback: ``AIError`` is keyed by the chat
    /// ``ProviderType``, which has no `.deepgram` case.
    public func streamTranscribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) -> AsyncThrowingStream<TranscriptionChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.unsupportedFeature(
                feature: "streaming speech-to-text (Deepgram live transcription requires a WebSocket "
                    + "connection, which HTTPClientManager does not support; use one-shot transcribe instead)",
                provider: .openai
            ))
        }
    }

    // MARK: - Text-to-Speech

    /// Synthesize spoken audio from text with Deepgram Aura-2 (`POST /speak`).
    ///
    /// The audio format, container, and sample rate are encoded onto the request URL; the body is
    /// a minimal `{"text": "..."}`. The returned audio is the raw encoded bytes.
    ///
    /// - Parameters:
    ///   - request: The speech synthesis request (text, model, format, optional sample rate)
    ///   - apiKey: Deepgram API key (sent as `Authorization: Token <key>`)
    /// - Returns: The synthesized audio in the requested format
    public func synthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) async throws -> SpeechSynthesisResponse {
        let audio = try await httpClient.post(
            url: speakURL(for: request),
            headers: buildSpeakHeaders(apiKey: apiKey),
            body: buildSpeakBody(from: request)
        )
        return makeSynthesisResponse(audio: audio, request: request)
    }

    /// Stream synthesized audio from text with Deepgram Aura-2 (`POST /speak`).
    ///
    /// Streams the audio bytes as they arrive, wrapping each network chunk in a
    /// ``SpeechAudioChunk``.
    ///
    /// - Parameters:
    ///   - request: The speech synthesis request
    ///   - apiKey: Deepgram API key (sent as `Authorization: Token <key>`)
    /// - Returns: An `AsyncThrowingStream` of incremental audio chunks
    public func streamSynthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = try buildSpeakBody(from: request)

                    let dataStream = httpClient.streamPost(
                        url: speakURL(for: request),
                        headers: buildSpeakHeaders(apiKey: apiKey),
                        body: body
                    )

                    // Delegate chunk wrapping to the testable helper so the same logic drives
                    // production and unit tests.
                    for try await chunk in makeAudioChunkStream(from: dataStream) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - URL Building

    /// Build the `POST /listen` URL for a transcription request.
    ///
    /// Always requests smart formatting and punctuation; appends a URL-encoded `language` hint when
    /// one is supplied (otherwise Deepgram auto-detects).
    func listenURL(for request: TranscriptionRequest) -> String {
        var url = "\(baseURL)/listen?model=\(request.model)&smart_format=true&punctuate=true"
        if let language = request.language {
            let encoded = language.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? language
            url += "&language=\(encoded)"
        }
        return url
    }

    /// Build the `POST /speak` URL for a synthesis request.
    ///
    /// Maps the neutral ``AudioFormat`` to Deepgram's `encoding` query parameter, adds
    /// `container=wav` for WAV output, and appends `sample_rate` (defaulting to 24000 Hz for
    /// linear16 encodings, or when the caller sets one explicitly for other formats).
    func speakURL(for request: SpeechSynthesisRequest) -> String {
        let encoding = Self.encoding(for: request.format)
        var url = "\(baseURL)/speak?model=\(request.model)&encoding=\(encoding)"

        if request.format == .wav {
            url += "&container=wav"
        }

        if encoding == "linear16" {
            url += "&sample_rate=\(request.sampleRate ?? 24000)"
        } else if let sampleRate = request.sampleRate {
            url += "&sample_rate=\(sampleRate)"
        }

        return url
    }

    /// Map a neutral ``AudioFormat`` to Deepgram's `encoding` query value.
    private static func encoding(for format: AudioFormat) -> String {
        switch format {
        case .mp3: return "mp3"
        case .opus: return "opus"
        case .flac: return "flac"
        case .aac: return "aac"
        case .pcm, .wav: return "linear16"
        }
    }

    // MARK: - Header Building

    /// Build the HTTP headers for a `POST /listen` request.
    ///
    /// Deepgram authenticates with `Authorization: Token <key>` — the scheme is literally `Token`,
    /// *not* `Bearer`. The `Content-Type` reflects the audio's MIME type (or a generic
    /// `application/octet-stream` when unknown).
    func buildListenHeaders(apiKey: String, mimeType: String?) -> [(String, String)] {
        [
            ("Authorization", "Token \(apiKey)"),
            ("Content-Type", mimeType ?? "application/octet-stream")
        ]
    }

    /// Build the HTTP headers for a `POST /speak` request.
    ///
    /// Deepgram authenticates with `Authorization: Token <key>` — the scheme is literally `Token`,
    /// *not* `Bearer`. The JSON body sets `Content-Type: application/json`.
    func buildSpeakHeaders(apiKey: String) -> [(String, String)] {
        [
            ("Authorization", "Token \(apiKey)"),
            ("Content-Type", "application/json")
        ]
    }

    // MARK: - Body Building

    /// Encode the `{"text": "..."}` body for a `POST /speak` request.
    func buildSpeakBody(from request: SpeechSynthesisRequest) throws -> Data {
        try JSONEncoder().encode(DeepgramSpeakRequest(text: request.text))
    }

    // MARK: - Response Transformation

    /// Transform a decoded ``DeepgramListenResponse`` into a neutral ``TranscriptionResponse``.
    ///
    /// Pulls the best alternative from the first channel; maps per-word timing (preferring the
    /// punctuated display form), the detected language, and the audio duration.
    ///
    /// - Throws: ``AIError/invalidResponse(message:)`` when the response carries no alternative.
    func transformListenResponse(_ response: DeepgramListenResponse) throws -> TranscriptionResponse {
        let channel = response.results.channels.first
        guard let alternative = channel?.alternatives.first else {
            throw AIError.invalidResponse(message: "Deepgram returned no transcription alternatives")
        }

        let words = alternative.words?.map { word in
            TranscriptionWord(
                word: word.punctuatedWord ?? word.word,
                startSeconds: word.start,
                endSeconds: word.end
            )
        }

        return TranscriptionResponse(
            text: alternative.transcript,
            segments: nil,
            words: words,
            language: channel?.detectedLanguage,
            durationSeconds: response.metadata?.duration
        )
    }

    /// Wrap raw synthesized audio bytes in a neutral ``SpeechSynthesisResponse``.
    func makeSynthesisResponse(audio: Data, request: SpeechSynthesisRequest) -> SpeechSynthesisResponse {
        SpeechSynthesisResponse(audio: audio, format: request.format, model: request.model)
    }

    /// Transform a raw audio byte stream into a stream of neutral ``SpeechAudioChunk`` values.
    ///
    /// Each incoming `Data` chunk (as produced by
    /// ``HTTPClientManager/streamPost(url:headers:body:context:)``) is wrapped verbatim; errors are
    /// forwarded and the stream finishes when the source completes.
    func makeAudioChunkStream(
        from dataStream: AsyncThrowingStream<Data, Error>
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await data in dataStream {
                        continuation.yield(SpeechAudioChunk(audio: data))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
