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

    // MARK: - OpenAI Models (placeholders for future implementation)

    /// GPT-4 Turbo
    case gpt4Turbo = "gpt-4-turbo"

    /// GPT-4
    case gpt4 = "gpt-4"

    /// GPT-3.5 Turbo
    case gpt35Turbo = "gpt-3.5-turbo"

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

        case .gpt4Turbo, .gpt4, .gpt35Turbo:
            return .openai
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
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gpt4: return "GPT-4"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
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
        case .gpt4Turbo, .gpt4:
            return true
        case .gpt35Turbo:
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
        case .gpt4Turbo:
            return 128_000
        case .gpt4:
            return 8_192
        case .gpt35Turbo:
            return 16_385
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
        case .gpt4Turbo:
            return 4_096
        case .gpt4, .gpt35Turbo:
            return 4_096
        }
    }
}
