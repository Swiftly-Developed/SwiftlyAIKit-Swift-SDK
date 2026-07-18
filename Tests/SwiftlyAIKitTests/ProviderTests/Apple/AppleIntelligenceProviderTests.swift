import Testing
import Foundation
@testable import SwiftlyAIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Tests for `AppleIntelligenceProvider` Foundation Models tool calling: neutral `AITool`
/// translation into a Foundation Models schema, and mapping a captured on-device tool call back
/// into a neutral `.toolUse` response. Foundation Models–dependent assertions are availability
/// gated; the pure mapping is verified on every platform.
@Suite("AppleIntelligenceProvider Tool Tests")
struct AppleIntelligenceProviderTests {
    private func weatherTool() -> AITool {
        AITool(
            name: "get_weather",
            description: "Get the current weather",
            parameters: AIToolParameters(
                properties: [
                    "location": AIToolProperty(type: "string", description: "City"),
                    "unit": AIToolProperty(type: "string", description: "Unit", enumValues: ["celsius", "fahrenheit"]),
                    "days": AIToolProperty(type: "integer", description: "Forecast days")
                ],
                required: ["location"]
            )
        )
    }

    // MARK: - Neutral Tool-Call Mapping (platform-independent)

    @Test("A captured on-device tool call maps to a .toolUse response")
    func testToolCallMapsToToolUse() {
        let provider = AppleIntelligenceProvider()
        let response = provider.makeToolUseResponse(
            name: "get_weather",
            argumentsJSON: "{\"location\":\"SF\"}"
        )

        #expect(response.stopReason == .toolUse)
        #expect(response.provider == .appleIntelligence)

        let call = response.message.content.compactMap { part -> AIToolCall? in
            if case .toolCall(let toolCall) = part { return toolCall }
            return nil
        }.first
        #expect(call?.name == "get_weather")
        #expect(call?.arguments.contains("SF") == true)
    }

    @Test("Provider reports tool support matching Foundation Models availability")
    func testSupportsToolsTracksAvailability() {
        #expect(AppleIntelligenceProvider().supportsTools == AppleIntelligenceCapabilities.foundationModelsAvailable)
    }

    // MARK: - Neutral Tool → Foundation Models Schema (availability gated)

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Test("A neutral AITool translates into a Foundation Models GenerationSchema")
    func testToolTranslatesToGenerationSchema() throws {
        // A well-formed neutral tool (string, enum-constrained string, integer, required field)
        // must produce a valid GenerationSchema without throwing.
        _ = try AppleIntelligenceProvider.makeGenerationSchema(for: weatherTool())
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Test("Nested object and array tool parameters translate without throwing")
    func testNestedToolTranslatesToGenerationSchema() throws {
        let tool = AITool(
            name: "book_trip",
            description: "Book a trip",
            parameters: AIToolParameters(
                properties: [
                    "traveler": AIToolProperty(
                        type: "object",
                        description: "Traveler details",
                        properties: [
                            "name": AIToolProperty(type: "string"),
                            "age": AIToolProperty(type: "integer")
                        ],
                        required: ["name"]
                    ),
                    "cities": AIToolProperty(
                        type: "array",
                        description: "Cities to visit",
                        items: AIToolPropertyItems(type: "string")
                    )
                ],
                required: ["traveler"]
            )
        )
        _ = try AppleIntelligenceProvider.makeGenerationSchema(for: tool)
    }
    #endif
}
