import Foundation

/// Google Gemini API Models
///
/// Provider-specific types for Gemini's GenerateContent API.
///
/// ## See Also
/// - ``GeminiProvider``
/// - <doc:GeminiGuide>

// MARK: - Content and Parts

/// Content part for Gemini API
public enum GeminiPart: Codable, Sendable, Equatable {
    case text(String)
    case inlineData(mimeType: String, data: String)
    case fileData(mimeType: String, fileUri: String)
    case functionCall(name: String, args: [String: AnyCodable])
    case functionResponse(name: String, response: [String: AnyCodable])

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData
        case fileData
        case functionCall
        case functionResponse
    }

    enum InlineDataKeys: String, CodingKey {
        case mimeType
        case data
    }

    enum FileDataKeys: String, CodingKey {
        case mimeType
        case fileUri
    }

    enum FunctionCallKeys: String, CodingKey {
        case name
        case args
    }

    enum FunctionResponseKeys: String, CodingKey {
        case name
        case response
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let text = try? container.decode(String.self, forKey: .text) {
            self = .text(text)
        } else if container.contains(.inlineData) {
            let dataContainer = try container.nestedContainer(keyedBy: InlineDataKeys.self, forKey: .inlineData)
            let mimeType = try dataContainer.decode(String.self, forKey: .mimeType)
            let data = try dataContainer.decode(String.self, forKey: .data)
            self = .inlineData(mimeType: mimeType, data: data)
        } else if container.contains(.fileData) {
            let dataContainer = try container.nestedContainer(keyedBy: FileDataKeys.self, forKey: .fileData)
            let mimeType = try dataContainer.decode(String.self, forKey: .mimeType)
            let fileUri = try dataContainer.decode(String.self, forKey: .fileUri)
            self = .fileData(mimeType: mimeType, fileUri: fileUri)
        } else if container.contains(.functionCall) {
            let callContainer = try container.nestedContainer(keyedBy: FunctionCallKeys.self, forKey: .functionCall)
            let name = try callContainer.decode(String.self, forKey: .name)
            let args = try callContainer.decode([String: AnyCodable].self, forKey: .args)
            self = .functionCall(name: name, args: args)
        } else if container.contains(.functionResponse) {
            let respContainer = try container.nestedContainer(keyedBy: FunctionResponseKeys.self, forKey: .functionResponse)
            let name = try respContainer.decode(String.self, forKey: .name)
            let response = try respContainer.decode([String: AnyCodable].self, forKey: .response)
            self = .functionResponse(name: name, response: response)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown part type")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)

        case .inlineData(let mimeType, let data):
            var dataContainer = container.nestedContainer(keyedBy: InlineDataKeys.self, forKey: .inlineData)
            try dataContainer.encode(mimeType, forKey: .mimeType)
            try dataContainer.encode(data, forKey: .data)

        case .fileData(let mimeType, let fileUri):
            var dataContainer = container.nestedContainer(keyedBy: FileDataKeys.self, forKey: .fileData)
            try dataContainer.encode(mimeType, forKey: .mimeType)
            try dataContainer.encode(fileUri, forKey: .fileUri)

        case .functionCall(let name, let args):
            var callContainer = container.nestedContainer(keyedBy: FunctionCallKeys.self, forKey: .functionCall)
            try callContainer.encode(name, forKey: .name)
            try callContainer.encode(args, forKey: .args)

        case .functionResponse(let name, let response):
            var respContainer = container.nestedContainer(keyedBy: FunctionResponseKeys.self, forKey: .functionResponse)
            try respContainer.encode(name, forKey: .name)
            try respContainer.encode(response, forKey: .response)
        }
    }
}

/// Content for Gemini API (message content)
public struct GeminiContent: Codable, Sendable, Equatable {
    public let role: String?
    public let parts: [GeminiPart]

    public init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

// MARK: - Function Calling

/// Function declaration for Gemini API
public struct GeminiFunctionDeclaration: Codable, Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: GeminiSchema?

    public init(name: String, description: String, parameters: GeminiSchema? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// JSON Schema for function parameters
public struct GeminiSchema: Codable, Sendable, Equatable {
    public let type: String
    public let properties: [String: GeminiSchemaProperty]?
    public let required: [String]?

    public init(type: String, properties: [String: GeminiSchemaProperty]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// Schema property definition
public struct GeminiSchemaProperty: Codable, Sendable, Equatable {
    public let type: String
    public let description: String?
    public let format: String?
    public let items: GeminiSchemaItems?
    public let `enum`: [String]?
    /// Nested property definitions (for object-typed properties)
    public let properties: [String: GeminiSchemaProperty]?
    /// Required nested property names (for object-typed properties)
    public let required: [String]?

    public init(
        type: String,
        description: String? = nil,
        format: String? = nil,
        items: GeminiSchemaItems? = nil,
        enumValues: [String]? = nil,
        properties: [String: GeminiSchemaProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.format = format
        self.items = items
        self.enum = enumValues
        self.properties = properties
        self.required = required
    }
}

/// Schema items for array types
///
/// Supports arrays of primitives (type only) and arrays of objects (nested
/// `properties`/`required`).
public struct GeminiSchemaItems: Codable, Sendable, Equatable {
    public let type: String
    /// Nested property definitions (for arrays of objects)
    public let properties: [String: GeminiSchemaProperty]?
    /// Required nested property names (for arrays of objects)
    public let required: [String]?

    public init(
        type: String,
        properties: [String: GeminiSchemaProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// Tool configuration for Gemini API
public struct GeminiTool: Codable, Sendable, Equatable {
    public let functionDeclarations: [GeminiFunctionDeclaration]

    public init(functionDeclarations: [GeminiFunctionDeclaration]) {
        self.functionDeclarations = functionDeclarations
    }
}

/// Tool configuration settings
public struct GeminiToolConfig: Codable, Sendable, Equatable {
    public let functionCallingConfig: GeminiFunctionCallingConfig

    public init(functionCallingConfig: GeminiFunctionCallingConfig) {
        self.functionCallingConfig = functionCallingConfig
    }
}

/// Function calling mode configuration
public struct GeminiFunctionCallingConfig: Codable, Sendable, Equatable {
    public let mode: Mode
    public let allowedFunctionNames: [String]?

    public enum Mode: String, Codable, Sendable {
        case auto = "AUTO"
        case any = "ANY"
        case none = "NONE"
    }

    public init(mode: Mode, allowedFunctionNames: [String]? = nil) {
        self.mode = mode
        self.allowedFunctionNames = allowedFunctionNames
    }
}

// MARK: - Safety Settings

/// Safety setting for content filtering
public struct GeminiSafetySetting: Codable, Sendable, Equatable {
    public let category: HarmCategory
    public let threshold: HarmBlockThreshold

    public enum HarmCategory: String, Codable, Sendable {
        case harassment = "HARM_CATEGORY_HARASSMENT"
        case hateSpeech = "HARM_CATEGORY_HATE_SPEECH"
        case sexuallyExplicit = "HARM_CATEGORY_SEXUALLY_EXPLICIT"
        case dangerousContent = "HARM_CATEGORY_DANGEROUS_CONTENT"
    }

    public enum HarmBlockThreshold: String, Codable, Sendable {
        case blockNone = "BLOCK_NONE"
        case blockOnlyHigh = "BLOCK_ONLY_HIGH"
        case blockMediumAndAbove = "BLOCK_MEDIUM_AND_ABOVE"
        case blockLowAndAbove = "BLOCK_LOW_AND_ABOVE"
    }

    public init(category: HarmCategory, threshold: HarmBlockThreshold) {
        self.category = category
        self.threshold = threshold
    }
}

// MARK: - Generation Config

/// Generation configuration for Gemini API
public struct GeminiGenerationConfig: Codable, Sendable, Equatable {
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let maxOutputTokens: Int?
    public let stopSequences: [String]?
    public let responseMimeType: String?
    public let responseSchema: GeminiSchema?

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        maxOutputTokens: Int? = nil,
        stopSequences: [String]? = nil,
        responseMimeType: String? = nil,
        responseSchema: GeminiSchema? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxOutputTokens = maxOutputTokens
        self.stopSequences = stopSequences
        self.responseMimeType = responseMimeType
        self.responseSchema = responseSchema
    }
}

// MARK: - Request/Response

/// Gemini API request
public struct GeminiRequest: Codable, Sendable {
    public let contents: [GeminiContent]
    public let systemInstruction: GeminiContent?
    public let generationConfig: GeminiGenerationConfig?
    public let safetySettings: [GeminiSafetySetting]?
    public let tools: [GeminiTool]?
    public let toolConfig: GeminiToolConfig?

    public init(
        contents: [GeminiContent],
        systemInstruction: GeminiContent? = nil,
        generationConfig: GeminiGenerationConfig? = nil,
        safetySettings: [GeminiSafetySetting]? = nil,
        tools: [GeminiTool]? = nil,
        toolConfig: GeminiToolConfig? = nil
    ) {
        self.contents = contents
        self.systemInstruction = systemInstruction
        self.generationConfig = generationConfig
        self.safetySettings = safetySettings
        self.tools = tools
        self.toolConfig = toolConfig
    }
}

/// Gemini API response
public struct GeminiResponse: Codable, Sendable {
    public let candidates: [GeminiCandidate]
    public let usageMetadata: GeminiUsageMetadata?
    public let modelVersion: String?

    public init(candidates: [GeminiCandidate], usageMetadata: GeminiUsageMetadata? = nil, modelVersion: String? = nil) {
        self.candidates = candidates
        self.usageMetadata = usageMetadata
        self.modelVersion = modelVersion
    }
}

/// Response candidate
public struct GeminiCandidate: Codable, Sendable {
    public let content: GeminiContent
    public let finishReason: String?
    public let safetyRatings: [GeminiSafetyRating]?
    public let citationMetadata: GeminiCitationMetadata?

    public init(
        content: GeminiContent,
        finishReason: String? = nil,
        safetyRatings: [GeminiSafetyRating]? = nil,
        citationMetadata: GeminiCitationMetadata? = nil
    ) {
        self.content = content
        self.finishReason = finishReason
        self.safetyRatings = safetyRatings
        self.citationMetadata = citationMetadata
    }
}

/// Usage metadata (token counts)
public struct GeminiUsageMetadata: Codable, Sendable {
    public let promptTokenCount: Int
    public let candidatesTokenCount: Int
    public let totalTokenCount: Int

    public init(promptTokenCount: Int, candidatesTokenCount: Int, totalTokenCount: Int) {
        self.promptTokenCount = promptTokenCount
        self.candidatesTokenCount = candidatesTokenCount
        self.totalTokenCount = totalTokenCount
    }
}

/// Safety rating for a response
public struct GeminiSafetyRating: Codable, Sendable {
    public let category: String
    public let probability: String

    public init(category: String, probability: String) {
        self.category = category
        self.probability = probability
    }
}

/// Citation metadata
public struct GeminiCitationMetadata: Codable, Sendable {
    public let citationSources: [GeminiCitationSource]

    public init(citationSources: [GeminiCitationSource]) {
        self.citationSources = citationSources
    }
}

/// Citation source
public struct GeminiCitationSource: Codable, Sendable {
    public let startIndex: Int?
    public let endIndex: Int?
    public let uri: String?
    public let license: String?

    public init(startIndex: Int? = nil, endIndex: Int? = nil, uri: String? = nil, license: String? = nil) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.uri = uri
        self.license = license
    }
}

// MARK: - Streaming

/// Streaming response chunk
public struct GeminiStreamChunk: Codable, Sendable {
    public let candidates: [GeminiCandidate]
    public let usageMetadata: GeminiUsageMetadata?
    public let modelVersion: String?

    public init(candidates: [GeminiCandidate], usageMetadata: GeminiUsageMetadata? = nil, modelVersion: String? = nil) {
        self.candidates = candidates
        self.usageMetadata = usageMetadata
        self.modelVersion = modelVersion
    }
}

// MARK: - Token Counting

/// Token count request
public struct GeminiCountTokensRequest: Codable, Sendable {
    public let contents: [GeminiContent]

    public init(contents: [GeminiContent]) {
        self.contents = contents
    }
}

/// Token count response
public struct GeminiCountTokensResponse: Codable, Sendable {
    public let totalTokens: Int

    public init(totalTokens: Int) {
        self.totalTokens = totalTokens
    }
}

// MARK: - Error Models

/// Gemini API error response
public struct GeminiErrorResponse: Codable, Sendable {
    public let error: GeminiError

    public init(error: GeminiError) {
        self.error = error
    }
}

/// Gemini error details
public struct GeminiError: Codable, Sendable {
    public let code: Int
    public let message: String
    public let status: String?
    public let details: [GeminiErrorDetail]?

    public init(code: Int, message: String, status: String? = nil, details: [GeminiErrorDetail]? = nil) {
        self.code = code
        self.message = message
        self.status = status
        self.details = details
    }
}

/// Gemini error detail
public struct GeminiErrorDetail: Codable, Sendable {
    public let type: String?
    public let reason: String?
    public let domain: String?
    public let metadata: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case type = "@type"
        case reason
        case domain
        case metadata
    }

    public init(type: String? = nil, reason: String? = nil, domain: String? = nil, metadata: [String: String]? = nil) {
        self.type = type
        self.reason = reason
        self.domain = domain
        self.metadata = metadata
    }
}
