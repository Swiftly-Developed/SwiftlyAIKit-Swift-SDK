import Foundation

/// Unified image generation response
///
/// Contains the generated images from any provider (OpenAI, Grok, Apple).
public struct ImageGenerationResponse: Sendable {
    /// Unique identifier for this generation
    public let id: String

    /// Timestamp when images were generated
    public let created: Date

    /// Provider that generated the images
    public let provider: ProviderType

    /// The model used for generation
    public let model: String

    /// Generated images
    public let images: [GeneratedImage]

    /// Usage statistics (if available)
    public let usage: ImageGenerationUsage?

    /// Initialize an image generation response
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this generation
    ///   - created: Timestamp when images were generated
    ///   - provider: Provider that generated the images
    ///   - model: The model used for generation
    ///   - images: Generated images
    ///   - usage: Usage statistics (if available)
    public init(
        id: String,
        created: Date,
        provider: ProviderType,
        model: String,
        images: [GeneratedImage],
        usage: ImageGenerationUsage? = nil
    ) {
        self.id = id
        self.created = created
        self.provider = provider
        self.model = model
        self.images = images
        self.usage = usage
    }
}

/// A single generated image
public struct GeneratedImage: Sendable {
    /// Index of this image in the batch (0-based)
    public let index: Int

    /// URL to the generated image (if responseFormat was .url)
    ///
    /// Note: URLs are typically temporary and expire within 1 hour.
    public let url: String?

    /// Base64-encoded image data (if responseFormat was .base64)
    public let base64Data: String?

    /// The prompt as revised by the model (DALL-E 3 may modify prompts)
    public let revisedPrompt: String?

    /// Size of the generated image
    public let size: ImageSize?

    /// Content type of the image (e.g., "image/png")
    public let contentType: String?

    /// Initialize a generated image
    ///
    /// - Parameters:
    ///   - index: Index of this image in the batch
    ///   - url: URL to the generated image
    ///   - base64Data: Base64-encoded image data
    ///   - revisedPrompt: The prompt as revised by the model
    ///   - size: Size of the generated image
    ///   - contentType: Content type of the image
    public init(
        index: Int,
        url: String? = nil,
        base64Data: String? = nil,
        revisedPrompt: String? = nil,
        size: ImageSize? = nil,
        contentType: String? = nil
    ) {
        self.index = index
        self.url = url
        self.base64Data = base64Data
        self.revisedPrompt = revisedPrompt
        self.size = size
        self.contentType = contentType
    }

    /// Check if this image has data available
    public var hasData: Bool {
        url != nil || base64Data != nil
    }
}

/// Usage statistics for image generation
public struct ImageGenerationUsage: Sendable {
    /// Number of images generated
    public let imagesGenerated: Int

    /// Cost in provider's currency unit (if available)
    public let cost: Double?

    /// Additional provider-specific usage data
    public let providerData: [String: AnyCodable]?

    /// Initialize usage statistics
    ///
    /// - Parameters:
    ///   - imagesGenerated: Number of images generated
    ///   - cost: Cost in provider's currency unit
    ///   - providerData: Additional provider-specific usage data
    public init(
        imagesGenerated: Int,
        cost: Double? = nil,
        providerData: [String: AnyCodable]? = nil
    ) {
        self.imagesGenerated = imagesGenerated
        self.cost = cost
        self.providerData = providerData
    }
}
