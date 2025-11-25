import Foundation

/// Enum listing all supported AI models across providers
public enum ModelProvider: String, Codable, Sendable, CaseIterable {
    // MARK: - Anthropic Claude Models

    /// Claude Opus 4.1 - Latest Opus model (2025)
    case claudeOpus41 = "claude-opus-4-1"

    /// Claude Opus 4 - Latest version
    case claudeOpus4Latest = "claude-opus-4"

    /// Claude Opus 4 - Version 20250514
    case claudeOpus420250514 = "claude-opus-4-20250514"

    /// Claude Sonnet 4.5 - Latest Sonnet model (2025)
    case claudeSonnet45Latest = "claude-sonnet-4-5"

    /// Claude Sonnet 4.5 - Version 20250514
    case claudeSonnet4520250514 = "claude-sonnet-4-5-20250514"

    /// Claude Sonnet 4 - Latest version
    case claudeSonnet4Latest = "claude-sonnet-4"

    /// Claude Sonnet 4 - Version 20250115
    case claudeSonnet420250115 = "claude-sonnet-4-20250115"

    /// Claude 3.7 Sonnet - Latest 3.7 model
    case claude37Sonnet = "claude-3-7-sonnet"

    /// Claude 3.7 Sonnet - Version 20250219
    case claude37Sonnet20250219 = "claude-3-7-sonnet-20250219"

    /// Claude Haiku 4.5 - Latest Haiku model (2025)
    case claudeHaiku45Latest = "claude-haiku-4-5"

    /// Claude Haiku 4.5 - Version 20251001
    case claudeHaiku4520251001 = "claude-haiku-4-5-20251001"

    /// Claude 3.5 Sonnet - Legacy (deprecated, retiring Oct 22, 2025)
    case claude35Sonnet = "claude-3-5-sonnet"

    /// Claude 3.5 Sonnet - Version 20241022
    case claude35Sonnet20241022 = "claude-3-5-sonnet-20241022"

    /// Claude 3.5 Sonnet - Version 20240620
    case claude35Sonnet20240620 = "claude-3-5-sonnet-20240620"

    /// Claude 3.5 Haiku - Latest 3.5 Haiku
    case claude35Haiku = "claude-3-5-haiku"

    /// Claude 3.5 Haiku - Version 20241022
    case claude35Haiku20241022 = "claude-3-5-haiku-20241022"

    /// Claude 3 Opus - Legacy
    case claude3Opus = "claude-3-opus"

    /// Claude 3 Opus - Version 20240229
    case claude3Opus20240229 = "claude-3-opus-20240229"

    /// Claude 3 Sonnet - Legacy
    case claude3Sonnet = "claude-3-sonnet"

    /// Claude 3 Sonnet - Version 20240229
    case claude3Sonnet20240229 = "claude-3-sonnet-20240229"

    /// Claude 3 Haiku - Legacy
    case claude3Haiku = "claude-3-haiku"

    /// Claude 3 Haiku - Version 20240307
    case claude3Haiku20240307 = "claude-3-haiku-20240307"

    // MARK: - OpenAI Models

    /// GPT-4o - Latest model with vision and function calling
    case gpt4o = "gpt-4o"

    /// GPT-4o - May 13 2024 snapshot
    case gpt4o20240513 = "gpt-4o-2024-05-13"

    /// GPT-4o Mini - Lightweight version
    case gpt4oMini = "gpt-4o-mini"

    /// GPT-4o Mini - July 18 2024 snapshot
    case gpt4oMini20240718 = "gpt-4o-mini-2024-07-18"

    /// GPT-4 Turbo - High intelligence model
    case gpt4Turbo = "gpt-4-turbo"

    /// GPT-4 Turbo Preview
    case gpt4TurboPreview = "gpt-4-turbo-preview"

    /// GPT-4 - Base model
    case gpt4 = "gpt-4"

    /// GPT-3.5 Turbo - Fast and economical
    case gpt35Turbo = "gpt-3.5-turbo"

    // MARK: - Google Gemini Models

    /// Gemini 2.5 Pro - Most capable model
    case gemini25Pro = "gemini-2.5-pro-latest"

    /// Gemini 2.5 Flash - Fast and efficient
    case gemini25Flash = "gemini-2.5-flash-latest"

    /// Gemini 2.0 Flash Experimental - Latest experimental model
    case gemini20FlashExp = "gemini-2.0-flash-exp"

    /// Gemini 1.5 Pro - Previous generation flagship
    case gemini15Pro = "gemini-1.5-pro-latest"

    /// Gemini 1.5 Flash - Previous generation fast model
    case gemini15Flash = "gemini-1.5-flash-latest"

    // MARK: - Perplexity AI Models

    /// Sonar - Balanced performance with web search
    case sonar = "sonar"

    /// Sonar Pro - Enhanced accuracy with web search
    case sonarPro = "sonar-pro"

    /// Sonar Reasoning - Advanced reasoning with web search
    case sonarReasoning = "sonar-reasoning"

    // MARK: - Mistral AI Models

    /// Mistral Large 2.1 - Most capable model (128K context)
    case mistralLarge2 = "mistral-large-2411"

    /// Mistral Large - Latest alias
    case mistralLargeLatest = "mistral-large-latest"

    /// Mistral Medium 3 - Balanced performance (128K context)
    case mistralMedium3 = "mistral-medium-3-2505"

    /// Mistral Medium - Latest alias
    case mistralMediumLatest = "mistral-medium-latest"

    /// Mistral Small 3.1 - Fast and cost-effective (128K context)
    case mistralSmall3 = "mistral-small-2501"

    /// Mistral Small - Latest alias
    case mistralSmallLatest = "mistral-small-latest"

    /// Codestral - Code generation specialist (32K context)
    case codestral = "codestral-latest"

    /// Magistral Small - Reasoning model with chain-of-thought (128K context)
    case magistralSmall = "magistral-small-latest"

    /// Magistral Medium - Advanced reasoning (128K context)
    case magistralMedium = "magistral-medium-latest"

    /// Ministral 3B - Edge computing model (128K context)
    case ministral3B = "ministral-3b-latest"

    /// Ministral 8B - Edge computing model (128K context)
    case ministral8B = "ministral-8b-latest"

    // MARK: - DeepSeek Models

    /// DeepSeek Chat - Latest chat model (128K context, V3.2)
    case deepseekChat = "deepseek-chat"

    /// DeepSeek Reasoner - Reasoning model with chain-of-thought (64K-128K context, R1)
    case deepseekReasoner = "deepseek-reasoner"

    // MARK: - xAI Grok Models

    /// Grok 4 - Latest flagship model with reasoning (July 2025)
    case grok4 = "grok-4-0709"

    /// Grok 4 - Latest alias
    case grok4Latest = "grok-4"

    /// Grok 3 - Previous flagship model (1M context)
    case grok3 = "grok-3"

    /// Grok 3 Mini - Smaller, faster model (1M context)
    case grok3Mini = "grok-3-mini"

    /// Grok 2 Vision - Image understanding model (128K context)
    case grok2Vision = "grok-2-vision-1212"

    /// Grok Code Fast - Code generation specialist
    case grokCodeFast = "grok-code-fast-1"

    /// Grok 2 Image - Image generation model
    case grok2Image = "grok-2-image"

    // MARK: - Cohere Models

    /// Command A - Most capable model (256K context, 111B params)
    case commandA = "command-a-03-2025"

    /// Command A Reasoning - Advanced reasoning model (256K context)
    case commandAReasoning = "command-a-reasoning-03-2025"

    /// Command A Translate - Translation specialist (16K context, 23 languages)
    case commandATranslate = "command-a-translate-03-2025"

    /// Command A Vision - Multimodal model with image understanding (256K context)
    case commandAVision = "command-a-vision-03-2025"

    /// Command R+ 08-2024 - Latest RAG-optimized model (256K context)
    case commandRPlus08 = "command-r-plus-08-2024"

    /// Command R 08-2024 - Efficient RAG model (256K context)
    case commandR08 = "command-r-08-2024"

    /// Command R7B - Smallest R family model (256K context, 7B params)
    case commandR7B = "command-r7b-12-2024"

    /// Command R+ - Legacy version (128K context)
    case commandRPlus = "command-r-plus"

    /// Command R - Legacy version (128K context)
    case commandR = "command-r"

    /// Command - Original Command model (4K context)
    case command = "command"

    /// Command Light - Lightweight version (4K context)
    case commandLight = "command-light"

    // MARK: - Properties

    /// The provider for this model
    public var providerType: ProviderType {
        switch self {
        case .claudeOpus41, .claudeOpus4Latest, .claudeOpus420250514,
             .claudeSonnet45Latest, .claudeSonnet4520250514,
             .claudeSonnet4Latest, .claudeSonnet420250115,
             .claude37Sonnet, .claude37Sonnet20250219,
             .claudeHaiku45Latest, .claudeHaiku4520251001,
             .claude35Sonnet, .claude35Sonnet20241022, .claude35Sonnet20240620,
             .claude35Haiku, .claude35Haiku20241022,
             .claude3Opus, .claude3Opus20240229,
             .claude3Sonnet, .claude3Sonnet20240229,
             .claude3Haiku, .claude3Haiku20240307:
            return .anthropic

        case .gpt4o, .gpt4o20240513,
             .gpt4oMini, .gpt4oMini20240718,
             .gpt4Turbo, .gpt4TurboPreview,
             .gpt4, .gpt35Turbo:
            return .openai

        case .gemini25Pro, .gemini25Flash,
             .gemini20FlashExp,
             .gemini15Pro, .gemini15Flash:
            return .google

        case .sonar, .sonarPro, .sonarReasoning:
            return .perplexity

        case .mistralLarge2, .mistralLargeLatest,
             .mistralMedium3, .mistralMediumLatest,
             .mistralSmall3, .mistralSmallLatest,
             .codestral,
             .magistralSmall, .magistralMedium,
             .ministral3B, .ministral8B:
            return .mistral

        case .deepseekChat, .deepseekReasoner:
            return .deepseek

        case .grok4, .grok4Latest, .grok3, .grok3Mini, .grok2Vision, .grokCodeFast, .grok2Image:
            return .grok

        case .commandA, .commandAReasoning, .commandATranslate, .commandAVision,
             .commandRPlus08, .commandR08, .commandR7B,
             .commandRPlus, .commandR,
             .command, .commandLight:
            return .cohere
        }
    }

    /// Human-readable name for the model
    public var displayName: String {
        switch self {
        case .claudeOpus41: return "Claude Opus 4.1"
        case .claudeOpus4Latest: return "Claude Opus 4"
        case .claudeOpus420250514: return "Claude Opus 4 (20250514)"
        case .claudeSonnet45Latest: return "Claude Sonnet 4.5"
        case .claudeSonnet4520250514: return "Claude Sonnet 4.5 (20250514)"
        case .claudeSonnet4Latest: return "Claude Sonnet 4"
        case .claudeSonnet420250115: return "Claude Sonnet 4 (20250115)"
        case .claude37Sonnet: return "Claude 3.7 Sonnet"
        case .claude37Sonnet20250219: return "Claude 3.7 Sonnet (20250219)"
        case .claudeHaiku45Latest: return "Claude Haiku 4.5"
        case .claudeHaiku4520251001: return "Claude Haiku 4.5 (20251001)"
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude35Sonnet20241022: return "Claude 3.5 Sonnet (20241022)"
        case .claude35Sonnet20240620: return "Claude 3.5 Sonnet (20240620)"
        case .claude35Haiku: return "Claude 3.5 Haiku"
        case .claude35Haiku20241022: return "Claude 3.5 Haiku (20241022)"
        case .claude3Opus: return "Claude 3 Opus"
        case .claude3Opus20240229: return "Claude 3 Opus (20240229)"
        case .claude3Sonnet: return "Claude 3 Sonnet"
        case .claude3Sonnet20240229: return "Claude 3 Sonnet (20240229)"
        case .claude3Haiku: return "Claude 3 Haiku"
        case .claude3Haiku20240307: return "Claude 3 Haiku (20240307)"
        case .gpt4o: return "GPT-4o"
        case .gpt4o20240513: return "GPT-4o (2024-05-13)"
        case .gpt4oMini: return "GPT-4o Mini"
        case .gpt4oMini20240718: return "GPT-4o Mini (2024-07-18)"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gpt4TurboPreview: return "GPT-4 Turbo Preview"
        case .gpt4: return "GPT-4"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
        case .gemini25Pro: return "Gemini 2.5 Pro"
        case .gemini25Flash: return "Gemini 2.5 Flash"
        case .gemini20FlashExp: return "Gemini 2.0 Flash (Experimental)"
        case .gemini15Pro: return "Gemini 1.5 Pro"
        case .gemini15Flash: return "Gemini 1.5 Flash"
        case .sonar: return "Sonar"
        case .sonarPro: return "Sonar Pro"
        case .sonarReasoning: return "Sonar Reasoning"
        case .mistralLarge2: return "Mistral Large 2.1"
        case .mistralLargeLatest: return "Mistral Large"
        case .mistralMedium3: return "Mistral Medium 3"
        case .mistralMediumLatest: return "Mistral Medium"
        case .mistralSmall3: return "Mistral Small 3.1"
        case .mistralSmallLatest: return "Mistral Small"
        case .codestral: return "Codestral"
        case .magistralSmall: return "Magistral Small"
        case .magistralMedium: return "Magistral Medium"
        case .ministral3B: return "Ministral 3B"
        case .ministral8B: return "Ministral 8B"
        case .deepseekChat: return "DeepSeek Chat"
        case .deepseekReasoner: return "DeepSeek Reasoner"
        case .grok4: return "Grok 4"
        case .grok4Latest: return "Grok 4"
        case .grok3: return "Grok 3"
        case .grok3Mini: return "Grok 3 Mini"
        case .grok2Vision: return "Grok 2 Vision"
        case .grokCodeFast: return "Grok Code Fast"
        case .grok2Image: return "Grok 2 Image"
        case .commandA: return "Command A"
        case .commandAReasoning: return "Command A Reasoning"
        case .commandATranslate: return "Command A Translate"
        case .commandAVision: return "Command A Vision"
        case .commandRPlus08: return "Command R+ 08-2024"
        case .commandR08: return "Command R 08-2024"
        case .commandR7B: return "Command R7B"
        case .commandRPlus: return "Command R+"
        case .commandR: return "Command R"
        case .command: return "Command"
        case .commandLight: return "Command Light"
        }
    }

    /// Check if model supports vision/images
    public var supportsVision: Bool {
        switch self {
        case .claudeOpus41, .claudeOpus4Latest, .claudeOpus420250514,
             .claudeSonnet45Latest, .claudeSonnet4520250514,
             .claudeSonnet4Latest, .claudeSonnet420250115,
             .claude37Sonnet, .claude37Sonnet20250219,
             .claudeHaiku45Latest, .claudeHaiku4520251001,
             .claude35Sonnet, .claude35Sonnet20241022, .claude35Sonnet20240620,
             .claude35Haiku, .claude35Haiku20241022,
             .claude3Opus, .claude3Opus20240229,
             .claude3Sonnet, .claude3Sonnet20240229,
             .claude3Haiku, .claude3Haiku20240307:
            return true
        case .gpt4o, .gpt4o20240513,
             .gpt4oMini, .gpt4oMini20240718,
             .gpt4Turbo, .gpt4TurboPreview,
             .gpt4:
            return true
        case .gpt35Turbo:
            return false
        case .gemini25Pro, .gemini25Flash,
             .gemini20FlashExp,
             .gemini15Pro, .gemini15Flash:
            return true
        case .sonar, .sonarPro, .sonarReasoning:
            return false
        case .mistralLargeLatest, .mistralLarge2,
             .mistralMediumLatest, .mistralMedium3,
             .mistralSmallLatest, .mistralSmall3:
            return true
        case .codestral, .magistralSmall, .magistralMedium,
             .ministral3B, .ministral8B:
            return false
        case .deepseekChat, .deepseekReasoner:
            return false
        case .grok2Vision:
            return true
        case .grok4, .grok4Latest, .grok3, .grok3Mini, .grokCodeFast, .grok2Image:
            return false
        case .commandAVision:
            return true
        case .commandA, .commandAReasoning, .commandATranslate,
             .commandRPlus08, .commandR08, .commandR7B,
             .commandRPlus, .commandR,
             .command, .commandLight:
            return false
        }
    }

    /// Check if model supports prompt caching
    public var supportsPromptCaching: Bool {
        switch self {
        case .claudeOpus41, .claudeOpus4Latest, .claudeOpus420250514,
             .claudeSonnet45Latest, .claudeSonnet4520250514,
             .claudeSonnet4Latest, .claudeSonnet420250115,
             .claude37Sonnet, .claude37Sonnet20250219,
             .claudeHaiku45Latest, .claudeHaiku4520251001,
             .claude35Haiku, .claude35Haiku20241022,
             .claude3Opus, .claude3Opus20240229,
             .claude3Haiku, .claude3Haiku20240307:
            return true
        case .gemini25Pro, .gemini25Flash,
             .gemini15Pro, .gemini15Flash:
            return true
        case .deepseekChat, .deepseekReasoner:
            return true
        case .grok4, .grok4Latest, .grok3, .grok3Mini, .grok2Vision, .grokCodeFast:
            return true  // Grok has automatic prompt caching
        default:
            return false
        }
    }

    /// Check if model supports extended thinking
    public var supportsExtendedThinking: Bool {
        switch self {
        case .claudeOpus4Latest, .claudeOpus420250514,
             .claudeSonnet4Latest, .claudeSonnet420250115,
             .claude37Sonnet, .claude37Sonnet20250219:
            return true
        default:
            return false
        }
    }

    /// Check if model supports PDF documents
    public var supportsPDF: Bool {
        switch self {
        case .claudeOpus41, .claudeOpus4Latest, .claudeOpus420250514,
             .claudeSonnet45Latest, .claudeSonnet4520250514,
             .claudeSonnet4Latest, .claudeSonnet420250115,
             .claude37Sonnet, .claude37Sonnet20250219,
             .claudeHaiku45Latest, .claudeHaiku4520251001,
             .claude35Sonnet, .claude35Sonnet20241022, .claude35Sonnet20240620,
             .claude35Haiku, .claude35Haiku20241022,
             .claude3Opus, .claude3Opus20240229:
            return true
        case .gemini25Pro, .gemini25Flash,
             .gemini20FlashExp,
             .gemini15Pro, .gemini15Flash:
            return true
        default:
            return false
        }
    }

    /// Maximum input tokens (context window)
    public var maxInputTokens: Int {
        switch self {
        case .claudeOpus41, .claudeOpus4Latest, .claudeOpus420250514,
             .claudeSonnet45Latest, .claudeSonnet4520250514,
             .claudeSonnet4Latest, .claudeSonnet420250115,
             .claude37Sonnet, .claude37Sonnet20250219:
            return 200_000
        case .claudeHaiku45Latest, .claudeHaiku4520251001,
             .claude35Sonnet, .claude35Sonnet20241022, .claude35Sonnet20240620,
             .claude35Haiku, .claude35Haiku20241022,
             .claude3Opus, .claude3Opus20240229,
             .claude3Sonnet, .claude3Sonnet20240229,
             .claude3Haiku, .claude3Haiku20240307:
            return 200_000
        case .gpt4o, .gpt4o20240513:
            return 128_000
        case .gpt4oMini, .gpt4oMini20240718:
            return 128_000
        case .gpt4Turbo, .gpt4TurboPreview:
            return 128_000
        case .gpt4:
            return 8_192
        case .gpt35Turbo:
            return 16_385
        case .gemini25Pro:
            return 2_097_152
        case .gemini25Flash:
            return 1_048_576
        case .gemini20FlashExp:
            return 1_048_576
        case .gemini15Pro:
            return 2_097_152
        case .gemini15Flash:
            return 1_048_576
        case .sonar:
            return 127_072
        case .sonarPro:
            return 200_000
        case .sonarReasoning:
            return 127_072
        case .mistralLargeLatest, .mistralLarge2,
             .mistralMediumLatest, .mistralMedium3,
             .mistralSmallLatest, .mistralSmall3,
             .magistralSmall, .magistralMedium,
             .ministral3B, .ministral8B:
            return 128_000
        case .codestral:
            return 32_000
        case .deepseekChat:
            return 128_000 // DeepSeek Chat V3.2 has 128K context
        case .deepseekReasoner:
            return 64_000 // DeepSeek Reasoner R1 has 64K context (some sources say up to 128K)
        case .grok3, .grok3Mini:
            return 1_000_000 // 1M context
        case .grok2Vision:
            return 128_000
        case .grok4, .grok4Latest, .grokCodeFast:
            return 128_000 // Assumed based on typical model sizes
        case .grok2Image:
            return 1_024 // Max prompt length for image generation
        case .commandA, .commandAReasoning, .commandAVision,
             .commandRPlus08, .commandR08, .commandR7B,
             .commandRPlus, .commandR:
            return 256_000 // Command A and R families have 256K context
        case .commandATranslate:
            return 16_000 // Command A Translate has 16K context
        case .command, .commandLight:
            return 4_000 // Legacy Command models have 4K context
        }
    }

    /// Maximum output tokens
    public var maxOutputTokens: Int {
        switch self {
        case .claudeOpus41, .claudeOpus4Latest, .claudeOpus420250514,
             .claudeSonnet45Latest, .claudeSonnet4520250514,
             .claudeSonnet4Latest, .claudeSonnet420250115,
             .claude37Sonnet, .claude37Sonnet20250219,
             .claudeHaiku45Latest, .claudeHaiku4520251001:
            return 16_384
        case .claude35Sonnet, .claude35Sonnet20241022, .claude35Sonnet20240620,
             .claude35Haiku, .claude35Haiku20241022:
            return 8_192
        case .claude3Opus, .claude3Opus20240229,
             .claude3Sonnet, .claude3Sonnet20240229,
             .claude3Haiku, .claude3Haiku20240307:
            return 4_096
        case .gpt4o, .gpt4o20240513:
            return 16_384
        case .gpt4oMini, .gpt4oMini20240718:
            return 16_384
        case .gpt4Turbo, .gpt4TurboPreview:
            return 4_096
        case .gpt4, .gpt35Turbo:
            return 4_096
        case .gemini25Pro:
            return 65_536
        case .gemini25Flash:
            return 8_192
        case .gemini20FlashExp:
            return 8_192
        case .gemini15Pro:
            return 8_192
        case .gemini15Flash:
            return 8_192
        case .sonar, .sonarPro, .sonarReasoning:
            return 4_096
        case .mistralLargeLatest, .mistralLarge2,
             .mistralMediumLatest, .mistralMedium3,
             .mistralSmallLatest, .mistralSmall3,
             .codestral,
             .ministral3B, .ministral8B:
            return 8_192
        case .magistralSmall, .magistralMedium:
            return 32_768
        case .deepseekChat:
            return 8_192 // DeepSeek Chat typically outputs up to 8K tokens
        case .deepseekReasoner:
            return 32_768 // DeepSeek Reasoner can output up to 32K-64K tokens (including reasoning)
        case .grok4, .grok4Latest, .grok3, .grok3Mini, .grok2Vision, .grokCodeFast:
            return 8_192 // Typical output limit
        case .grok2Image:
            return 0 // Image generation doesn't produce text tokens
        case .commandA, .commandAReasoning, .commandAVision, .commandATranslate,
             .commandRPlus08, .commandR08, .commandR7B,
             .commandRPlus, .commandR,
             .command, .commandLight:
            return 8_192 // All Cohere models have 8K output limit
        }
    }
}
