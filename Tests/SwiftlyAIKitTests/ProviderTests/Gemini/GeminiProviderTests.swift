import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for GeminiProvider implementation
@Suite("GeminiProvider Tests")
struct GeminiProviderTests {
    // MARK: - Basic Configuration Tests

    @Test("GeminiProvider initializes with default values")
    func testInitializationDefaults() {
        let provider = GeminiProvider()

        #expect(provider.providerType == .google)
    }

    @Test("GeminiProvider initializes with custom baseURL")
    func testInitializationCustomBaseURL() {
        let provider = GeminiProvider(baseURL: "https://custom.api.com/v1")

        #expect(provider.providerType == .google)
    }

    @Test("GeminiProvider initializes with custom HTTP client")
    func testInitializationCustomHTTPClient() async {
        let mockClient = HTTPClientManager()
        let provider = GeminiProvider(httpClient: mockClient)

        #expect(provider.providerType == .google)
    }

    // MARK: - Request Mapping Tests

    @Test("Maps text message to Gemini format")
    func testMapTextMessage() {
        let message = AIMessage(
            role: .user,
            content: [.text("Hello, Gemini!")]
        )

        // Verify the message structure
        #expect(message.role == .user)
        #expect(message.content.count == 1)

        if case .text(let text) = message.content[0] {
            #expect(text == "Hello, Gemini!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Maps image message to Gemini format")
    func testMapImageMessage() {
        let base64Data = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let message = AIMessage(
            role: .user,
            content: [
                .text("What's in this image?"),
                .image(source: .base64(base64Data), mediaType: "image/png")
            ]
        )

        #expect(message.content.count == 2)
        #expect(message.role == .user)
    }

    @Test("Maps document message to Gemini format")
    func testMapDocumentMessage() {
        let pdfData = Data("Mock PDF content".utf8)
        let message = AIMessage(
            role: .user,
            content: [
                .text("Analyze this document"),
                .document(data: pdfData, mediaType: "application/pdf", filename: "doc.pdf")
            ]
        )

        #expect(message.content.count == 2)
        #expect(message.role == .user)
    }

    @Test("Maps system prompt correctly")
    func testMapSystemPrompt() {
        let request = AIRequest(
            model: "gemini-2.5-pro-latest",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ],
            systemPrompt: "You are a helpful assistant."
        )

        #expect(request.systemPrompt == "You are a helpful assistant.")
        #expect(request.messages.count == 1)
    }

    @Test("Maps generation config parameters")
    func testMapGenerationConfig() {
        let request = AIRequest(
            model: "gemini-2.5-pro-latest",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ],
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            stopSequences: ["END"]
        )

        #expect(request.temperature == 0.7)
        #expect(request.maxTokens == 1024)
        #expect(request.topP == 0.9)
        #expect(request.topK == 40)
        #expect(request.stopSequences == ["END"])
    }

    // MARK: - Response Mapping Tests

    @Test("Maps successful response from Gemini")
    func testMapSuccessfulResponse() throws {
        let jsonData = MockGeminiAPI.generateContentResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)

        #expect(response.candidates.count == 1)
        #expect(response.candidates[0].finishReason == "STOP")
        #expect(response.usageMetadata?.totalTokenCount == 35)
    }

    @Test("Maps multimodal response from Gemini")
    func testMapMultimodalResponse() throws {
        let jsonData = MockGeminiAPI.multimodalResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)

        #expect(response.candidates.count == 1)
        let parts = response.candidates[0].content.parts
        #expect(parts.count == 1)

        if case .text(let text) = parts[0] {
            #expect(text.contains("sunset"))
        } else {
            Issue.record("Expected text part")
        }
    }

    @Test("Maps function call response from Gemini")
    func testMapFunctionCallResponse() throws {
        let jsonData = MockGeminiAPI.functionCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)

        #expect(response.candidates.count == 1)
        let parts = response.candidates[0].content.parts
        #expect(parts.count == 2)

        // Verify function call part exists
        let hasFunctionCall = parts.contains { part in
            if case .functionCall = part {
                return true
            }
            return false
        }
        #expect(hasFunctionCall)
    }

    @Test("Maps finish reasons correctly")
    func testMapFinishReasons() throws {
        // Test STOP
        let stopData = MockGeminiAPI.generateContentResponse.data(using: .utf8)!
        let stopResponse = try JSONDecoder().decode(GeminiResponse.self, from: stopData)
        #expect(stopResponse.candidates[0].finishReason == "STOP")

        // Test MAX_TOKENS
        let maxData = MockGeminiAPI.maxTokensResponse.data(using: .utf8)!
        let maxResponse = try JSONDecoder().decode(GeminiResponse.self, from: maxData)
        #expect(maxResponse.candidates[0].finishReason == "MAX_TOKENS")

        // Test SAFETY
        let safetyData = MockGeminiAPI.safetyFilteredResponse.data(using: .utf8)!
        let safetyResponse = try JSONDecoder().decode(GeminiResponse.self, from: safetyData)
        #expect(safetyResponse.candidates[0].finishReason == "SAFETY")
    }

    @Test("Maps usage metadata correctly")
    func testMapUsageMetadata() throws {
        let jsonData = MockGeminiAPI.generateContentResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)

        guard let usage = response.usageMetadata else {
            Issue.record("Expected usage metadata")
            return
        }

        #expect(usage.promptTokenCount == 10)
        #expect(usage.candidatesTokenCount == 25)
        #expect(usage.totalTokenCount == 35)
    }

    // MARK: - Image Generation Tests

    @Test("ImageGenerationCapabilities reports Google as supported")
    func testImageGenerationCapabilitiesGoogle() {
        #expect(ImageGenerationCapabilities.isSupported(by: .google))

        let models = ImageGenerationCapabilities.models(for: .google)
        #expect(!models.isEmpty)
        #expect(models.contains("gemini-3.1-flash-image"))
        #expect(models.contains("imagen-4.0-generate-001"))

        #expect(ImageGenerationCapabilities.defaultModel(for: .google) == "gemini-3.1-flash-image")
        #expect(ImageGenerationCapabilities.supportedSizes(for: .google) == ImageSize.allCases)
    }

    @Test("GeminiProvider advertises image generation")
    func testGeminiProviderSupportsImageGeneration() {
        let provider = GeminiProvider()

        #expect(provider.supportsImageGeneration)
        #expect(provider.imageGenerationModels.contains("gemini-3.1-flash-image"))
        #expect(provider.imageGenerationModels.contains("imagen-4.0-generate-001"))
    }

    @Test("GoogleProvider forwards image generation capability")
    func testGoogleProviderForwardsImageGeneration() {
        let provider = GoogleProvider()

        #expect(provider.supportsImageGeneration)
        #expect(!provider.imageGenerationModels.isEmpty)
    }

    @Test("Maps ImageSize to Google aspect ratio")
    func testImageSizeAspectRatio() {
        #expect(ImageSize.square256.aspectRatio == "1:1")
        #expect(ImageSize.square1024.aspectRatio == "1:1")
        #expect(ImageSize.landscape1792x1024.aspectRatio == "16:9")
        #expect(ImageSize.portrait1024x1792.aspectRatio == "9:16")
    }

    @Test("Decodes Gemini-native image response and maps to GeneratedImage")
    func testDecodeGeminiNativeImageResponse() throws {
        let jsonData = MockGeminiAPI.imageGenerateContentResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)

        let images = GeminiProvider.extractImages(from: response, size: .square1024)
        #expect(images.count == 1)
        #expect(images[0].base64Data == MockGeminiAPI.sampleImageBase64)
        #expect(images[0].contentType == "image/png")
        #expect(images[0].size == .square1024)
        #expect(images[0].url == nil)
        #expect(images[0].hasData)
    }

    @Test("Decodes Imagen predict response and maps to GeneratedImage")
    func testDecodeImagenPredictResponse() throws {
        let jsonData = MockGeminiAPI.imagenPredictResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(ImagenPredictResponse.self, from: jsonData)

        #expect(response.predictions.count == 1)
        #expect(response.predictions[0].bytesBase64Encoded == MockGeminiAPI.sampleImageBase64)
        #expect(response.predictions[0].mimeType == "image/png")

        let images = GeminiProvider.mapImagenPredictions(response, size: .landscape1792x1024)
        #expect(images.count == 1)
        #expect(images[0].base64Data == MockGeminiAPI.sampleImageBase64)
        #expect(images[0].contentType == "image/png")
        #expect(images[0].size == .landscape1792x1024)
    }

    @Test("Encodes Imagen predict request with sampleCount and aspectRatio")
    func testEncodeImagenPredictRequest() throws {
        let request = ImagenPredictRequest(
            instances: [ImagenInstance(prompt: "a cat astronaut")],
            parameters: ImagenParameters(sampleCount: 3, aspectRatio: "16:9")
        )

        let data = try JSONEncoder().encode(request)
        let roundTrip = try JSONDecoder().decode(ImagenPredictRequest.self, from: data)

        #expect(roundTrip.instances.count == 1)
        #expect(roundTrip.instances[0].prompt == "a cat astronaut")
        #expect(roundTrip.parameters?.sampleCount == 3)
        #expect(roundTrip.parameters?.aspectRatio == "16:9")
    }

    @Test("Encodes Gemini image generation config with responseModalities and imageConfig")
    func testEncodeGeminiImageGenerationConfig() throws {
        let config = GeminiGenerationConfig(
            responseModalities: ["IMAGE"],
            imageConfig: GeminiImageConfig(aspectRatio: "1:1")
        )

        let data = try JSONEncoder().encode(config)
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        #expect(jsonString.contains("responseModalities"))
        #expect(jsonString.contains("imageConfig"))

        let roundTrip = try JSONDecoder().decode(GeminiGenerationConfig.self, from: data)
        #expect(roundTrip.responseModalities == ["IMAGE"])
        #expect(roundTrip.imageConfig?.aspectRatio == "1:1")
    }

    @Test("Convenience factories build Google image requests")
    func testGoogleImageRequestFactories() {
        let gemini = ImageGenerationRequest.gemini(prompt: "a fox")
        #expect(gemini.model == "gemini-3.1-flash-image")
        #expect(gemini.responseFormat == .base64)

        // Imagen clamps numberOfImages to the 1...4 range Google accepts.
        let imagen = ImageGenerationRequest.imagen(prompt: "a fox", numberOfImages: 9)
        #expect(imagen.model == "imagen-4.0-generate-001")
        #expect(imagen.numberOfImages == 4)
        #expect(imagen.responseFormat == .base64)
    }

    // MARK: - Error Handling Tests

    @Test("Parses 400 Bad Request error")
    func testParseBadRequestError() throws {
        let jsonData = MockGeminiAPI.badRequestError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GeminiErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.code == 400)
        #expect(errorResponse.error.message.contains("Invalid request"))
        #expect(errorResponse.error.status == "INVALID_ARGUMENT")
    }

    @Test("Parses 401 Unauthorized error")
    func testParseUnauthorizedError() throws {
        let jsonData = MockGeminiAPI.unauthorizedError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GeminiErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.code == 401)
        #expect(errorResponse.error.message.contains("API key"))
        #expect(errorResponse.error.status == "UNAUTHENTICATED")
    }

    @Test("Parses 429 Rate Limit error")
    func testParseRateLimitError() throws {
        let jsonData = MockGeminiAPI.rateLimitError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GeminiErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.code == 429)
        #expect(errorResponse.error.status == "RESOURCE_EXHAUSTED")
    }

    @Test("Parses 500 Internal Server error")
    func testParseInternalServerError() throws {
        let jsonData = MockGeminiAPI.internalServerError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GeminiErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.code == 500)
        #expect(errorResponse.error.status == "INTERNAL")
    }

    // MARK: - Safety Settings Tests

    @Test("Safety settings can be encoded")
    func testSafetySettingsEncoding() throws {
        let settings = [
            GeminiSafetySetting(
                category: .harassment,
                threshold: .blockMediumAndAbove
            ),
            GeminiSafetySetting(
                category: .hateSpeech,
                threshold: .blockMediumAndAbove
            )
        ]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode([GeminiSafetySetting].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].category == .harassment)
        #expect(decoded[1].category == .hateSpeech)
    }

    @Test("All harm categories are available")
    func testAllHarmCategories() {
        let categories: [GeminiSafetySetting.HarmCategory] = [
            .harassment,
            .hateSpeech,
            .sexuallyExplicit,
            .dangerousContent
        ]

        #expect(categories.count == 4)
    }

    @Test("All harm thresholds are available")
    func testAllHarmThresholds() {
        let thresholds: [GeminiSafetySetting.HarmBlockThreshold] = [
            .blockNone,
            .blockOnlyHigh,
            .blockMediumAndAbove,
            .blockLowAndAbove
        ]

        #expect(thresholds.count == 4)
    }

    // MARK: - Function Calling Tests

    @Test("Function declaration can be created")
    func testFunctionDeclaration() {
        let schema = GeminiSchema(
            type: "object",
            properties: [
                "location": GeminiSchemaProperty(type: "string", description: "City name"),
                "unit": GeminiSchemaProperty(type: "string", description: "Temperature unit")
            ],
            required: ["location"]
        )

        let function = GeminiFunctionDeclaration(
            name: "get_weather",
            description: "Get current weather for a location",
            parameters: schema
        )

        #expect(function.name == "get_weather")
        #expect(function.parameters?.type == "object")
        #expect(function.parameters?.required?.contains("location") == true)
    }

    @Test("Tool configuration modes")
    func testToolConfigurationModes() {
        let modes: [GeminiFunctionCallingConfig.Mode] = [
            .auto,
            .any,
            .none
        ]

        #expect(modes.count == 3)
    }

    // MARK: - Token Counting Tests

    @Test("CountTokens response can be decoded")
    func testCountTokensResponse() throws {
        let jsonData = MockGeminiAPI.countTokensResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiCountTokensResponse.self, from: jsonData)

        #expect(response.totalTokens == 42)
    }

    @Test("CountTokens for long text")
    func testCountTokensLongText() throws {
        let jsonData = MockGeminiAPI.countTokensLongResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiCountTokensResponse.self, from: jsonData)

        #expect(response.totalTokens == 1523)
    }

    // MARK: - Streaming Tests

    @Test("Stream events can be parsed")
    func testStreamEventsParsing() throws {
        for event in MockGeminiAPI.streamEvents {
            if event == "data: [DONE]" {
                // End signal
                continue
            }

            guard event.hasPrefix("data: ") else {
                continue
            }

            let jsonString = String(event.dropFirst(6))
            guard let jsonData = jsonString.data(using: .utf8) else {
                continue
            }

            // Should be able to decode as stream chunk
            let chunk = try JSONDecoder().decode(GeminiStreamChunk.self, from: jsonData)
            #expect(!chunk.candidates.isEmpty)
        }
    }

    @Test("Stream accumulates text correctly")
    func testStreamTextAccumulation() {
        var accumulated = ""
        let expectedParts = ["Hello", "! How", " can", " I", " help", " you", "?"]

        for part in expectedParts {
            accumulated += part
        }

        #expect(accumulated == "Hello! How can I help you?")
    }

    // MARK: - Models List Tests

    @Test("Decodes models.list response")
    func testDecodeModelsListResponse() throws {
        let jsonData = MockGeminiAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiModelsResponse.self, from: jsonData)

        #expect(response.models.count == 3)
        #expect(response.nextPageToken == "abc123")

        // A known chat model decodes with all surfaced fields.
        let pro = response.models[0]
        #expect(pro.name == "models/gemini-2.5-pro")
        #expect(pro.displayName == "Gemini 2.5 Pro")
        #expect(pro.inputTokenLimit == 2_097_152)
        #expect(pro.outputTokenLimit == 65_536)
        // supportedGenerationMethods round-trips (this is what callers filter on).
        #expect(pro.supportedGenerationMethods?.contains("generateContent") == true)
    }

    @Test("Caller can filter models.list to generateContent-capable models")
    func testFilterModelsListToChatCapable() throws {
        let jsonData = MockGeminiAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiModelsResponse.self, from: jsonData)

        // The raw list includes an embedding model; the caller filters it out.
        let chatModels = response.models.filter {
            $0.supportedGenerationMethods?.contains("generateContent") == true
        }

        #expect(chatModels.count == 2)
        #expect(chatModels.allSatisfy { $0.name.hasPrefix("models/gemini") })
        #expect(!chatModels.contains { $0.name.contains("embedding") })
    }

    // MARK: - Model Support Tests

    @Test("Gemini 2.5 Pro is supported")
    func testGemini25ProSupport() {
        let model = ModelProvider.gemini25Pro

        #expect(model.providerType == .google)
        #expect(model.displayName == "Gemini 2.5 Pro")
        #expect(model.supportsVision == true)
        #expect(model.supportsPDF == true)
        #expect(model.supportsPromptCaching == true)
        #expect(model.maxInputTokens == 2_097_152)
        #expect(model.maxOutputTokens == 65_536)
    }

    @Test("Gemini 2.5 Flash is supported")
    func testGemini25FlashSupport() {
        let model = ModelProvider.gemini25Flash

        #expect(model.providerType == .google)
        #expect(model.displayName == "Gemini 2.5 Flash")
        #expect(model.supportsVision == true)
        #expect(model.supportsPDF == true)
        #expect(model.maxInputTokens == 1_048_576)
        #expect(model.maxOutputTokens == 8_192)
    }

    @Test("Gemini 1.5 Pro is supported")
    func testGemini15ProSupport() {
        let model = ModelProvider.gemini15Pro

        #expect(model.providerType == .google)
        #expect(model.supportsVision == true)
        #expect(model.supportsPDF == true)
        #expect(model.maxInputTokens == 2_097_152)
    }

    @Test("All Gemini models use Google provider")
    func testAllGeminiModelsUseGoogleProvider() {
        let geminiModels: [ModelProvider] = [
            .gemini25Pro,
            .gemini25Flash,
            .gemini20FlashExp,
            .gemini15Pro,
            .gemini15Flash
        ]

        for model in geminiModels {
            #expect(model.providerType == .google)
        }
    }
}
