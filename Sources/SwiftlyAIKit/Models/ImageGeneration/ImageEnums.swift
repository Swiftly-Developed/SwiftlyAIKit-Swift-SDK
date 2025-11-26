import Foundation

// MARK: - Image Size

/// Standard image sizes for generation
///
/// Different providers support different sizes. Use `supportedBy(_:)` to check compatibility.
public enum ImageSize: String, Codable, Sendable, CaseIterable {
    /// 256x256 pixels (DALL-E 2 only)
    case square256 = "256x256"

    /// 512x512 pixels (DALL-E 2 only)
    case square512 = "512x512"

    /// 1024x1024 pixels (DALL-E 2, DALL-E 3, Grok)
    case square1024 = "1024x1024"

    /// 1792x1024 pixels landscape (DALL-E 3 only)
    case landscape1792x1024 = "1792x1024"

    /// 1024x1792 pixels portrait (DALL-E 3 only)
    case portrait1024x1792 = "1024x1792"

    /// Width in pixels
    public var width: Int {
        switch self {
        case .square256: return 256
        case .square512: return 512
        case .square1024: return 1024
        case .landscape1792x1024: return 1792
        case .portrait1024x1792: return 1024
        }
    }

    /// Height in pixels
    public var height: Int {
        switch self {
        case .square256: return 256
        case .square512: return 512
        case .square1024: return 1024
        case .landscape1792x1024: return 1024
        case .portrait1024x1792: return 1792
        }
    }

    /// Check if this size is supported by a specific provider
    public func supportedBy(_ provider: ProviderType) -> Bool {
        switch provider {
        case .openai:
            // DALL-E 3 supports: 1024x1024, 1792x1024, 1024x1792
            // DALL-E 2 supports: 256x256, 512x512, 1024x1024
            return true // All sizes supported by at least one DALL-E model
        case .grok:
            // Grok only supports 1024x1024
            return self == .square1024
        case .appleIntelligence:
            // Image Playground handles sizing automatically
            return true
        default:
            return false
        }
    }
}

// MARK: - Image Response Format

/// Format for returning generated images
public enum ImageResponseFormat: String, Codable, Sendable {
    /// Return image as a URL (temporary, typically expires in 1 hour)
    case url

    /// Return image as base64-encoded data
    case base64 = "b64_json"
}

// MARK: - Image Quality

/// Quality level for generated images
///
/// Only supported by OpenAI DALL-E 3.
public enum ImageQuality: String, Codable, Sendable, CaseIterable {
    /// Standard quality - faster, lower cost
    case standard

    /// HD quality - more detailed, higher cost (DALL-E 3 only)
    case hd
}

// MARK: - Image Style

/// Style for generated images
///
/// Different providers support different styles.
public enum ImageStyle: String, Codable, Sendable {
    // OpenAI DALL-E styles
    /// Vivid - hyper-real, dramatic (OpenAI default)
    case vivid

    /// Natural - more natural, less hyper-real (OpenAI)
    case natural

    // Apple Image Playground styles
    /// Animation style (Apple Image Playground)
    case animation

    /// Illustration style (Apple Image Playground)
    case illustration

    /// Sketch style (Apple Image Playground)
    case sketch

    /// Check if this style is supported by a specific provider
    public func supportedBy(_ provider: ProviderType) -> Bool {
        switch provider {
        case .openai:
            return self == .vivid || self == .natural
        case .appleIntelligence:
            return self == .animation || self == .illustration || self == .sketch
        case .grok:
            // Grok doesn't support style parameter
            return false
        default:
            return false
        }
    }
}
