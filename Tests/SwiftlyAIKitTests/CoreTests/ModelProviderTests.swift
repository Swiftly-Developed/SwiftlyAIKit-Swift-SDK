import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for ModelProvider enum
@Suite("ModelProvider Tests")
struct ModelProviderTests {
    // MARK: - Enum Conformance

    @Test("ModelProvider is CaseIterable")
    func testCaseIterable() {
        let allCases = ModelProvider.allCases
        #expect(allCases.count == 60) // 22 Claude + 8 GPT + 5 Gemini + 3 Perplexity + 11 Mistral + 11 Cohere
    }

    @Test("ModelProvider has correct raw values")
    func testRawValues() {
        #expect(ModelProvider.claudeOpus41.rawValue == "claude-opus-4-1")
        #expect(ModelProvider.claudeSonnet45Latest.rawValue == "claude-sonnet-4-5")
        #expect(ModelProvider.claudeHaiku45Latest.rawValue == "claude-haiku-4-5")
        #expect(ModelProvider.gpt4Turbo.rawValue == "gpt-4-turbo")
    }

    @Test("ModelProvider is Codable (encode)")
    func testCodableEncode() throws {
        let model = ModelProvider.claudeSonnet4520250514
        let data = try JSONEncoder().encode(model)
        let decoded = String(data: data, encoding: .utf8)

        #expect(decoded?.contains("claude-sonnet-4-5-20250514") == true)
    }

    @Test("ModelProvider is Codable (decode)")
    func testCodableDecode() throws {
        let json = "\"claude-opus-4-20250514\"".data(using: .utf8)!
        let model = try JSONDecoder().decode(ModelProvider.self, from: json)

        #expect(model == .claudeOpus420250514)
    }

    // MARK: - Provider Type

    @Test("All Claude 4 models return Anthropic provider")
    func testClaude4ModelsProvider() {
        #expect(ModelProvider.claudeOpus41.providerType == .anthropic)
        #expect(ModelProvider.claudeOpus4Latest.providerType == .anthropic)
        #expect(ModelProvider.claudeOpus420250514.providerType == .anthropic)
        #expect(ModelProvider.claudeSonnet45Latest.providerType == .anthropic)
        #expect(ModelProvider.claudeSonnet4520250514.providerType == .anthropic)
        #expect(ModelProvider.claudeSonnet4Latest.providerType == .anthropic)
        #expect(ModelProvider.claudeSonnet420250115.providerType == .anthropic)
        #expect(ModelProvider.claudeHaiku45Latest.providerType == .anthropic)
        #expect(ModelProvider.claudeHaiku4520251001.providerType == .anthropic)
    }

    @Test("All Claude 3.7 models return Anthropic provider")
    func testClaude37ModelsProvider() {
        #expect(ModelProvider.claude37Sonnet.providerType == .anthropic)
        #expect(ModelProvider.claude37Sonnet20250219.providerType == .anthropic)
    }

    @Test("All Claude 3.5 models return Anthropic provider")
    func testClaude35ModelsProvider() {
        #expect(ModelProvider.claude35Sonnet.providerType == .anthropic)
        #expect(ModelProvider.claude35Sonnet20241022.providerType == .anthropic)
        #expect(ModelProvider.claude35Sonnet20240620.providerType == .anthropic)
        #expect(ModelProvider.claude35Haiku.providerType == .anthropic)
        #expect(ModelProvider.claude35Haiku20241022.providerType == .anthropic)
    }

    @Test("All Claude 3 models return Anthropic provider")
    func testClaude3ModelsProvider() {
        #expect(ModelProvider.claude3Opus.providerType == .anthropic)
        #expect(ModelProvider.claude3Opus20240229.providerType == .anthropic)
        #expect(ModelProvider.claude3Sonnet.providerType == .anthropic)
        #expect(ModelProvider.claude3Sonnet20240229.providerType == .anthropic)
        #expect(ModelProvider.claude3Haiku.providerType == .anthropic)
        #expect(ModelProvider.claude3Haiku20240307.providerType == .anthropic)
    }

    @Test("All OpenAI models return OpenAI provider")
    func testOpenAIModelsProvider() {
        #expect(ModelProvider.gpt4Turbo.providerType == .openai)
        #expect(ModelProvider.gpt4.providerType == .openai)
        #expect(ModelProvider.gpt35Turbo.providerType == .openai)
    }

    @Test("All models have a provider type")
    func testAllModelsHaveProvider() {
        for model in ModelProvider.allCases {
            // Should not crash
            _ = model.providerType
        }
    }

    // MARK: - Display Names

    @Test("Display names are human-readable")
    func testDisplayNames() {
        #expect(ModelProvider.claudeOpus41.displayName == "Claude Opus 4.1")
        #expect(ModelProvider.claudeSonnet45Latest.displayName == "Claude Sonnet 4.5")
        #expect(ModelProvider.claudeHaiku45Latest.displayName == "Claude Haiku 4.5")
        #expect(ModelProvider.claude37Sonnet.displayName == "Claude 3.7 Sonnet")
        #expect(ModelProvider.claude35Sonnet.displayName == "Claude 3.5 Sonnet")
        #expect(ModelProvider.claude3Opus.displayName == "Claude 3 Opus")
        #expect(ModelProvider.gpt4Turbo.displayName == "GPT-4 Turbo")
    }

    @Test("Display names include version dates when specified")
    func testDisplayNamesWithDates() {
        #expect(ModelProvider.claudeOpus420250514.displayName.contains("20250514"))
        #expect(ModelProvider.claudeSonnet4520250514.displayName.contains("20250514"))
        #expect(ModelProvider.claude35Sonnet20241022.displayName.contains("20241022"))
    }

    @Test("All models have non-empty display names")
    func testAllModelsHaveDisplayNames() {
        for model in ModelProvider.allCases {
            #expect(!model.displayName.isEmpty, "Model \(model) should have a display name")
        }
    }

    // MARK: - Vision Support

    @Test("All Claude models support vision")
    func testClaudeModelsVision() {
        #expect(ModelProvider.claudeOpus41.supportsVision)
        #expect(ModelProvider.claudeSonnet45Latest.supportsVision)
        #expect(ModelProvider.claudeHaiku45Latest.supportsVision)
        #expect(ModelProvider.claude37Sonnet.supportsVision)
        #expect(ModelProvider.claude35Sonnet.supportsVision)
        #expect(ModelProvider.claude3Opus.supportsVision)
        #expect(ModelProvider.claude3Haiku.supportsVision)
    }

    @Test("GPT-4 models support vision")
    func testGPT4Vision() {
        #expect(ModelProvider.gpt4Turbo.supportsVision)
        #expect(ModelProvider.gpt4.supportsVision)
    }

    @Test("GPT-3.5 does not support vision")
    func testGPT35NoVision() {
        #expect(!ModelProvider.gpt35Turbo.supportsVision)
    }

    // MARK: - Prompt Caching Support

    @Test("Claude 4 Opus models support prompt caching")
    func testClaude4OpusCaching() {
        #expect(ModelProvider.claudeOpus41.supportsPromptCaching)
        #expect(ModelProvider.claudeOpus4Latest.supportsPromptCaching)
        #expect(ModelProvider.claudeOpus420250514.supportsPromptCaching)
    }

    @Test("Claude 4 Sonnet models support prompt caching")
    func testClaude4SonnetCaching() {
        #expect(ModelProvider.claudeSonnet45Latest.supportsPromptCaching)
        #expect(ModelProvider.claudeSonnet4520250514.supportsPromptCaching)
        #expect(ModelProvider.claudeSonnet4Latest.supportsPromptCaching)
        #expect(ModelProvider.claudeSonnet420250115.supportsPromptCaching)
    }

    @Test("Claude 3.7 models support prompt caching")
    func testClaude37Caching() {
        #expect(ModelProvider.claude37Sonnet.supportsPromptCaching)
        #expect(ModelProvider.claude37Sonnet20250219.supportsPromptCaching)
    }

    @Test("Claude 3.5 Haiku supports prompt caching")
    func testClaude35HaikuCaching() {
        #expect(ModelProvider.claude35Haiku.supportsPromptCaching)
        #expect(ModelProvider.claude35Haiku20241022.supportsPromptCaching)
    }

    @Test("Claude 3 models support prompt caching")
    func testClaude3Caching() {
        #expect(ModelProvider.claude3Opus.supportsPromptCaching)
        #expect(ModelProvider.claude3Opus20240229.supportsPromptCaching)
        #expect(ModelProvider.claude3Haiku.supportsPromptCaching)
        #expect(ModelProvider.claude3Haiku20240307.supportsPromptCaching)
    }

    @Test("OpenAI models do not support prompt caching")
    func testOpenAINoCaching() {
        #expect(!ModelProvider.gpt4Turbo.supportsPromptCaching)
        #expect(!ModelProvider.gpt4.supportsPromptCaching)
        #expect(!ModelProvider.gpt35Turbo.supportsPromptCaching)
    }

    // MARK: - Extended Thinking Support

    @Test("Claude Opus 4 supports extended thinking")
    func testClaudeOpus4ExtendedThinking() {
        #expect(ModelProvider.claudeOpus4Latest.supportsExtendedThinking)
        #expect(ModelProvider.claudeOpus420250514.supportsExtendedThinking)
    }

    @Test("Claude Sonnet 4 supports extended thinking")
    func testClaudeSonnet4ExtendedThinking() {
        #expect(ModelProvider.claudeSonnet4Latest.supportsExtendedThinking)
        #expect(ModelProvider.claudeSonnet420250115.supportsExtendedThinking)
    }

    @Test("Claude 3.7 Sonnet supports extended thinking")
    func testClaude37ExtendedThinking() {
        #expect(ModelProvider.claude37Sonnet.supportsExtendedThinking)
        #expect(ModelProvider.claude37Sonnet20250219.supportsExtendedThinking)
    }

    @Test("Claude Opus 4.1 does not support extended thinking")
    func testClaudeOpus41NoExtendedThinking() {
        #expect(!ModelProvider.claudeOpus41.supportsExtendedThinking)
    }

    @Test("Haiku models do not support extended thinking")
    func testHaikuNoExtendedThinking() {
        #expect(!ModelProvider.claudeHaiku45Latest.supportsExtendedThinking)
        #expect(!ModelProvider.claude35Haiku.supportsExtendedThinking)
        #expect(!ModelProvider.claude3Haiku.supportsExtendedThinking)
    }

    @Test("OpenAI models do not support extended thinking")
    func testOpenAINoExtendedThinking() {
        #expect(!ModelProvider.gpt4Turbo.supportsExtendedThinking)
        #expect(!ModelProvider.gpt4.supportsExtendedThinking)
        #expect(!ModelProvider.gpt35Turbo.supportsExtendedThinking)
    }

    // MARK: - PDF Support

    @Test("Claude 4 models support PDF")
    func testClaude4PDF() {
        #expect(ModelProvider.claudeOpus41.supportsPDF)
        #expect(ModelProvider.claudeSonnet45Latest.supportsPDF)
        #expect(ModelProvider.claudeHaiku45Latest.supportsPDF)
    }

    @Test("Claude 3.7 and 3.5 models support PDF")
    func testClaude37And35PDF() {
        #expect(ModelProvider.claude37Sonnet.supportsPDF)
        #expect(ModelProvider.claude35Sonnet.supportsPDF)
        #expect(ModelProvider.claude35Haiku.supportsPDF)
    }

    @Test("Claude 3 Opus supports PDF")
    func testClaude3OpusPDF() {
        #expect(ModelProvider.claude3Opus.supportsPDF)
        #expect(ModelProvider.claude3Opus20240229.supportsPDF)
    }

    @Test("Claude 3 Sonnet and Haiku do not support PDF")
    func testClaude3SonnetHaikuNoPDF() {
        #expect(!ModelProvider.claude3Sonnet.supportsPDF)
        #expect(!ModelProvider.claude3Sonnet20240229.supportsPDF)
        #expect(!ModelProvider.claude3Haiku.supportsPDF)
        #expect(!ModelProvider.claude3Haiku20240307.supportsPDF)
    }

    @Test("OpenAI models do not support PDF")
    func testOpenAINoPDF() {
        #expect(!ModelProvider.gpt4Turbo.supportsPDF)
        #expect(!ModelProvider.gpt4.supportsPDF)
        #expect(!ModelProvider.gpt35Turbo.supportsPDF)
    }

    // MARK: - Token Limits

    @Test("Claude 4 models have 200k context window")
    func testClaude4InputTokens() {
        #expect(ModelProvider.claudeOpus41.maxInputTokens == 200_000)
        #expect(ModelProvider.claudeSonnet45Latest.maxInputTokens == 200_000)
        #expect(ModelProvider.claudeSonnet4Latest.maxInputTokens == 200_000)
        #expect(ModelProvider.claude37Sonnet.maxInputTokens == 200_000)
        #expect(ModelProvider.claudeHaiku45Latest.maxInputTokens == 200_000)
    }

    @Test("Claude 3.5 and 3 models have 200k context window")
    func testClaude35And3InputTokens() {
        #expect(ModelProvider.claude35Sonnet.maxInputTokens == 200_000)
        #expect(ModelProvider.claude35Haiku.maxInputTokens == 200_000)
        #expect(ModelProvider.claude3Opus.maxInputTokens == 200_000)
        #expect(ModelProvider.claude3Sonnet.maxInputTokens == 200_000)
        #expect(ModelProvider.claude3Haiku.maxInputTokens == 200_000)
    }

    @Test("Latest Claude models have 16k output tokens")
    func testLatestClaudeOutputTokens() {
        #expect(ModelProvider.claudeOpus41.maxOutputTokens == 16_384)
        #expect(ModelProvider.claudeSonnet45Latest.maxOutputTokens == 16_384)
        #expect(ModelProvider.claudeHaiku45Latest.maxOutputTokens == 16_384)
        #expect(ModelProvider.claudeSonnet4Latest.maxOutputTokens == 16_384)
        #expect(ModelProvider.claude37Sonnet.maxOutputTokens == 16_384)
    }

    @Test("Claude 3.5 models have 8k output tokens")
    func testClaude35OutputTokens() {
        #expect(ModelProvider.claude35Sonnet.maxOutputTokens == 8_192)
        #expect(ModelProvider.claude35Haiku.maxOutputTokens == 8_192)
    }

    @Test("Claude 3 models have 4k output tokens")
    func testClaude3OutputTokens() {
        #expect(ModelProvider.claude3Opus.maxOutputTokens == 4_096)
        #expect(ModelProvider.claude3Sonnet.maxOutputTokens == 4_096)
        #expect(ModelProvider.claude3Haiku.maxOutputTokens == 4_096)
    }

    @Test("GPT-4 Turbo has 128k context window")
    func testGPT4TurboInputTokens() {
        #expect(ModelProvider.gpt4Turbo.maxInputTokens == 128_000)
    }

    @Test("GPT-4 has 8k context window")
    func testGPT4InputTokens() {
        #expect(ModelProvider.gpt4.maxInputTokens == 8_192)
    }

    @Test("GPT-3.5 has 16k context window")
    func testGPT35InputTokens() {
        #expect(ModelProvider.gpt35Turbo.maxInputTokens == 16_385)
    }

    @Test("OpenAI models have 4k output tokens")
    func testOpenAIOutputTokens() {
        #expect(ModelProvider.gpt4Turbo.maxOutputTokens == 4_096)
        #expect(ModelProvider.gpt4.maxOutputTokens == 4_096)
        #expect(ModelProvider.gpt35Turbo.maxOutputTokens == 4_096)
    }

    // MARK: - Model Families

    @Test("All Opus models are from Anthropic")
    func testOpusModels() {
        let opusModels = ModelProvider.allCases.filter { $0.displayName.contains("Opus") }
        for model in opusModels {
            #expect(model.providerType == .anthropic, "Opus model \(model) should be Anthropic")
        }
    }

    @Test("All Sonnet models are from Anthropic")
    func testSonnetModels() {
        let sonnetModels = ModelProvider.allCases.filter { $0.displayName.contains("Sonnet") }
        for model in sonnetModels {
            #expect(model.providerType == .anthropic, "Sonnet model \(model) should be Anthropic")
        }
    }

    @Test("All Haiku models are from Anthropic")
    func testHaikuModels() {
        let haikuModels = ModelProvider.allCases.filter { $0.displayName.contains("Haiku") }
        for model in haikuModels {
            #expect(model.providerType == .anthropic, "Haiku model \(model) should be Anthropic")
        }
    }

    @Test("All GPT models are from OpenAI")
    func testGPTModels() {
        let gptModels = ModelProvider.allCases.filter { $0.displayName.contains("GPT") }
        for model in gptModels {
            #expect(model.providerType == .openai, "GPT model \(model) should be OpenAI")
        }
    }

    // MARK: - Feature Coverage

    @Test("At least one model supports each feature")
    func testFeatureCoverage() {
        let allModels = ModelProvider.allCases

        // Vision
        #expect(allModels.contains { $0.supportsVision })

        // Prompt Caching
        #expect(allModels.contains { $0.supportsPromptCaching })

        // Extended Thinking
        #expect(allModels.contains { $0.supportsExtendedThinking })

        // PDF
        #expect(allModels.contains { $0.supportsPDF })
    }

    @Test("Not all models support all features")
    func testFeatureVariance() {
        let allModels = ModelProvider.allCases

        // Not all models support prompt caching
        #expect(allModels.contains { !$0.supportsPromptCaching })

        // Not all models support extended thinking
        #expect(allModels.contains { !$0.supportsExtendedThinking })

        // Not all models support PDF
        #expect(allModels.contains { !$0.supportsPDF })
    }

    // MARK: - Comprehensive Property Tests

    @Test("All models have positive token limits")
    func testAllModelsTokenLimits() {
        for model in ModelProvider.allCases {
            #expect(model.maxInputTokens > 0, "Model \(model) should have positive input tokens")
            #expect(model.maxOutputTokens > 0, "Model \(model) should have positive output tokens")
        }
    }

    @Test("All models have provider and display name")
    func testAllModelsBasicProperties() {
        for model in ModelProvider.allCases {
            // Should not crash
            _ = model.providerType
            _ = model.displayName
            #expect(!model.displayName.isEmpty)
        }
    }

    // MARK: - Real-World Scenarios

    @Test("Scenario: Choose model for vision task")
    func testVisionModelSelection() {
        let visionModels = ModelProvider.allCases.filter { $0.supportsVision }
        #expect(visionModels.count > 0)

        // Latest Sonnet should support vision
        #expect(visionModels.contains(.claudeSonnet45Latest))
    }

    @Test("Scenario: Choose model with prompt caching for cost savings")
    func testCachingModelSelection() {
        let cachingModels = ModelProvider.allCases.filter { $0.supportsPromptCaching }
        #expect(cachingModels.count > 0)

        // Haiku with caching for cost efficiency
        #expect(cachingModels.contains(.claude35Haiku))
    }

    @Test("Scenario: Choose model for complex reasoning with extended thinking")
    func testReasoningModelSelection() {
        let thinkingModels = ModelProvider.allCases.filter { $0.supportsExtendedThinking }
        #expect(thinkingModels.count > 0)

        // Opus 4 and Sonnet 4 should support extended thinking
        #expect(thinkingModels.contains(.claudeOpus4Latest))
        #expect(thinkingModels.contains(.claudeSonnet4Latest))
    }

    @Test("Scenario: Choose model for PDF analysis")
    func testPDFModelSelection() {
        let pdfModels = ModelProvider.allCases.filter { $0.supportsPDF }
        #expect(pdfModels.count > 0)

        // Latest models should support PDF
        #expect(pdfModels.contains(.claudeOpus41))
        #expect(pdfModels.contains(.claudeSonnet45Latest))
    }

    @Test("Scenario: Find largest context window")
    func testLargestContextWindow() {
        let maxContext = ModelProvider.allCases.map { $0.maxInputTokens }.max()
        #expect(maxContext == 2_097_152)

        // Gemini Pro models have the largest context (2M tokens)
        let largestModels = ModelProvider.allCases.filter { $0.maxInputTokens == 2_097_152 }
        #expect(largestModels.allSatisfy { $0.providerType == .google })
    }

    // MARK: - Gemini Model Tests

    @Test("All Gemini models return Google provider")
    func testGeminiModelsProvider() {
        #expect(ModelProvider.gemini25Pro.providerType == .google)
        #expect(ModelProvider.gemini25Flash.providerType == .google)
        #expect(ModelProvider.gemini20FlashExp.providerType == .google)
        #expect(ModelProvider.gemini15Pro.providerType == .google)
        #expect(ModelProvider.gemini15Flash.providerType == .google)
    }

    @Test("Gemini models have correct display names")
    func testGeminiDisplayNames() {
        #expect(ModelProvider.gemini25Pro.displayName == "Gemini 2.5 Pro")
        #expect(ModelProvider.gemini25Flash.displayName == "Gemini 2.5 Flash")
        #expect(ModelProvider.gemini20FlashExp.displayName == "Gemini 2.0 Flash (Experimental)")
        #expect(ModelProvider.gemini15Pro.displayName == "Gemini 1.5 Pro")
        #expect(ModelProvider.gemini15Flash.displayName == "Gemini 1.5 Flash")
    }

    @Test("All Gemini models support vision")
    func testGeminiVisionSupport() {
        #expect(ModelProvider.gemini25Pro.supportsVision == true)
        #expect(ModelProvider.gemini25Flash.supportsVision == true)
        #expect(ModelProvider.gemini20FlashExp.supportsVision == true)
        #expect(ModelProvider.gemini15Pro.supportsVision == true)
        #expect(ModelProvider.gemini15Flash.supportsVision == true)
    }

    @Test("All Gemini models support PDF")
    func testGeminiPDFSupport() {
        #expect(ModelProvider.gemini25Pro.supportsPDF == true)
        #expect(ModelProvider.gemini25Flash.supportsPDF == true)
        #expect(ModelProvider.gemini20FlashExp.supportsPDF == true)
        #expect(ModelProvider.gemini15Pro.supportsPDF == true)
        #expect(ModelProvider.gemini15Flash.supportsPDF == true)
    }

    @Test("Gemini stable models support prompt caching")
    func testGeminiPromptCaching() {
        #expect(ModelProvider.gemini25Pro.supportsPromptCaching == true)
        #expect(ModelProvider.gemini25Flash.supportsPromptCaching == true)
        #expect(ModelProvider.gemini15Pro.supportsPromptCaching == true)
        #expect(ModelProvider.gemini15Flash.supportsPromptCaching == true)
        // Experimental model might not support caching
        #expect(ModelProvider.gemini20FlashExp.supportsPromptCaching == false)
    }

    @Test("Gemini models have massive context windows")
    func testGeminiContextWindows() {
        // Pro models: 2M tokens
        #expect(ModelProvider.gemini25Pro.maxInputTokens == 2_097_152)
        #expect(ModelProvider.gemini15Pro.maxInputTokens == 2_097_152)

        // Flash models: 1M tokens
        #expect(ModelProvider.gemini25Flash.maxInputTokens == 1_048_576)
        #expect(ModelProvider.gemini20FlashExp.maxInputTokens == 1_048_576)
        #expect(ModelProvider.gemini15Flash.maxInputTokens == 1_048_576)
    }

    @Test("Gemini models have correct output limits")
    func testGeminiOutputLimits() {
        // 2.5 Pro has 65K output
        #expect(ModelProvider.gemini25Pro.maxOutputTokens == 65_536)

        // Other models have 8K output
        #expect(ModelProvider.gemini25Flash.maxOutputTokens == 8_192)
        #expect(ModelProvider.gemini20FlashExp.maxOutputTokens == 8_192)
        #expect(ModelProvider.gemini15Pro.maxOutputTokens == 8_192)
        #expect(ModelProvider.gemini15Flash.maxOutputTokens == 8_192)
    }

    @Test("Gemini models do not support extended thinking")
    func testGeminiNoExtendedThinking() {
        #expect(ModelProvider.gemini25Pro.supportsExtendedThinking == false)
        #expect(ModelProvider.gemini25Flash.supportsExtendedThinking == false)
        #expect(ModelProvider.gemini20FlashExp.supportsExtendedThinking == false)
        #expect(ModelProvider.gemini15Pro.supportsExtendedThinking == false)
        #expect(ModelProvider.gemini15Flash.supportsExtendedThinking == false)
    }
}
