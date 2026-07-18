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

    // MARK: - Capabilities

    /// Whether tool / function calling is supported on this device
    ///
    /// Tool calling is wired through Apple's Foundation Models `Tool` API, which requires
    /// iOS 26+ / macOS 26+ with Apple Intelligence enabled. On older systems (or when the model
    /// is unavailable) this is `false` and any ``AIRequest/tools`` are ignored.
    public var supportsTools: Bool {
        AppleIntelligenceCapabilities.foundationModelsAvailable
    }

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

    // MARK: - Tool Call Mapping

    /// Build a neutral tool-use ``AIResponse`` from a captured on-device tool invocation.
    ///
    /// Foundation Models executes registered tools in-process. SwiftlyAIKit instead surfaces the
    /// invocation to the caller (parity with the HTTP providers), so a captured call becomes a
    /// `.toolCall` content block with a `.toolUse` stop reason. Kept free of any Foundation Models
    /// types so it compiles — and is unit-testable — on every platform.
    func makeToolUseResponse(name: String, argumentsJSON: String) -> AIResponse {
        let call = AIToolCall(
            id: "apple-fm-tool-\(UUID().uuidString.prefix(8))",
            name: name,
            arguments: argumentsJSON
        )
        return AIResponse(
            id: "apple-fm-\(UUID().uuidString.prefix(8))",
            model: AppleIntelligenceModel.foundationModel.rawValue,
            message: AIMessage(role: .assistant, content: [.toolCall(call)]),
            stopReason: .toolUse,
            usage: nil,
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

        // Build the prompt from messages
        let prompt = buildPromptFromMessages(request)

        // Register neutral tools with the on-device session when supplied. The recorder captures the
        // first tool the model tries to invoke so we can surface it to the caller as `.toolUse`
        // (parity with the HTTP providers) instead of executing it in-process.
        let recorder = AppleToolCallRecorder()
        let session = try makeSession(for: request, recorder: recorder)

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
            // A registered tool being invoked aborts generation; surface it as a neutral tool call.
            if let call = recorder.capturedCall {
                return makeToolUseResponse(name: call.name, argumentsJSON: call.argumentsJSON)
            }
            // Map FoundationModels errors to our error types
            throw Self.mapFoundationModelsError(error)
        }
    }

    /// Build a Foundation Models session, registering intercepting tools when the request carries
    /// any. With no tools this is identical to `LanguageModelSession()` — behaviour is unchanged.
    @available(iOS 26.0, macOS 26.0, *)
    private func makeSession(for request: AIRequest, recorder: AppleToolCallRecorder) throws -> LanguageModelSession {
        guard let tools = request.tools, !tools.isEmpty else {
            return LanguageModelSession()
        }
        let fmTools: [any Tool] = try tools.map { tool in
            InterceptingTool(
                name: tool.name,
                description: tool.description,
                parameters: try Self.makeGenerationSchema(for: tool),
                recorder: recorder
            )
        }
        return LanguageModelSession(tools: fmTools)
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func streamMessageWithFoundationModels(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponse, Error> {
        // Check if the model is available on this device
        guard await Self.isFoundationModelAvailable() else {
            throw AppleIntelligenceError.notEnabled
        }

        return AsyncThrowingStream { continuation in
            Task {
                let recorder = AppleToolCallRecorder()
                do {
                    let session = try makeSession(for: request, recorder: recorder)
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
                    // A registered tool being invoked aborts generation; surface the neutral tool
                    // call as a terminal `.toolUse` chunk rather than an error.
                    if let call = recorder.capturedCall {
                        continuation.yield(makeToolUseResponse(name: call.name, argumentsJSON: call.argumentsJSON))
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: Self.mapFoundationModelsError(error))
                    }
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

    // MARK: - Tool Schema Translation

    /// Translate a neutral ``AITool`` into a Foundation Models ``GenerationSchema``.
    ///
    /// Because `AITool` schemas are defined at runtime (JSON-Schema dictionaries) rather than at
    /// compile time, this uses `DynamicGenerationSchema` — the runtime counterpart of the
    /// `@Generable` macro — rather than a statically generated schema.
    @available(iOS 26.0, macOS 26.0, *)
    static func makeGenerationSchema(for tool: AITool) throws -> GenerationSchema {
        let root = makeDynamicSchema(
            for: tool.parameters,
            name: tool.name,
            description: tool.description
        )
        return try GenerationSchema(root: root, dependencies: [])
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func makeDynamicSchema(
        for parameters: AIToolParameters,
        name: String,
        description: String?
    ) -> DynamicGenerationSchema {
        let required = Set(parameters.required ?? [])
        let properties = parameters.properties.map { key, value in
            DynamicGenerationSchema.Property(
                name: key,
                description: value.description,
                schema: makeDynamicSchema(for: value, name: key),
                isOptional: !required.contains(key)
            )
        }
        return DynamicGenerationSchema(name: name, description: description, properties: properties)
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func makeDynamicSchema(for property: AIToolProperty, name: String) -> DynamicGenerationSchema {
        switch property.type {
        case "integer":
            return DynamicGenerationSchema(type: Int.self)
        case "number":
            return DynamicGenerationSchema(type: Double.self)
        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)
        case "array":
            return DynamicGenerationSchema(arrayOf: makeDynamicSchema(forItems: property.items))
        case "object":
            let required = Set(property.required ?? [])
            let nested = (property.properties ?? [:]).map { key, value in
                DynamicGenerationSchema.Property(
                    name: key,
                    description: value.description,
                    schema: makeDynamicSchema(for: value, name: key),
                    isOptional: !required.contains(key)
                )
            }
            return DynamicGenerationSchema(name: name, description: property.description, properties: nested)
        default:
            // "string" and anything unrecognised → string (with an enum constraint when present).
            if let enumValues = property.enum, !enumValues.isEmpty {
                return DynamicGenerationSchema(name: name, description: property.description, anyOf: enumValues)
            }
            return DynamicGenerationSchema(type: String.self)
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func makeDynamicSchema(forItems items: AIToolPropertyItems?) -> DynamicGenerationSchema {
        guard let items else { return DynamicGenerationSchema(type: String.self) }
        switch items.type {
        case "integer":
            return DynamicGenerationSchema(type: Int.self)
        case "number":
            return DynamicGenerationSchema(type: Double.self)
        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)
        case "object":
            let required = Set(items.required ?? [])
            let nested = (items.properties ?? [:]).map { key, value in
                DynamicGenerationSchema.Property(
                    name: key,
                    description: value.description,
                    schema: makeDynamicSchema(for: value, name: key),
                    isOptional: !required.contains(key)
                )
            }
            return DynamicGenerationSchema(name: "item", description: items.description, properties: nested)
        default:
            return DynamicGenerationSchema(type: String.self)
        }
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

// MARK: - Foundation Models Tool Bridging

#if canImport(FoundationModels)
import FoundationModels

/// Captures the first tool the on-device model tries to invoke during a generation.
///
/// Foundation Models runs registered tools in-process; to surface the call to the SDK caller we
/// record the invocation from ``InterceptingTool/call(arguments:)`` and abort generation, then
/// rebuild it as a neutral `.toolCall` response.
final class AppleToolCallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCall: (name: String, argumentsJSON: String)?

    func record(name: String, argumentsJSON: String) {
        lock.lock()
        defer { lock.unlock() }
        if storedCall == nil {
            storedCall = (name, argumentsJSON)
        }
    }

    var capturedCall: (name: String, argumentsJSON: String)? {
        lock.lock()
        defer { lock.unlock() }
        return storedCall
    }
}

/// Sentinel thrown from an intercepting tool's `call` to stop generation once the model requests a
/// tool. The recorded invocation is then surfaced as a neutral `.toolUse` response.
enum AppleToolInterception: Error {
    case toolRequested
}

/// A Foundation Models ``Tool`` that records the model's invocation and aborts, rather than
/// executing anything, so the SDK can hand the tool call back to the caller.
@available(iOS 26.0, macOS 26.0, *)
struct InterceptingTool: Tool {
    typealias Arguments = GeneratedContent
    typealias Output = String

    let name: String
    let description: String
    let parameters: GenerationSchema
    let recorder: AppleToolCallRecorder

    func call(arguments: GeneratedContent) async throws -> String {
        recorder.record(name: name, argumentsJSON: arguments.jsonString)
        throw AppleToolInterception.toolRequested
    }
}
#endif
