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
    func testListModelsResponseDecoding() throws {
        let data = MockGeminiAPI.listModelsResponse.data(using: .utf8)!
        // Plain decoder (no .convertFromSnakeCase), matching GeminiProvider.listModels.
        let response = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)

        #expect(response.models.count == 2)
        #expect(response.nextPageToken == "abc123")

        let pro = response.models[0]
        #expect(pro.name == "models/gemini-2.5-pro")
        #expect(pro.displayName == "Gemini 2.5 Pro")
        #expect(pro.inputTokenLimit == 2_097_152)
        #expect(pro.outputTokenLimit == 65_536)
        #expect(pro.supportedGenerationMethods.contains("generateContent"))
    }

    @Test("supportedGenerationMethods round-trips through Codable")
    func testModelInfoSupportedMethodsRoundTrip() throws {
        let data = MockGeminiAPI.listModelsResponse.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)

        let reencoded = try JSONEncoder().encode(decoded)
        let redecoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: reencoded)

        #expect(redecoded.models[0].supportedGenerationMethods == ["generateContent", "countTokens"])
        #expect(redecoded.models[1].supportedGenerationMethods == ["embedContent"])
        #expect(redecoded.nextPageToken == "abc123")
    }

    @Test("Caller can filter to generateContent-capable models")
    func testFilterToGenerateContentModels() throws {
        let data = MockGeminiAPI.listModelsResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)

        // listModels returns the RAW list; the caller filters to chat-capable models.
        let chatModels = response.models.filter { $0.supportedGenerationMethods.contains("generateContent") }
        #expect(chatModels.count == 1)
        #expect(chatModels.first?.name == "models/gemini-2.5-pro")
    }

    @Test("Models list decodes when nextPageToken is absent")
    func testListModelsWithoutPageToken() throws {
        let json = """
        { "models": [ { "name": "models/gemini-2.5-flash", "supportedGenerationMethods": ["generateContent"] } ] }
        """
        let response = try JSONDecoder().decode(GeminiModelsResponse.self, from: Data(json.utf8))

        #expect(response.nextPageToken == nil)
        #expect(response.models.count == 1)
        #expect(response.models[0].displayName == nil)
        #expect(response.models[0].supportedGenerationMethods == ["generateContent"])
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
