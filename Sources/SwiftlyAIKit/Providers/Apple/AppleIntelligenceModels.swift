import Foundation

/// Apple Intelligence API Models
///
/// Types for Apple's on-device Foundation Models and Image Playground.
///
/// ## See Also
/// - ``AppleIntelligenceProvider``
/// - <doc:AppleIntelligenceGuide>

// MARK: - Apple Intelligence Models

/// Available Apple Intelligence models
public enum AppleIntelligenceModel: String, Codable, Sendable, CaseIterable {
    /// Apple Foundation Model for on-device text generation (iOS 26+, macOS 26+)
    case foundationModel = "apple-foundation-model"

    /// Apple Image Playground - Animation style (iOS 18.4+, macOS 15.4+)
    case imagePlaygroundAnimation = "apple-image-animation"

    /// Apple Image Playground - Illustration style (iOS 18.4+, macOS 15.4+)
    case imagePlaygroundIllustration = "apple-image-illustration"

    /// Apple Image Playground - Sketch style (iOS 18.4+, macOS 15.4+)
    case imagePlaygroundSketch = "apple-image-sketch"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .foundationModel:
            return "Apple Foundation Model"
        case .imagePlaygroundAnimation:
            return "Image Playground (Animation)"
        case .imagePlaygroundIllustration:
            return "Image Playground (Illustration)"
        case .imagePlaygroundSketch:
            return "Image Playground (Sketch)"
        }
    }

    /// Whether this is an image generation model
    public var isImageModel: Bool {
        switch self {
        case .foundationModel:
            return false
        case .imagePlaygroundAnimation, .imagePlaygroundIllustration, .imagePlaygroundSketch:
            return true
        }
    }

    /// Image Playground style for image models
    public var imagePlaygroundStyle: ImageStyle? {
        switch self {
        case .foundationModel:
            return nil
        case .imagePlaygroundAnimation:
            return .animation
        case .imagePlaygroundIllustration:
            return .illustration
        case .imagePlaygroundSketch:
            return .sketch
        }
    }
}

// MARK: - Capability Detection

/// Apple Intelligence capability detection
///
/// Use this to check availability before attempting to use Apple Intelligence features.
///
/// ## Usage
/// ```swift
/// if AppleIntelligenceCapabilities.foundationModelsAvailable {
///     // Use Foundation Models for text generation
/// }
///
/// if AppleIntelligenceCapabilities.imagePlaygroundAvailable {
///     // Use Image Playground for image generation
/// }
/// ```
public struct AppleIntelligenceCapabilities: Sendable {

    /// Check if Foundation Models framework is available
    ///
    /// Foundation Models requires:
    /// - iOS 26.0+ or macOS 26.0+
    /// - Apple Silicon (A17 Pro or later on iPhone, M1 or later on Mac)
    /// - Apple Intelligence enabled in Settings
    public static var foundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    /// Check if Image Playground is available
    ///
    /// Image Playground requires:
    /// - iOS 18.4+ or macOS 15.4+
    /// - Apple Silicon (A17 Pro or later on iPhone, M1 or later on Mac)
    /// - Apple Intelligence enabled in Settings
    public static var imagePlaygroundAvailable: Bool {
        #if canImport(ImagePlayground)
        if #available(iOS 18.4, macOS 15.4, *) {
            return true
        }
        #endif
        return false
    }

    /// Check if any Apple Intelligence feature is available
    public static var anyFeatureAvailable: Bool {
        foundationModelsAvailable || imagePlaygroundAvailable
    }

    /// Get list of available Apple Intelligence models
    public static var availableModels: [AppleIntelligenceModel] {
        var models: [AppleIntelligenceModel] = []

        if foundationModelsAvailable {
            models.append(.foundationModel)
        }

        if imagePlaygroundAvailable {
            models.append(contentsOf: [
                .imagePlaygroundAnimation,
                .imagePlaygroundIllustration,
                .imagePlaygroundSketch
            ])
        }

        return models
    }

    /// Human-readable description of available features
    public static var availabilityDescription: String {
        var features: [String] = []

        if foundationModelsAvailable {
            features.append("Foundation Models (text)")
        }

        if imagePlaygroundAvailable {
            features.append("Image Playground (images)")
        }

        if features.isEmpty {
            return "No Apple Intelligence features available on this device"
        }

        return "Available: \(features.joined(separator: ", "))"
    }
}

// MARK: - Error Types

/// Apple Intelligence specific errors
public enum AppleIntelligenceError: Error, Sendable {
    /// Feature not available on this device
    case featureNotAvailable(feature: String, requirement: String)

    /// Apple Intelligence not enabled in Settings
    case notEnabled

    /// Session creation failed
    case sessionCreationFailed(underlying: String)

    /// Generation failed
    case generationFailed(underlying: String)

    /// User cancelled the operation
    case userCancelled

    /// Invalid input
    case invalidInput(message: String)

    /// Human-readable error description
    public var localizedDescription: String {
        switch self {
        case .featureNotAvailable(let feature, let requirement):
            return "\(feature) is not available. Requires \(requirement)."
        case .notEnabled:
            return "Apple Intelligence is not enabled. Enable it in Settings > Apple Intelligence & Siri."
        case .sessionCreationFailed(let underlying):
            return "Failed to create Apple Intelligence session: \(underlying)"
        case .generationFailed(let underlying):
            return "Generation failed: \(underlying)"
        case .userCancelled:
            return "Operation was cancelled by the user."
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}
