import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(ImagePlayground)
import ImagePlayground
#endif

/// Apple Intelligence provider for on-device AI
///
/// On-device AI with perfect privacy - no network required, completely free.
///
/// ## Topics
///
/// ### ProviderProtocol
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
///
/// ### ImageGenerationProvider
/// - ``supportsImageGeneration``
/// - ``imageGenerationModels``
/// - ``generateImage(_:apiKey:)``
///
/// ## See Also
/// - <doc:AppleIntelligenceGuide>
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
        // Check if the model is available on this device
        guard await Self.isFoundationModelAvailable() else {
            throw AppleIntelligenceError.notEnabled
        }

        // Create a language model session
        let session = LanguageModelSession()

        // Build the prompt from messages
        let prompt = buildPromptFromMessages(request)

        do {
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
        } catch {
            // Map FoundationModels errors to our error types
            throw Self.mapFoundationModelsError(error)
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func streamMessageWithFoundationModels(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponse, Error> {
        // Check if the model is available on this device
        guard await Self.isFoundationModelAvailable() else {
            throw AppleIntelligenceError.notEnabled
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession()
                    let prompt = buildPromptFromMessages(request)

                    var previousContent = ""

                    for try await partial in session.streamResponse(to: prompt) {
                        // Apple's streamResponse returns accumulated content, not deltas
                        // We need to extract just the new text (delta) for proper streaming
                        let currentContent = partial.content
                        let delta: String
                        if currentContent.hasPrefix(previousContent) {
                            delta = String(currentContent.dropFirst(previousContent.count))
                        } else {
                            // Fallback if content doesn't match expected pattern
                            delta = currentContent
                        }
                        previousContent = currentContent

                        // Only yield if there's new content
                        guard !delta.isEmpty else { continue }

                        let message = AIMessage(
                            role: .assistant,
                            content: [.text(delta)]
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

                    // Final response with stop reason (empty content, just signals completion)
                    let finalMessage = AIMessage(
                        role: .assistant,
                        content: [.text("")]
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
                    continuation.finish(throwing: Self.mapFoundationModelsError(error))
                }
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func isFoundationModelAvailable() async -> Bool {
        // Check if the system language model is available
        // This returns false if Apple Intelligence is not enabled or assets aren't downloaded
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            return true
        case .unavailable:
            return false
        @unknown default:
            return false
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func mapFoundationModelsError(_ error: Error) -> Error {
        let errorDescription = String(describing: error)

        if errorDescription.contains("unavailable") || errorDescription.contains("assetsUnavailable") {
            return AppleIntelligenceError.notEnabled
        } else if errorDescription.contains("cancelled") || errorDescription.contains("Canceled") {
            return AppleIntelligenceError.userCancelled
        } else {
            return AppleIntelligenceError.generationFailed(underlying: errorDescription)
        }
    }

    private func buildPromptFromMessages(_ request: AIRequest) -> String {
        // For Apple's Foundation Models, we only send the last user message
        // The model doesn't handle multi-turn conversations well when concatenated as text
        // Each request should be treated as a single-turn interaction

        // Get the last user message
        if let lastUserMessage = request.messages.last(where: { $0.role == .user }) {
            let text = lastUserMessage.content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            // Prepend system prompt if present
            if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
                return "\(systemPrompt)\n\n\(text)"
            }

            return text
        }

        // Fallback: concatenate all messages (shouldn't normally reach here)
        var parts: [String] = []

        // Add system prompt if present
        if let systemPrompt = request.systemPrompt {
            parts.append(systemPrompt)
        }

        // Add conversation messages
        for message in request.messages {
            let text = message.content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            parts.append(text)
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
