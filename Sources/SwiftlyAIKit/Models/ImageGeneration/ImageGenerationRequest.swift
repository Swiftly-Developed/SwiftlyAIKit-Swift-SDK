import Foundation

/// Unified image generation request
///
/// This request type works across all image generation providers (OpenAI DALL-E, Grok, Apple Image Playground).
/// Provider-specific options can be passed via `providerOptions`.
///
/// ## Usage
///
/// ```swift
/// // Basic request
/// let request = ImageGenerationRequest(
///     prompt: "A serene mountain landscape at sunset",
///     model: "dall-e-3"
/// )
///
/// // Advanced request with options
/// let request = ImageGenerationRequest(
///     prompt: "A serene mountain landscape at sunset",
///     model: "dall-e-3",
///     numberOfImages: 1,
///     size: .landscape1792x1024,
///     quality: .hd,
///     style: .vivid
/// )
/// ```
public struct ImageGenerationRequest: Sendable {
    /// The text prompt describing the desired image
    public let prompt: String

    /// The model to use for generation
    ///
    /// Examples:
    /// - OpenAI: "dall-e-3", "dall-e-2"
    /// - Grok: "grok-2-image"
    /// - Apple: "apple-image-animation", "apple-image-illustration", "apple-image-sketch"
    public let model: String

    /// Number of images to generate (1-10, varies by provider)
    ///
    /// - DALL-E 3: Always 1
    /// - DALL-E 2: 1-10
    /// - Grok: 1
    /// - Apple: 1
    public let numberOfImages: Int

    /// Size of the generated image
    public let size: ImageSize

    /// Format for returning the generated image
    public let responseFormat: ImageResponseFormat

    /// Quality level (OpenAI DALL-E 3 only)
    public let quality: ImageQuality?

    /// Style of the generated image
    public let style: ImageStyle?

    /// Optional user identifier for tracking
    public let user: String?

    /// Provider-specific options
    ///
    /// Use this for features specific to certain providers that aren't
    /// covered by the standard parameters.
    public let providerOptions: [String: AnyCodable]?

    /// Initialize an image generation request
    ///
    /// - Parameters:
    ///   - prompt: The text prompt describing the desired image
    ///   - model: The model to use for generation
    ///   - numberOfImages: Number of images to generate (default: 1)
    ///   - size: Size of the generated image (default: 1024x1024)
    ///   - responseFormat: Format for returning images (default: url)
    ///   - quality: Quality level for DALL-E 3 (default: nil)
    ///   - style: Style of the generated image (default: nil)
    ///   - user: Optional user identifier for tracking
    ///   - providerOptions: Provider-specific options
    public init(
        prompt: String,
        model: String,
        numberOfImages: Int = 1,
        size: ImageSize = .square1024,
        responseFormat: ImageResponseFormat = .url,
        quality: ImageQuality? = nil,
        style: ImageStyle? = nil,
        user: String? = nil,
        providerOptions: [String: AnyCodable]? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.numberOfImages = numberOfImages
        self.size = size
        self.responseFormat = responseFormat
        self.quality = quality
        self.style = style
        self.user = user
        self.providerOptions = providerOptions
    }
}

// MARK: - Convenience Initializers

extension ImageGenerationRequest {
    /// Create a DALL-E 3 image request
    ///
    /// - Parameters:
    ///   - prompt: The text prompt describing the desired image
    ///   - size: Size of the generated image (default: 1024x1024)
    ///   - quality: Quality level (default: standard)
    ///   - style: Style of the generated image (default: vivid)
    /// - Returns: Configured ImageGenerationRequest
    public static func dallE3(
        prompt: String,
        size: ImageSize = .square1024,
        quality: ImageQuality = .standard,
        style: ImageStyle = .vivid
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            prompt: prompt,
            model: "dall-e-3",
            numberOfImages: 1, // DALL-E 3 only supports 1
            size: size,
            quality: quality,
            style: style
        )
    }

    /// Create a DALL-E 2 image request
    ///
    /// - Parameters:
    ///   - prompt: The text prompt describing the desired image
    ///   - numberOfImages: Number of images to generate (1-10)
    ///   - size: Size of the generated image (256, 512, or 1024 square)
    /// - Returns: Configured ImageGenerationRequest
    public static func dallE2(
        prompt: String,
        numberOfImages: Int = 1,
        size: ImageSize = .square1024
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            prompt: prompt,
            model: "dall-e-2",
            numberOfImages: min(max(numberOfImages, 1), 10),
            size: size
        )
    }

    /// Create a Grok image request
    ///
    /// - Parameters:
    ///   - prompt: The text prompt describing the desired image
    /// - Returns: Configured ImageGenerationRequest
    public static func grok(prompt: String) -> ImageGenerationRequest {
        ImageGenerationRequest(
            prompt: prompt,
            model: "grok-2-image",
            numberOfImages: 1,
            size: .square1024 // Grok only supports 1024x1024
        )
    }

    /// Create an Apple Image Playground request
    ///
    /// - Parameters:
    ///   - prompt: The text prompt describing the desired image
    ///   - style: Image Playground style (animation, illustration, sketch)
    /// - Returns: Configured ImageGenerationRequest
    public static func imagePlayground(
        prompt: String,
        style: ImageStyle = .animation
    ) -> ImageGenerationRequest {
        let model: String
        switch style {
        case .animation:
            model = "apple-image-animation"
        case .illustration:
            model = "apple-image-illustration"
        case .sketch:
            model = "apple-image-sketch"
        default:
            model = "apple-image-animation"
        }

        return ImageGenerationRequest(
            prompt: prompt,
            model: model,
            numberOfImages: 1,
            style: style
        )
    }
}
