import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for DeepSeekProvider model-discovery (`listModels`) decoding.
@Suite("DeepSeekProvider Models List Tests")
struct DeepSeekProviderTests {
    // MARK: - Models List

    @Test("Decodes models list response")
    func testDecodeModelsListResponse() throws {
        let jsonData = MockDeepSeekAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepSeekModelsResponse.self, from: jsonData)

        #expect(response.object == "list")
        #expect(response.data.count == 2)
        #expect(response.data.map(\.id) == ["deepseek-chat", "deepseek-reasoner"])
    }

    @Test("Maps model info snake_case keys")
    func testModelInfoSnakeCaseMapping() throws {
        let jsonData = MockDeepSeekAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepSeekModelsResponse.self, from: jsonData)

        let chat = try #require(response.data.first)
        #expect(chat.id == "deepseek-chat")
        #expect(chat.object == "model")
        // Verify the owned_by -> ownedBy snake_case key maps correctly.
        #expect(chat.ownedBy == "deepseek")
    }
}
