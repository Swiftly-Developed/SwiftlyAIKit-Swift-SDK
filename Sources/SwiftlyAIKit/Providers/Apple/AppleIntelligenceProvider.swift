import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(ImagePlayground)
import ImagePlayground
#endif

/// Apple Intelligence provider for on-device AI
///
/// This provider integrates with Apple's on-device AI capabilities:
/// - **Foundation Models** (iOS 26+, macOS 26+): Text generation using Apple's on-device LLM
/// - **Image Playground** (iOS 18.4+, macOS 15.4+): Image generation with animation, illustration, and sketch styles
///
/// ## Key Characteristics
/// - **On-device**: All processing happens locally, no data sent to external servers
/// - **No API key required**: Uses device capabilities, not cloud services
/// - **Privacy-focused**: Data never leaves the device
///
/// ## Usage
/// ```swift
/// let provider = AppleIntelligenceProvider()
///
/// // Check availability
/// if provider.supportsImageGeneration {
///     let request = ImageGenerationRequest.imagePlayground(
///         prompt: "A happy golden retriever",
///         style: .animation
///     )
///     let response = try await provider.generateImage(request, apiKey: "")
/// }
/// ```
///
/// ## Platform Requirements
/// | Feature | iOS | macOS | Hardware |
/// |---------|-----|-------|----------|
/// | Foundation Models | 26.0+ | 26.0+ | A17 Pro+ or Apple Silicon |
/// | Image Playground | 18.4+ | 15.4+ | A17 Pro+ or Apple Silicon |
public struct AppleIntelligenceProvider: ProviderProtocol, ImageGenerationProvider {
    public let providerType: ProviderType = .appleIntelligence

    /// Initialize Apple Intelligence provider
    public init() {}

    // MARK: - ProviderProtocol Implementation

    /// Send a message using Foundation Models
    ///
    /// - Note: Requires iOS 26+ or macOS 26+ with Apple Silicon
    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return try await sendMessageWithFoundationModels(request)
        }
        #endif

        throw AIError.unsupportedFeature(
            feature: "Foundation Models text generation",
            provider: .appleIntelligence
        )
    }

    /// Stream a message using Foundation Models
    ///
    /// - Note: Requires iOS 26+ or macOS 26+ with Apple Silicon
    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                #if canImport(FoundationModels)
                if #available(iOS 26.0, macOS 26.0, *) {
                    do {
                        let stream = try await streamMessageWithFoundationModels(request)
                        for try await response in stream {
                            continuation.yield(response)
                        }
                        continuation.finish()
                        return
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }
                #endif

                continuation.finish(throwing: AIError.unsupportedFeature(
                    feature: "Foundation Models streaming",
                    provider: .appleIntelligence
                ))
            }
        }
    }

    // MARK: - ImageGenerationProvider Implementation

    /// Whether image generation is supported on this device
    public var supportsImageGeneration: Bool {
        AppleIntelligenceCapabilities.imagePlaygroundAvailable
    }

    /// Available image generation models
    public var imageGenerationModels: [String] {
        guard supportsImageGeneration else { return [] }
        return [
            AppleIntelligenceModel.imagePlaygroundAnimation.rawValue,
            AppleIntelligenceModel.imagePlaygroundIllustration.rawValue,
            AppleIntelligenceModel.imagePlaygroundSketch.rawValue
        ]
    }

    /// Generate images using Image Playground
    ///
    /// - Note: Requires iOS 18.4+ or macOS 15.4+ with Apple Silicon
    /// - Note: The apiKey parameter is ignored (on-device processing)
    public func generateImage(
        _ request: ImageGenerationRequest,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        #if canImport(ImagePlayground)
        if #available(iOS 18.4, macOS 15.4, *) {
            return try await generateImageWithImagePlayground(request)
        }
        #endif

        throw AIError.unsupportedFeature(
            feature: "Image Playground",
            provider: .appleIntelligence
        )
    }

    // MARK: - Foundation Models Implementation

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func sendMessageWithFoundationModels(_ request: AIRequest) async throws -> AIResponse {
        // Create a language model session
        let session = LanguageModelSession()

        // Build the prompt from messages
        let prompt = buildPromptFromMessages(request)

        // Generate response
        let response = try await session.respond(to: prompt)

        // Map to AIResponse
        let message = AIMessage(
            role: .assistant,
            content: [.text(response.content)]
        )

        return AIResponse(
            id: "apple-fm-\(UUID().uuidString.prefix(8))",
            model: AppleIntelligenceModel.foundationModel.rawValue,
            message: message,
            stopReason: .endTurn,
            usage: nil,
            provider: .appleIntelligence
        )
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func streamMessageWithFoundationModels(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession()
                    let prompt = buildPromptFromMessages(request)

                    var accumulatedContent = ""

                    for try await partial in session.streamResponse(to: prompt) {
                        accumulatedContent = partial.content

                        let message = AIMessage(
                            role: .assistant,
                            content: [.text(accumulatedContent)]
                        )

                        let response = AIResponse(
                            id: "apple-fm-\(UUID().uuidString.prefix(8))",
                            model: AppleIntelligenceModel.foundationModel.rawValue,
                            message: message,
                            stopReason: nil,
                            usage: nil,
                            provider: .appleIntelligence
                        )

                        continuation.yield(response)
                    }

                    // Final response with stop reason
                    let finalMessage = AIMessage(
                        role: .assistant,
                        content: [.text(accumulatedContent)]
                    )

                    let finalResponse = AIResponse(
                        id: "apple-fm-\(UUID().uuidString.prefix(8))",
                        model: AppleIntelligenceModel.foundationModel.rawValue,
                        message: finalMessage,
                        stopReason: .endTurn,
                        usage: nil,
                        provider: .appleIntelligence
                    )

                    continuation.yield(finalResponse)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildPromptFromMessages(_ request: AIRequest) -> String {
        var parts: [String] = []

        // Add system prompt if present
        if let systemPrompt = request.systemPrompt {
            parts.append("System: \(systemPrompt)")
        }

        // Add conversation messages
        for message in request.messages {
            let role = message.role.rawValue.capitalized
            let text = message.content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            parts.append("\(role): \(text)")
        }

        return parts.joined(separator: "\n\n")
    }
    #endif

    // MARK: - Image Playground Implementation

    // Note: Image Playground API (ImageCreator) is only available in Xcode 16+ with iOS 18.4+/macOS 15.4+ SDK
    // The implementation below provides a placeholder that will be activated when the framework is available
    // The actual API usage will need to be updated once the SDK is available for testing

    #if canImport(ImagePlayground)
    @available(iOS 18.4, macOS 15.4, *)
    private func generateImageWithImagePlayground(_ request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        // Image Playground provides a SwiftUI-based interface for image generation
        // The ImageCreator API requires SwiftUI context and user interaction
        // For programmatic generation, we would need to use the ImagePlayground sheet presentation

        // Since Image Playground is primarily a SwiftUI component that presents a UI,
        // programmatic image generation without UI is not directly supported.
        // Apps should use ImagePlaygroundView or the .imagePlaygroundSheet modifier.

        throw AIError.unsupportedFeature(
            feature: "Programmatic Image Playground generation (use ImagePlaygroundView in SwiftUI instead)",
            provider: .appleIntelligence
        )
    }
    #endif
}
