import Foundation

/// ElevenLabs voice provider (text-to-speech + speech-to-text)
///
/// Implements the voice axis for ElevenLabs, conforming to both ``TextToSpeech`` (via the
/// `/text-to-speech/{voice_id}` endpoints) and ``SpeechToText`` (via the Scribe
/// `/speech-to-text` endpoint), plus two extra helpers — ``listVoices(apiKey:)`` and
/// ``cloneVoice(name:files:description:apiKey:fileMimeType:)`` — that fall outside the neutral
/// voice protocols.
///
/// ElevenLabs diverges from the OpenAI-compatible providers in three notable ways:
/// - **Auth header is `xi-api-key`**, not `Authorization: Bearer`.
/// - **`output_format` is a query parameter** on the TTS endpoints (not a body field).
/// - **TTS responses are raw audio bytes** (no JSON envelope); Scribe STT is JSON.
public struct ElevenLabsVoiceProvider: TextToSpeech, SpeechToText {
    private let httpClient: HTTPClientManager
    let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Default premade "Rachel" voice used when a request does not specify a voice.
    static let defaultVoiceID = "21m00Tcm4TlvDq8ikWAM"

    /// Initialize the ElevenLabs voice provider with a default HTTPClientManager.
    /// - Parameters:
    ///   - baseURL: Base URL for the ElevenLabs API (default: `https://api.elevenlabs.io/v1`)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = VoiceProviderType.elevenLabs.baseURL,
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

    /// Initialize the ElevenLabs voice provider with a custom HTTP client.
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for the ElevenLabs API (default: `https://api.elevenlabs.io/v1`)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = VoiceProviderType.elevenLabs.baseURL,
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

    public var supportsTextToSpeech: Bool { true }

    public var textToSpeechModels: [String] { VoiceCapabilities.ttsModels(for: .elevenLabs) }

    public var supportsSpeechToText: Bool { true }

    public var speechToTextModels: [String] { VoiceCapabilities.sttModels(for: .elevenLabs) }

    // MARK: - Endpoints

    /// Scribe speech-to-text endpoint URL for the configured base URL.
    var sttURL: String { "\(baseURL)/speech-to-text" }

    /// Text-to-speech endpoint URL.
    ///
    /// - Parameters:
    ///   - voiceID: The resolved voice identifier.
    ///   - outputFormat: The ElevenLabs `output_format` token (a **query** parameter).
    ///   - streaming: When `true`, targets the `/stream` variant.
    /// - Returns: The fully-formed URL string.
    func ttsURL(voiceID: String, outputFormat: String, streaming: Bool) -> String {
        let suffix = streaming ? "/stream" : ""
        return "\(baseURL)/text-to-speech/\(voiceID)\(suffix)?output_format=\(outputFormat)"
    }

    // MARK: - TextToSpeech

    public func synthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) async throws -> SpeechSynthesisResponse {
        let format = try outputFormat(for: request.format)
        let voiceID = resolveVoiceID(request.voice)
        let url = ttsURL(voiceID: voiceID, outputFormat: format, streaming: false)
        let body = try buildSpeechRequestBody(from: request)

        let audio = try await httpClient.post(
            url: url,
            headers: buildHeaders(apiKey: apiKey),
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
                    let format = try outputFormat(for: request.format)
                    let voiceID = resolveVoiceID(request.voice)
                    let url = ttsURL(voiceID: voiceID, outputFormat: format, streaming: true)
                    let body = try buildSpeechRequestBody(from: request)

                    let dataStream = httpClient.streamPost(
                        url: url,
                        headers: buildHeaders(apiKey: apiKey),
                        body: body
                    )

                    for try await chunk in dataStream {
                        continuation.yield(SpeechAudioChunk(audio: chunk))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - SpeechToText

    public func transcribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) async throws -> TranscriptionResponse {
        let boundary = "swiftlyai-\(UUID().uuidString)"

        var fields: [(name: String, value: String)] = [("model_id", request.model)]
        if let language = request.language {
            fields.append((name: "language_code", value: language))
        }

        let mimeType = request.mimeType ?? "audio/mpeg"
        let files = [MultipartFile(
            name: "file",
            filename: "audio.\(fileExtension(forMimeType: mimeType))",
            mimeType: mimeType,
            data: request.audio
        )]

        let body = buildMultipartBody(fields: fields, files: files, boundary: boundary)
        let headers = buildHeaders(
            apiKey: apiKey,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        let responseData = try await httpClient.post(url: sttURL, headers: headers, body: body)
        let decoded = try JSONDecoder().decode(ElevenLabsTranscriptionResponse.self, from: responseData)
        return mapTranscription(decoded)
    }

    public func streamTranscribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) -> AsyncThrowingStream<TranscriptionChunk, Error> {
        // Scribe REST is batch (no true streaming): transcribe once, then emit a single final chunk.
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await transcribe(request, apiKey: apiKey)
                    continuation.yield(TranscriptionChunk(text: response.text, isFinal: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - ElevenLabs-Specific Methods

    /// List the account's available voices.
    ///
    /// - Parameter apiKey: The ElevenLabs API key.
    /// - Returns: The account's voices as neutral ``ElevenLabsVoiceInfo`` values.
    public func listVoices(apiKey: String) async throws -> [ElevenLabsVoiceInfo] {
        let responseData = try await httpClient.get(
            url: "\(baseURL)/voices",
            headers: buildHeaders(apiKey: apiKey)
        )
        let decoded = try JSONDecoder().decode(ElevenLabsVoicesResponse.self, from: responseData)
        return decoded.voices.map {
            ElevenLabsVoiceInfo(id: $0.voiceID, name: $0.name, category: $0.category)
        }
    }

    /// Create a cloned voice from one or more audio samples.
    ///
    /// - Parameters:
    ///   - name: The name for the new voice.
    ///   - files: Audio sample bytes (one multipart `files` part per sample).
    ///   - description: Optional description for the new voice.
    ///   - apiKey: The ElevenLabs API key.
    ///   - fileMimeType: MIME type of the sample audio (default: `audio/mpeg`).
    /// - Returns: The identifier of the newly created voice.
    public func cloneVoice(
        name: String,
        files: [Data],
        description: String? = nil,
        apiKey: String,
        fileMimeType: String = "audio/mpeg"
    ) async throws -> String {
        let boundary = "swiftlyai-\(UUID().uuidString)"

        var fields: [(name: String, value: String)] = [("name", name)]
        if let description = description {
            fields.append((name: "description", value: description))
        }

        let ext = fileExtension(forMimeType: fileMimeType)
        let fileParts = files.enumerated().map { index, data in
            MultipartFile(name: "files", filename: "sample_\(index).\(ext)", mimeType: fileMimeType, data: data)
        }

        let body = buildMultipartBody(fields: fields, files: fileParts, boundary: boundary)
        let headers = buildHeaders(
            apiKey: apiKey,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        let responseData = try await httpClient.post(
            url: "\(baseURL)/voices/add",
            headers: headers,
            body: body
        )
        let decoded = try JSONDecoder().decode(ElevenLabsAddVoiceResponse.self, from: responseData)
        return decoded.voiceID
    }

    // MARK: - Request Building (internal for testability)

    /// Build the HTTP headers for an ElevenLabs request.
    ///
    /// ElevenLabs authenticates with an `xi-api-key` header — **not** `Authorization: Bearer`.
    ///
    /// - Parameters:
    ///   - apiKey: The ElevenLabs API key.
    ///   - contentType: The `Content-Type` header value (default: `application/json`).
    /// - Returns: Header key/value tuples.
    func buildHeaders(apiKey: String, contentType: String = "application/json") -> [(String, String)] {
        [("xi-api-key", apiKey), ("Content-Type", contentType)]
    }

    /// Resolve the voice ID for a request, falling back to the default premade voice.
    ///
    /// - Parameter voice: The requested voice identifier, if any.
    /// - Returns: The resolved voice identifier.
    func resolveVoiceID(_ voice: String?) -> String {
        voice ?? Self.defaultVoiceID
    }

    /// Map a neutral ``AudioFormat`` to an ElevenLabs `output_format` token.
    ///
    /// - Parameter format: The requested audio format.
    /// - Returns: The ElevenLabs `output_format` query value.
    /// - Throws: `AIError.invalidRequest` for `.flac`/`.aac`, which ElevenLabs does not support.
    func outputFormat(for format: AudioFormat) throws -> String {
        switch format {
        case .mp3: return "mp3_44100_128"
        case .wav: return "wav_44100"
        case .pcm: return "pcm_44100"
        case .opus: return "opus_48000_128"
        case .flac, .aac:
            throw AIError.invalidRequest(
                message: "ElevenLabs does not support the \(format.rawValue) output format"
            )
        }
    }

    /// Build the JSON body for a text-to-speech request.
    ///
    /// `voice_settings` is included only when the neutral request carries a `speed`.
    ///
    /// - Parameter request: The neutral synthesis request.
    /// - Returns: The encoded JSON body.
    func buildSpeechRequestBody(from request: SpeechSynthesisRequest) throws -> Data {
        let voiceSettings = request.speed.map { ElevenLabsVoiceSettings(speed: $0) }
        let payload = ElevenLabsSpeechRequest(
            text: request.text,
            modelID: request.model,
            voiceSettings: voiceSettings
        )
        return try JSONEncoder().encode(payload)
    }

    /// Map a decoded Scribe response into a neutral ``TranscriptionResponse``.
    ///
    /// Only `"word"`-typed tokens with both a `start` and `end` are surfaced as
    /// ``TranscriptionWord`` values; spacing / audio-event tokens (and any token missing
    /// timing) are dropped defensively.
    ///
    /// - Parameter response: The decoded Scribe response.
    /// - Returns: The neutral transcription response.
    func mapTranscription(_ response: ElevenLabsTranscriptionResponse) -> TranscriptionResponse {
        let words: [TranscriptionWord]? = response.words?.compactMap { word in
            guard let start = word.start, let end = word.end else { return nil }
            if let type = word.type, type != "word" { return nil }
            return TranscriptionWord(word: word.text, startSeconds: start, endSeconds: end)
        }

        return TranscriptionResponse(
            text: response.text,
            segments: nil,
            words: words,
            language: response.languageCode,
            durationSeconds: nil
        )
    }

    /// A single file part for a `multipart/form-data` body.
    struct MultipartFile {
        let name: String
        let filename: String
        let mimeType: String
        let data: Data
    }

    /// Build a `multipart/form-data` body from text fields and file parts.
    ///
    /// The SDK's ``HTTPClientManager`` has no multipart helper, so the provider assembles the
    /// body itself. The caller must reuse the same `boundary` in the `Content-Type` header.
    ///
    /// - Parameters:
    ///   - fields: Text form fields as `(name, value)` pairs.
    ///   - files: File parts.
    ///   - boundary: The multipart boundary token.
    /// - Returns: The encoded multipart body.
    func buildMultipartBody(
        fields: [(name: String, value: String)],
        files: [MultipartFile],
        boundary: String
    ) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        for field in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            append("\(field.value)\r\n")
        }

        for file in files {
            append("--\(boundary)\r\n")
            append(
                "Content-Disposition: form-data; name=\"\(file.name)\"; "
                + "filename=\"\(file.filename)\"\r\n"
            )
            append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }

        append("--\(boundary)--\r\n")
        return body
    }

    // MARK: - Private Helpers

    /// Best-effort file extension for a given audio MIME type (used for multipart filenames).
    private func fileExtension(forMimeType mimeType: String) -> String {
        switch mimeType {
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/wav", "audio/x-wav": return "wav"
        case "audio/L16", "audio/pcm": return "pcm"
        case "audio/opus", "audio/ogg": return "opus"
        case "audio/flac": return "flac"
        case "audio/aac": return "aac"
        case "audio/mp4", "audio/m4a", "audio/x-m4a": return "m4a"
        case "audio/webm": return "webm"
        default: return "mp3"
        }
    }
}
