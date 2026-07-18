import Foundation

/// Cartesia voice provider — low-latency ``TextToSpeech`` (Sonic) plus batch ``SpeechToText``
/// (Ink-Whisper).
///
/// Voice is a **separate capability axis** from chat: `CartesiaVoiceProvider` is *not* a
/// ``ProviderProtocol`` chat provider and is never routed through `sendMessage`.
///
/// ## Authentication
///
/// Every request carries **two** required headers:
/// - `X-API-Key` — a Cartesia API key (prefix `sk_car_`)
/// - `Cartesia-Version` — the global, date-stamped API version (see ``apiVersion``)
///
/// ## Endpoints
/// - One-shot TTS: `POST {baseURL}/tts/bytes` → raw audio bytes (``synthesize(_:apiKey:)``)
/// - Streaming TTS: `POST {baseURL}/tts/sse` → SSE base64 audio chunks (``streamSynthesize(_:apiKey:)``)
/// - Batch STT: `POST {baseURL}/stt` → `multipart/form-data` upload (``transcribe(_:apiKey:)``)
/// - Voices: `GET {baseURL}/voices` (``listVoices(apiKey:)``)
///
/// - Note: Cartesia streaming STT is WebSocket-only, which this HTTP-based provider does not
///   implement; ``streamTranscribe(_:apiKey:)`` uses the protocol default (throws unsupported).
public struct CartesiaVoiceProvider: TextToSpeech, SpeechToText {
    /// The current global Cartesia API version sent as the `Cartesia-Version` header.
    ///
    /// Cartesia versions are date-stamped and global (one value applies to all endpoints).
    /// Verify the current value at <https://docs.cartesia.ai> and override via
    /// ``init(baseURL:apiVersion:)`` if it changes.
    public static let defaultAPIVersion = "2026-03-01"

    /// Text-to-speech (Sonic) model identifiers.
    static let ttsModelIDs = ["sonic-3", "sonic-3.5", "sonic-2", "sonic-turbo"]

    /// Speech-to-text (Ink-Whisper) model identifiers.
    static let sttModelIDs = ["ink-whisper"]

    /// Default output sample rate (Hz) when the request does not specify one.
    static let defaultSampleRate = 44_100

    /// Default MP3 bit rate (bps) for the `mp3` container.
    static let defaultMP3BitRate = 128_000

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let apiVersion: String

    /// Create a Cartesia voice provider using a default HTTP client.
    ///
    /// - Parameters:
    ///   - baseURL: The Cartesia API base URL (default: ``VoiceProviderType/cartesia`` base URL).
    ///   - apiVersion: The `Cartesia-Version` header value (default: ``defaultAPIVersion``).
    public init(
        baseURL: String = VoiceProviderType.cartesia.baseURL,
        apiVersion: String = Self.defaultAPIVersion
    ) {
        self.httpClient = HTTPClientManager()
        self.baseURL = baseURL
        self.apiVersion = apiVersion
    }

    /// Create a Cartesia voice provider with an injected HTTP client.
    ///
    /// - Parameters:
    ///   - httpClient: The HTTP client manager to use.
    ///   - baseURL: The Cartesia API base URL (default: ``VoiceProviderType/cartesia`` base URL).
    ///   - apiVersion: The `Cartesia-Version` header value (default: ``defaultAPIVersion``).
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = VoiceProviderType.cartesia.baseURL,
        apiVersion: String = Self.defaultAPIVersion
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.apiVersion = apiVersion
    }

    // MARK: - Capabilities

    public var supportsTextToSpeech: Bool { true }

    public var textToSpeechModels: [String] { Self.ttsModelIDs }

    public var supportsSpeechToText: Bool { true }

    public var speechToTextModels: [String] { Self.sttModelIDs }

    // MARK: - Text-to-Speech

    public func synthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) async throws -> SpeechSynthesisResponse {
        let body = try makeTTSRequestData(from: request)
        let audio = try await httpClient.post(
            url: "\(baseURL)/tts/bytes",
            headers: jsonHeaders(apiKey: apiKey),
            body: body
        )
        return SpeechSynthesisResponse(audio: audio, format: request.format, model: request.model)
    }

    public func streamSynthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = try makeTTSRequestData(from: request)
                    var headers = jsonHeaders(apiKey: apiKey)
                    headers.append(("Accept", "text/event-stream"))

                    let dataStream = httpClient.streamPost(
                        url: "\(baseURL)/tts/sse",
                        headers: headers,
                        body: body
                    )

                    // Delegate SSE framing / base64 decoding to the testable helper so the
                    // exact same logic drives production and unit tests.
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

    // MARK: - Speech-to-Text

    public func transcribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) async throws -> TranscriptionResponse {
        let boundary = "SwiftlyAIKit-\(UUID().uuidString)"
        let body = makeMultipartBody(from: request, boundary: boundary)

        var headers = authHeaders(apiKey: apiKey)
        headers.append(("Content-Type", "multipart/form-data; boundary=\(boundary)"))

        let data = try await httpClient.post(url: "\(baseURL)/stt", headers: headers, body: body)
        let decoded = try JSONDecoder().decode(CartesiaTranscriptionResponse.self, from: data)
        return mapTranscription(decoded)
    }

    // MARK: - Voices

    /// List the voices available to this API key.
    ///
    /// Cartesia voice ids churn, so they are fetched at runtime rather than hardcoded into
    /// ``VoiceCapabilities``. Returns the first page of results.
    ///
    /// - Parameter apiKey: A Cartesia API key.
    /// - Returns: The available voices.
    public func listVoices(apiKey: String) async throws -> [CartesiaVoice] {
        let data = try await httpClient.get(url: "\(baseURL)/voices", headers: authHeaders(apiKey: apiKey))
        return try JSONDecoder().decode(CartesiaVoicesResponse.self, from: data).data
    }

    // MARK: - Headers

    /// The two headers Cartesia requires on **every** call: `X-API-Key` + `Cartesia-Version`.
    func authHeaders(apiKey: String) -> [(String, String)] {
        [
            ("X-API-Key", apiKey),
            ("Cartesia-Version", apiVersion)
        ]
    }

    /// Auth headers plus a JSON content type, for the TTS endpoints.
    func jsonHeaders(apiKey: String) -> [(String, String)] {
        var headers = authHeaders(apiKey: apiKey)
        headers.append(("Content-Type", "application/json"))
        return headers
    }

    // MARK: - TTS Request Mapping

    /// Map a neutral ``SpeechSynthesisRequest`` onto the Cartesia wire request.
    ///
    /// - Throws: ``AIError/missingParameter(name:)`` when no voice id is supplied, or
    ///   ``AIError/invalidRequest(message:)`` for an audio format Cartesia cannot produce.
    func makeTTSRequest(from request: SpeechSynthesisRequest) throws -> CartesiaTTSRequest {
        guard let voice = request.voice, !voice.isEmpty else {
            throw AIError.missingParameter(name: "voice")
        }
        return CartesiaTTSRequest(
            modelID: request.model,
            transcript: request.text,
            voice: CartesiaVoiceSpecifier(mode: "id", id: voice),
            outputFormat: try Self.outputFormat(for: request.format, sampleRate: request.sampleRate),
            language: nil
        )
    }

    /// JSON-encode the mapped TTS request.
    func makeTTSRequestData(from request: SpeechSynthesisRequest) throws -> Data {
        try JSONEncoder().encode(makeTTSRequest(from: request))
    }

    /// Map a neutral ``AudioFormat`` onto a Cartesia `output_format`.
    ///
    /// Cartesia supports the `raw`, `wav`, and `mp3` containers; `.opus`/`.flac`/`.aac` are
    /// rejected with ``AIError/invalidRequest(message:)``.
    static func outputFormat(for format: AudioFormat, sampleRate: Int?) throws -> CartesiaOutputFormat {
        let rate = sampleRate ?? defaultSampleRate
        switch format {
        case .mp3:
            return CartesiaOutputFormat(container: "mp3", encoding: nil, sampleRate: rate, bitRate: defaultMP3BitRate)
        case .wav:
            return CartesiaOutputFormat(container: "wav", encoding: "pcm_s16le", sampleRate: rate, bitRate: nil)
        case .pcm:
            return CartesiaOutputFormat(container: "raw", encoding: "pcm_s16le", sampleRate: rate, bitRate: nil)
        case .opus, .flac, .aac:
            throw AIError.invalidRequest(
                message: "Cartesia does not support the \(format.rawValue) output format; use .mp3, .wav, or .pcm"
            )
        }
    }

    // MARK: - SSE Stream Parsing

    /// A decoded, actionable Cartesia stream event.
    enum StreamEvent: Equatable {
        /// Decoded audio bytes from a `"chunk"` event.
        case audio(Data)
        /// A terminating `"done"` event.
        case done
        /// A terminating `"error"` event with its message.
        case error(String)
    }

    /// Transform a raw Cartesia SSE byte stream into neutral ``SpeechAudioChunk`` values.
    ///
    /// Bytes are buffered and split on newline boundaries — retaining any partial trailing line —
    /// so an SSE `data:` frame that spans multiple network chunks (common for large base64 audio
    /// payloads on the low-latency path) is reassembled correctly before decoding.
    ///
    /// - Parameter dataStream: Raw SSE data chunks (as produced by
    ///   ``HTTPClientManager/streamPost(url:headers:body:context:)``).
    /// - Returns: A stream of incremental audio chunks, finishing on the `"done"` event or throwing
    ///   ``AIError/streamingError(message:)`` on an `"error"` event.
    func makeAudioChunkStream(
        from dataStream: AsyncThrowingStream<Data, Error>
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let newline = UInt8(0x0A)
                    var buffer = Data()

                    for try await data in dataStream {
                        buffer.append(data)
                        while let newlineIndex = buffer.firstIndex(of: newline) {
                            let lineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
                            buffer.removeSubrange(buffer.startIndex...newlineIndex)
                            if try Self.handle(lineData, continuation: continuation) { return }
                        }
                    }

                    // Process any trailing line that arrived without a closing newline.
                    if try Self.handle(buffer, continuation: continuation) { return }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Parse and act on one SSE line. Returns `true` when the stream is terminated (done/error).
    private static func handle(
        _ lineData: Data,
        continuation: AsyncThrowingStream<SpeechAudioChunk, Error>.Continuation
    ) throws -> Bool {
        guard let event = try parseSSELine(lineData) else { return false }
        switch event {
        case .audio(let audio):
            continuation.yield(SpeechAudioChunk(audio: audio))
            return false
        case .done:
            continuation.finish()
            return true
        case .error(let message):
            continuation.finish(throwing: AIError.streamingError(message: message))
            return true
        }
    }

    /// Decode a single SSE line into a ``StreamEvent``, or `nil` for lines that carry no audio
    /// action (blank frame separators, non-`data:` fields, and ignored event types).
    static func parseSSELine(_ lineData: Data) throws -> StreamEvent? {
        guard !lineData.isEmpty,
              let raw = String(data: lineData, encoding: .utf8) else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.hasPrefix("data:") else { return nil }

        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty || payload == "[DONE]" { return payload == "[DONE]" ? .done : nil }

        guard let jsonData = payload.data(using: .utf8) else { return nil }
        let event = try JSONDecoder().decode(CartesiaSSEEvent.self, from: jsonData)

        switch event.type {
        case "chunk":
            guard let base64 = event.data, let audio = Data(base64Encoded: base64) else {
                throw AIError.decodingError(message: "Cartesia SSE chunk missing/invalid base64 audio")
            }
            return .audio(audio)
        case "done":
            return .done
        case "error":
            return .error(event.error ?? "Cartesia streaming error")
        default:
            // "timestamps", "phoneme_timestamps", and any future informational events.
            return nil
        }
    }

    // MARK: - STT Request/Response Mapping

    /// Build a `multipart/form-data` body for the Ink-Whisper `/stt` upload.
    ///
    /// No multipart helper exists in the SDK, so the body is assembled by hand: a `model` field,
    /// an optional `language` field, a `word` timestamp-granularity field, and the audio `file`
    /// part carrying the raw bytes.
    func makeMultipartBody(from request: TranscriptionRequest, boundary: String) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        field("model", request.model)
        if let language = request.language {
            field("language", language)
        }
        field("timestamp_granularities[]", "word")

        let mimeType = request.mimeType ?? "audio/wav"
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(Self.filename(forMimeType: mimeType))\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(request.audio)
        append("\r\n")
        append("--\(boundary)--\r\n")

        return body
    }

    /// Map the Cartesia transcription response onto the neutral ``TranscriptionResponse``.
    func mapTranscription(_ response: CartesiaTranscriptionResponse) -> TranscriptionResponse {
        let words = response.words?.map {
            TranscriptionWord(word: $0.word, startSeconds: $0.start, endSeconds: $0.end)
        }
        return TranscriptionResponse(
            text: response.text,
            segments: nil,
            words: words,
            language: response.language,
            durationSeconds: response.duration
        )
    }

    /// A best-effort upload filename (Cartesia infers the container from the extension).
    static func filename(forMimeType mimeType: String) -> String {
        switch mimeType {
        case "audio/mpeg", "audio/mp3": return "audio.mp3"
        case "audio/wav", "audio/x-wav": return "audio.wav"
        case "audio/mp4", "audio/m4a": return "audio.m4a"
        case "audio/flac": return "audio.flac"
        case "audio/ogg", "audio/opus": return "audio.ogg"
        case "audio/webm": return "audio.webm"
        default: return "audio.wav"
        }
    }
}
