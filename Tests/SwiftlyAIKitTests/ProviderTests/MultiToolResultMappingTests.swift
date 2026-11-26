import Testing
import Foundation
@testable import SwiftlyAIKit

/// Multi tool-result request mapping (AI33 Phase 03b, ruling R31).
///
/// One assistant turn emits three tool calls; the next user turn answers all three in ONE neutral
/// message carrying three tool-result parts (one a failed tool's error JSON, one the AI33 chat
/// `declined` text). Every provider must put all three results on the wire, in order, each keyed
/// by its own call id and byte-identical — a first-result-only mapper leaves two calls
/// unanswered (an OpenAI-shaped `400`, or a model that never sees the decline).
///
/// The oracle is the ENCODED request (`JSONEncoder` → `JSONSerialization`), not the Swift struct,
/// so a coding-key slip is caught too.
@Suite("Multi tool-result request mapping (AI33 R31)")
struct MultiToolResultMappingTests {

    // MARK: - Fixture

    static let ids = ["t1", "t2", "t3"]
    static let declinedText = "The user declined this action. Nothing was changed. "
        + "Do not retry it unless the user asks; ask what they would like instead."
    static let results = [
        "{\"customers\":[]}",
        "{\"error\":\"Customer name already exists\"}",
        declinedText
    ]
    static let toolNames = ["list_customers", "create_customer", "create_customer"]

    static func request(model: String) -> AIRequest {
        AIRequest(
            model: model,
            messages: [
                AIMessage(role: .user, content: [.text("Create three things")]),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "t1", name: "list_customers", arguments: "{}")),
                    .toolCall(AIToolCall(id: "t2", name: "create_customer", arguments: "{\"name\":\"A\"}")),
                    .toolCall(AIToolCall(id: "t3", name: "create_customer", arguments: "{\"name\":\"B\"}"))
                ]),
                AIMessage(role: .user, content: [
                    .toolResult(id: "t1", result: results[0]),
                    .toolResult(id: "t2", result: results[1]),
                    .toolResult(id: "t3", result: results[2])
                ])
            ],
            tools: [
                AITool(
                    name: "list_customers",
                    description: "List customers",
                    parameters: AIToolParameters(properties: [:])
                ),
                AITool(
                    name: "create_customer",
                    description: "Create a customer",
                    parameters: AIToolParameters(
                        properties: ["name": AIToolProperty(type: "string", description: "Name")],
                        required: ["name"]
                    )
                )
            ]
        )
    }

    // MARK: - Wire helpers

    /// The encoded request as a JSON object.
    static func wire<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The per-provider assertion of the plan's §7 over an OpenAI-shaped `messages` array:
    /// user, assistant (`tool_calls` t1…t3), then exactly three contiguous `role: tool` messages
    /// answering t1…t3 in order with the result strings byte-identical, and nothing else.
    static func expectThreeToolMessages(_ request: [String: Any], provider: String) throws {
        let messages = try #require(request["messages"] as? [[String: Any]], "\(provider): no messages array")
        let roles = messages.map { $0["role"] as? String ?? "?" }
        #expect(roles == ["user", "assistant", "tool", "tool", "tool"], "\(provider): roles \(roles)")

        let assistant = try #require(messages.first { $0["role"] as? String == "assistant" })
        let calls = assistant["tool_calls"] as? [[String: Any]] ?? []
        #expect(calls.map { $0["id"] as? String ?? "?" } == ids, "\(provider): assistant tool_calls ids")

        let toolMessages = messages.filter { $0["role"] as? String == "tool" }
        #expect(toolMessages.count == 3, "\(provider): \(toolMessages.count) tool messages for 3 calls")
        let callIDs = toolMessages.map { $0["tool_call_id"] as? String ?? "?" }
        #expect(callIDs == ids, "\(provider): tool_call_id order")
        #expect(toolMessages.map { $0["content"] as? String ?? "?" } == results, "\(provider): result strings")
    }

    // MARK: - The five fixed mappers

    @Test("QA-UNIT02-AI-419: OpenAI maps three tool results to three tool messages, ids and order kept")
    func openAI() throws {
        let mapped = try OpenAIProvider().mapToOpenAIRequest(Self.request(model: "gpt-4o"))
        try Self.expectThreeToolMessages(try Self.wire(mapped), provider: "openai")
    }

    @Test("QA-UNIT02-AI-420: OpenRouter maps three tool results to three tool messages, ids and order kept")
    func openRouter() throws {
        let mapped = try OpenRouterProvider().mapToOpenRouterRequest(Self.request(model: "openai/gpt-4o"))
        try Self.expectThreeToolMessages(try Self.wire(mapped), provider: "openrouter")
    }

    @Test("QA-UNIT02-AI-421: Mistral maps three tool results to three tool messages, ids and order kept")
    func mistral() throws {
        let request = Self.request(model: "mistral-large-latest")
        let mapped = try MistralProvider().mapToMistralRequest(request, stream: false)
        try Self.expectThreeToolMessages(try Self.wire(mapped), provider: "mistral")
    }

    @Test("QA-UNIT02-AI-422: DeepSeek maps three tool results to three tool messages, ids and order kept")
    func deepSeek() throws {
        let mapped = try DeepSeekProvider().buildDeepSeekRequest(from: Self.request(model: "deepseek-chat"))
        try Self.expectThreeToolMessages(try Self.wire(mapped), provider: "deepseek")
    }

    @Test("QA-UNIT02-AI-423: Cohere maps three tool results to three tool messages, ids and order kept")
    func cohere() throws {
        let mapped = try CohereProvider().mapToCohereRequest(Self.request(model: "command-r-plus"), stream: false)
        try Self.expectThreeToolMessages(try Self.wire(mapped), provider: "cohere")
    }

    // MARK: - Control: the providers that were already correct

    @Test("QA-UNIT02-AI-424: Anthropic, Gemini, Grok and Perplexity keep answering every tool call (control)")
    func controls() throws {
        // Anthropic: the results turn is one user message with three tool_result blocks.
        let anthropicRequest = Self.request(model: "claude-sonnet-4-5")
        let anthropic = try Self.wire(try AnthropicProvider().mapToAnthropicRequest(anthropicRequest))
        let anthropicMessages = try #require(anthropic["messages"] as? [[String: Any]])
        #expect(anthropicMessages.count == 3, "anthropic: \(anthropicMessages.count) messages")
        let anthropicLast = try #require(anthropicMessages.last)
        #expect(anthropicLast["role"] as? String == "user")
        let blocks = (anthropicLast["content"] as? [[String: Any]] ?? [])
            .filter { $0["type"] as? String == "tool_result" }
        #expect(blocks.map { $0["tool_use_id"] as? String ?? "?" } == Self.ids, "anthropic: tool_use_id order")
        #expect(blocks.map { $0["content"] as? String ?? "?" } == Self.results, "anthropic: result strings")

        // Gemini: one content with three functionResponse parts, names resolved from the calls.
        let gemini = try Self.wire(try GeminiProvider().mapToGeminiRequest(Self.request(model: "gemini-2.5-flash")))
        let contents = try #require(gemini["contents"] as? [[String: Any]])
        let parts = try #require(contents.last?["parts"] as? [[String: Any]])
        let responses = parts.compactMap { $0["functionResponse"] as? [String: Any] }
        #expect(responses.count == 3, "gemini: \(responses.count) functionResponse parts")
        #expect(responses.map { $0["name"] as? String ?? "?" } == Self.toolNames, "gemini: names")
        #expect(
            responses.map { ($0["response"] as? [String: Any])?["result"] as? String ?? "?" } == Self.results,
            "gemini: result strings"
        )

        // Grok: OpenAI-shaped, three tool messages.
        let grok = try Self.wire(try GrokProvider().buildGrokRequest(from: Self.request(model: "grok-4")))
        try Self.expectThreeToolMessages(grok, provider: "grok")

        // Perplexity: the Agent API input carries three function_call_output items in order.
        let perplexityRequest = try PerplexityProvider()
            .buildAgentRequest(from: Self.request(model: "sonar"), stream: false)
        let perplexity = try Self.wire(perplexityRequest)
        let input = try #require(perplexity["input"] as? [[String: Any]])
        let outputs = input.filter { $0["type"] as? String == "function_call_output" }
        #expect(outputs.map { $0["call_id"] as? String ?? "?" } == Self.ids, "perplexity: call_id order")
        #expect(outputs.map { $0["output"] as? String ?? "?" } == Self.results, "perplexity: result strings")
    }
}
