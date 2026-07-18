import Foundation

/// Protocol for providers that support image generation
///
/// Providers that can generate images from text prompts should conform to this protocol
/// in addition to ``ProviderProtocol``.
///
/// ## Overview
///
/// Three providers support image generation:
/// - **OpenAI** - DALL-E 3 and DALL-E 2
/// - **xAI Grok** - Grok 2 Image
/// - **Apple Intelligence** - Image Playground (on-device)
///
/// ## Conforming to ImageGenerationProvider
///
/// ```swift
/// extension OpenAIProvider: ImageGenerationProvider {
///     public var supportsImageGeneration: Bool { true }
///
///     public var imageGenerationModels: [String] {
///         ["dall-e-3", "dall-e-2"]
///     }
///
///     public func generateImage(
///         _ request: ImageGenerationRequest,
///         apiKey: String
///     ) async throws -> ImageGenerationResponse {
///         // 1. Transform request to provider format
///         // 2. Make HTTP call
///         // 3. Parse response
///         // 4. Return ImageGenerationResponse
///     }
/// }
/// ```
///
/// ## Usage
///
/// ```swift
/// let request = ImageGenerationRequest.dallE3(
///     prompt: "A sunset over mountains",
///     size: .square1024,
///     quality: .hd
/// )
///
/// let response = try await gateway.generateImage(request, using: .openai)
///
/// for image in response.images {
///     print("Generated: \(image.url ?? "data")")
/// }
/// ```
///
/// ## Topics
///
/// ### Protocol Requirements
/// - ``supportsImageGeneration``
/// - ``imageGenerationModels``
/// - ``generateImage(_:apiKey:)``
///
/// ### Helper Types
/// - ``ImageGenerationCapabilities``
///
/// ### Related Types
/// - ``ImageGenerationRequest``
/// - ``ImageGenerationResponse``
/// - ``AIGateway/generateImage(_:using:clientAPIKey:)``
///
/// ## See Also
/// - <doc:ImageGeneration>
/// - <doc:OpenAIGuide>
/// - <doc:GrokGuide>
/// - <doc:AppleIntelligenceGuide>
public protocol ImageGenerationProvider: Sendable {
    /// Whether this provider supports image generation
    var supportsImageGeneration: Bool { get }

    /// Available models for image generation
    ///
    /// Returns an array of model identifiers that can be used
    /// in `ImageGenerationRequest.model`.
    var imageGenerationModels: [String] { get }

    /// Generate images from a text prompt
    ///
    /// - Parameters:
    ///   - request: The image generation request
    ///   - apiKey: API key for authentication (ignored by Apple Intelligence)
    /// - Returns: Generated images
    /// - Throws: `AIError.unsupportedFeature` if provider doesn't support image generation
    func generateImage(
        _ request: ImageGenerationRequest,
        apiKey: String
    ) async throws -> ImageGenerationResponse
}

// MARK: - Default Implementation

extension ImageGenerationProvider {
    /// Default: Image generation not supported
    public var supportsImageGeneration: Bool { false }

    /// Default: No image generation models
    public var imageGenerationModels: [String] { [] }

    /// Default implementation throws unsupported error
    ///
    /// Providers that don't support image generation will use this default,
    /// which throws an appropriate error.
    public func generateImage(
        _ request: ImageGenerationRequest,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        // Get provider type if this conforms to ProviderProtocol
        let providerType: ProviderType
        if let provider = self as? ProviderProtocol {
            providerType = provider.providerType
        } else {
            providerType = .openai // Fallback
        }

        throw AIError.unsupportedFeature(
            feature: "image generation",
            provider: providerType
        )
    }
}

// MARK: - Image Generation Capabilities

/// Helper to check image generation capabilities
public struct ImageGenerationCapabilities: Sendable {
    /// Check if a provider supports image generation
    ///
    /// - Parameter provider: The provider type to check
    /// - Returns: True if the provider supports image generation
    public static func isSupported(by provider: ProviderType) -> Bool {
        switch provider {
        case .openai, .grok, .google, .appleIntelligence:
            return true
        case .anthropic, .perplexity, .cohere, .mistral, .deepseek, .groq, .openRouter, .ollama:
            return false
        }
    }

    /// Get available image generation models for a provider
    ///
    /// - Parameter provider: The provider type
    /// - Returns: Array of model identifiers
    public static func models(for provider: ProviderType) -> [String] {
        switch provider {
        case .openai:
            return ["dall-e-3", "dall-e-2"]
        case .grok:
            return ["grok-2-image"]
        case .google:
            return [
                "gemini-3.1-flash-image",
                "gemini-3.1-flash-lite-image",
                "gemini-3-pro-image",
                "gemini-2.5-flash-image",
                "imagen-4.0-generate-001",
                "imagen-4.0-fast-generate-001",
                "imagen-4.0-ultra-generate-001"
            ]
        case .appleIntelligence:
            return [
                "apple-image-animation",
                "apple-image-illustration",
                "apple-image-sketch"
            ]
        case .anthropic, .perplexity, .cohere, .mistral, .deepseek, .groq, .openRouter, .ollama:
            return []
        }
    }

    /// Get default image model for a provider
    ///
    /// - Parameter provider: The provider type
    /// - Returns: Default model identifier, or nil if not supported
    public static func defaultModel(for provider: ProviderType) -> String? {
        switch provider {
        case .openai:
            return "dall-e-3"
        case .grok:
            return "grok-2-image"
        case .google:
            return "gemini-3.1-flash-image"
        case .appleIntelligence:
            return "apple-image-animation"
        case .anthropic, .perplexity, .cohere, .mistral, .deepseek, .groq, .openRouter, .ollama:
            return nil
        }
    }

    /// Get supported sizes for a provider
    ///
    /// - Parameter provider: The provider type
    /// - Returns: Array of supported image sizes
    public static func supportedSizes(for provider: ProviderType) -> [ImageSize] {
        switch provider {
        case .openai:
            return ImageSize.allCases
        case .grok:
            return [.square1024]
        case .google:
            // Imagen/Gemini size by aspect ratio; every ImageSize maps to a supported ratio
            return ImageSize.allCases
        case .appleIntelligence:
            return [.square1024] // Image Playground handles sizing automatically
        case .anthropic, .perplexity, .cohere, .mistral, .deepseek, .groq, .openRouter, .ollama:
            return []
        }
    }
}
