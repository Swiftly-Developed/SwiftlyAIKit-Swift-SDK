# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.12] - 2026-07-18

Additive, backward-compatible feature: a new **Groq** provider for Groq's OpenAI-compatible
Chat Completions API (fast inference for open models). No neutral types change and every existing
provider behaves identically; `v0.9.11` consumers compile unchanged. Adds one `ProviderType` case,
so any exhaustive `switch` over `ProviderType` in consuming code will surface a new `.groq` arm.

### Added
- **`GroqProvider`** — `ProviderProtocol` conformer targeting Groq (`https://api.groq.com/openai/v1`,
  `Authorization: Bearer <key>`). Full chat support: `sendMessage`, `streamMessage` (SSE with
  cumulative content + terminal-usage handling), unified tool calling (tool wiring, tool-call
  reassembly via a static `accumulateToolCalls` helper), and `listModels(apiKey:)` → `GET /models`.
  Text/chat only — no image generation. Mirrors the OpenAI-compatible `GrokProvider` shape.
- **`ProviderType.groq`** — new case (`displayName` "Groq", `baseURL` `https://api.groq.com/openai/v1`),
  registered by `AIGateway.createDefaultProviders` as `GroqProvider()`. Marked tool-capable in
  `ToolCapabilities` and image-generation-unsupported in `ImageGenerationCapabilities`.
- **`GroqModelsResponse` / `GroqModelInfo`** plus the full `Groq*` request/response/streaming/tool
  Codable set — `Codable`, `Sendable`, snake_case wire property names (no `.convertFromSnakeCase`).
- **`MockGroqAPI` fixtures + `GroqProviderTests`/`GroqStreamingTests`/`GroqToolRoundTripTests`** and an
  `AIGatewayGroqDispatchTests` case asserting `.groq` routes to a real `GroqProvider`.

## [0.9.11] - 2026-07-18

Additive, backward-compatible feature: `AppleIntelligenceProvider` now wires the SDK's unified tool
API onto Apple's Foundation Models `Tool` API (iOS 26+ / macOS 26+). Neutral `AITool` definitions
are translated into Foundation Models `GenerationSchema`s and registered with the on-device session;
when the model requests a tool, the invocation is surfaced to the caller as a neutral `.toolCall`
content block with a `.toolUse` stop reason (parity with the HTTP providers) rather than executed
in-process. Everything is gated by `#if canImport(FoundationModels)` + `@available(iOS 26, macOS 26)`
and compiles unchanged on older SDKs. With no tools supplied — or when Foundation Models is
unavailable — behaviour is identical to `v0.9.10`.

### Added
- **`AppleIntelligenceProvider` Foundation Models tool calling (iOS/macOS 26+)** — `request.tools`
  are translated into Foundation Models tools via `DynamicGenerationSchema` (the runtime counterpart
  of `@Generable`, since `AITool` schemas are defined at runtime) and registered on the
  `LanguageModelSession`. A requested tool is returned as `.toolCall(AIToolCall)` + `stopReason
  == .toolUse`, for both `sendMessage` and `streamMessage`.
- **`AppleIntelligenceProvider.supportsTools`** now reflects real support —
  `AppleIntelligenceCapabilities.foundationModelsAvailable` (`true` only where Foundation Models is
  available) — instead of inheriting the protocol default.
- **`AppleIntelligenceProviderTests`** — assert neutral `AITool`s translate into a valid
  `GenerationSchema` (including enum, integer, nested-object and array parameters; availability
  gated) and that a captured on-device tool call maps to a `.toolUse` response (platform-independent).

### Changed
- **`ToolCapabilities.isSupported(by: .appleIntelligence)`** returns `true` where
  `canImport(FoundationModels)` (iOS 26+ / macOS 26+ SDK), `false` otherwise — previously a flat
  `false`. The exhaustive switch is preserved.

## [0.9.10] - 2026-07-18

Additive, backward-compatible capability-detection surface. Callers can now ask, per provider,
whether tool / function calling is supported — and `PerplexityProvider` (whose Sonar API is a pure
search/answer API with no function calling) degrades gracefully when a request carries tools. No
neutral types, `AIGateway`, or other providers change behaviour; `v0.9.9` consumers compile and
behave identically.

### Added
- **`ProviderProtocol.supportsTools`** — a `Bool` capability flag with an extension default of
  `true`, so existing tool-capable providers keep working unchanged. Providers without tool support
  override it to `false`.
- **`ToolCapabilities`** — a static, `ProviderType`-keyed helper mirroring `ImageGenerationCapabilities`;
  `ToolCapabilities.isSupported(by:)` returns `false` for `.perplexity` and `.appleIntelligence` and
  `true` for the rest. The switch is exhaustive (no `default`) so a new `ProviderType` case forces a
  compile error until its tool support is declared.
- **`ToolCapabilitiesTests` / `PerplexityToolDegradationTests`** — assert the per-provider support
  matrix, the `supportsTools` default, `PerplexityProvider().supportsTools == false`, and that a
  request carrying `tools`/`toolChoice` maps to a Sonar wire body that omits any tools field without
  throwing.

### Changed
- **`PerplexityProvider` overrides `supportsTools` to `false`** and documents graceful degradation:
  `request.tools` / `request.toolChoice` are ignored (a documented no-op) and the normal Sonar
  request proceeds, rather than throwing. `PerplexityProvider.mapToPerplexityRequest(_:)` is now
  `internal` (was `private`) so tests can assert the wire body omits tools.

## [0.9.9] - 2026-07-18

Capability-parity fix: `DeepSeekProvider` now honours the SDK's unified tool API. Previously it
mapped tools only from `providerOptions["tools"]` (a provider-native `[DeepSeekTool]` cast that
never matched the `AnyCodable`-boxed options dictionary, so neutral-API callers got no tool
calling at all). It now reads `request.tools` / `request.toolChoice` directly, mirroring
`OpenAIProvider`. Additive and backward-compatible — the `providerOptions` path is retained as a
fallback; `v0.9.8` consumers compile and behave identically.

### Fixed
- **`DeepSeekProvider` now maps the unified `request.tools` / `request.toolChoice`** into DeepSeek's OpenAI-compatible wire types (function name/description/JSON-schema parameters, incl. nested objects and arrays-of-objects), instead of ignoring them. The legacy `providerOptions["tools"]` / `providerOptions["tool_choice"]` values are kept as an override fallback for backward compatibility.
- **Multi-turn tool conversations round-trip** — assistant `.toolCall` content maps to a DeepSeek assistant message with `tool_calls`, and `.toolResult` content maps to a `tool`-role message keyed by `tool_call_id`.
- **Non-streaming responses decode `tool_calls`** into neutral `.toolCall(AIToolCall)` content blocks (arguments preserved as the raw JSON string, as `OpenAIProvider` does); the `tool_calls` finish-reason continues to map to `.toolUse`.
- **Streaming assembles index-keyed tool-call fragments** via a new testable `DeepSeekProvider.accumulate(_:into:)` helper (id/name arrive first, `arguments` stream in fragments), emitting fully-assembled `.toolCall` blocks on the finish chunk — mirroring `OpenAIProvider`/`GrokProvider`.

### Changed
- **`DeepSeekDelta.tool_calls`** is now typed `[DeepSeekDeltaToolCall]?` (new `DeepSeekDeltaToolCall` / `DeepSeekDeltaFunctionCall` types with optional fields) so partial streaming fragments decode; the strict `DeepSeekToolCall` type is unchanged for non-streaming responses and request messages.

### Added
- **`DeepSeekProviderToolTests`** — mirrors `OpenAIProviderTests`: neutral `request.tools`/`toolChoice` wiring (asserting the neutral API, not `providerOptions`, reaches the wire body), specific tool-choice mapping, multi-turn round-trip, response `tool_calls` → `.toolCall` decoding, streaming accumulation by index, and nested-object schema emission.

## [0.9.8] - 2026-07-18

Additive, backward-compatible extension bringing `DeepSeekProvider` to parity with the other
providers' model-discovery surface. No neutral types, `AIGateway`, `ProviderProtocol`, or
other providers change; `v0.9.7` consumers compile and behave identically.

### Added
- **`DeepSeekProvider.listModels(apiKey:)`** — lists available models via DeepSeek's OpenAI-compatible `GET /models` endpoint (Bearer auth), mirroring `OpenAIProvider`/`GrokProvider`/`GeminiProvider`/`CohereProvider`/`MistralProvider`/`AnthropicProvider`. Returns the RAW `DeepSeekModelsResponse`; callers filter to the models they intend to use (e.g. `deepseek-chat`, `deepseek-reasoner`).
- **`DeepSeekModelsResponse` / `DeepSeekModelInfo`** — `Codable`, `Sendable`, public response types for the models endpoint, with explicit snake_case `CodingKeys` (`owned_by`) to avoid the `.convertFromSnakeCase` conflict on Linux Foundation. DeepSeek's `/models` omits `created`, so `DeepSeekModelInfo` carries only `id`, `object`, and `ownedBy`.
- **`MockDeepSeekAPI.modelsListResponse`** fixture + `DeepSeekProviderTests` cases decoding the models list, asserting model ids and the `owned_by` snake_case key mapping.

## [0.9.7] - 2026-07-18

Additive, backward-compatible extension bringing `MistralProvider` to parity with the other
providers' model-discovery surface. No neutral types, `AIGateway`, `ProviderProtocol`, or
other providers change; `v0.9.6` consumers compile and behave identically.

### Added
- **`MistralProvider.listModels(apiKey:)`** — lists available models via Mistral's `GET /v1/models` endpoint, mirroring `OpenAIProvider`/`GrokProvider`/`GeminiProvider`/`CohereProvider`/`AnthropicProvider`. Returns the RAW `MistralModelsResponse`; callers filter by each model's `capabilities` (e.g. `completionChat`).
- **`MistralModelsResponse` / `MistralModelInfo` / `MistralModelCapabilities`** — `Codable`, `Sendable`, public response types for the models endpoint, with explicit snake_case `CodingKeys` (`owned_by`, `completion_chat`, `function_calling`) to avoid the `.convertFromSnakeCase` conflict on Linux Foundation. `capabilities` is optional (nil when the API omits it).
- **`MockMistralAPI.modelsListResponse`** fixture + `MistralProviderTests` cases decoding the models list, asserting model ids, snake_case key mapping, nested capabilities, and chat-capable filtering.

## [0.9.6] - 2026-07-18

Additive, backward-compatible extension bringing `CohereProvider` to parity with the other
providers' model-discovery surface. No neutral types, `AIGateway`, `ProviderProtocol`, or
other providers change; `v0.9.5` consumers compile and behave identically.

### Added
- **`CohereProvider.listModels(apiKey:)`** — lists available models via Cohere's `GET /models` endpoint, mirroring `OpenAIProvider`/`GrokProvider`/`GeminiProvider`/`AnthropicProvider`. Returns the RAW `CohereModelsResponse` (paginated via `nextPageToken`); callers filter by each model's `endpoints` (e.g. `chat`).
- **`CohereModelsResponse` / `CohereModelInfo`** — `Codable`, `Sendable`, public response types for the models endpoint, with explicit snake_case `CodingKeys` (`context_length`, `is_deprecated`, `tokenizer_url`, `default_endpoints`, `next_page_token`) to avoid the `.convertFromSnakeCase` conflict on Linux Foundation.
- **`MockCohereAPI.modelsListResponse`** fixture + `CohereProviderTests` cases decoding the models list, asserting model names, snake_case key mapping, pagination cursor, and chat-endpoint filtering.

## [0.9.5] - 2026-07-18

Additive, backward-compatible robustness fixes for `GrokProvider` streaming. No neutral
types, `AIGateway`, `ProviderProtocol`, or other providers change; `v0.9.4` consumers
compile and behave identically (they now additionally see streamed token usage).

### Fixed
- **`GrokProvider` streaming now surfaces the terminal usage chunk.** Under OpenAI-compatible SSE, `stream_options.include_usage` makes xAI emit a final `{"choices":[],"usage":{…}}` chunk that carries token usage but no `delta`. The previous stream loop nested `finish_reason` and `usage` handling inside an `if let delta` guard, so that delta-less terminal chunk was skipped and usage was dropped. `finish_reason` and `usage` are now read off every chunk unconditionally, and the fully-assembled final response (content + tool calls + stop reason + usage) is yielded once at stream end. Grok streaming now matches Gemini in reporting real streamed usage.
- **`finish_reason` survives a delta-less chunk** for the same reason (previously it only survived because OpenAI-compatible finish chunks happen to carry a non-nil empty `delta`).

### Changed
- **`GrokProvider.accumulateToolCalls` is now a testable `static` helper** (mirroring `OpenAIProvider.accumulate`), unit-testing the index-keyed reassembly of streamed tool-call fragments. Widened from `private` to `static` (internal); no public signature changes.
- SSE parsing/reassembly extracted into a testable `makeResponseStream(from:)` that drives both production and tests.

### Added
- **End-to-end streaming tests** (`GrokStreamingTests`) that consume `makeResponseStream` against a mock modelling real xAI framing (content deltas → `finish_reason` chunk → separate trailing `{"choices":[],"usage":{…}}` chunk → `[DONE]`), asserting cumulative content assembly, streamed tool-call reassembly, stop-reason mapping, and terminal-usage surfacing.
- `MockGrokAPI.streamingResponseRealFraming` / `streamingToolCallResponseRealFraming` fixtures reflecting real xAI SSE framing (usage on its own `choices:[]` chunk).

## [0.9.1] - 2026-07-16

Additive, backward-compatible patch so the neutral `AIRequest`/`AIResponse` boundary can
carry Anthropic server-tool signals (native web search, `server_tool_use`, tool-search) and
the `defer_loading` request flag. `v0.9.0` consumers compile and behave identically; other
providers are untouched.

### Added
- **`AIRequest.rawMessagesJSON`** — raw messages-array pass-through (mirrors `rawSystemJSON`/`rawToolsJSON`). When set, Anthropic relays the message objects verbatim, preserving native content blocks (`server_tool_use`, `web_search_tool_result` with `encrypted_content`, tool-search results) that the neutral `AIMessage` model cannot represent — fixes lost context / 400s on re-send (R2).
- **`AnthropicToolDefinition.deferLoading`** (`defer_loading`) + an open **`extras: [String: AnyCodable]`** bag, so `rawToolsJSON` round-trips byte-faithfully and AI19's hot/cold tool set survives decode→encode (R1).
- **`AnthropicRequest.rawMessages`** — internal raw passthrough used to emit `messages` verbatim.

### Changed
- **Streaming `processStreamEvent`** now surfaces server-tool signals on `AIResponse.providerData` (S1/S2/S3):
  - `web_search_tool_result` → `providerData["webSearchToolResult"]` carries the full block (urls / text / `encrypted_content`) instead of only the index (S1).
  - `server_tool_use` → block `id` surfaced at start (`providerData["serverToolId"]`); the streamed `input_json_delta` is accumulated and emitted on stop as `providerData["serverToolUse"] = {id, name, input}` with `streamEvent = "server_tool_use_complete"` (S2).
  - Unknown/future blocks (e.g. `tool_search_tool_result`) → `providerData["unknownBlock"]` + `["unknownBlockType"]`, instead of being dropped (S3).
- **`ToolStreamAccumulator`** now accumulates `server_tool_use` input in addition to `tool_use` (returns a `StreamedTool` enum: `.client` / `.server`).
- **`AnthropicContentBlock` decoding** captures the full raw block for `web_search_tool_result` and unknown types (previously only `content` / discarded), and re-encodes them byte-faithfully.
- **Non-streaming `mapToAIResponse`** surfaces unknown blocks on `providerData["unknownBlocks"]`.

## [Unreleased]

### Changed
- **Documentation**: Complete restructure of DocC documentation for provider-first navigation
- **Documentation**: Added 15 new API reference extension files grouping types by provider and feature
- **Documentation**: Reorganized root documentation page (SwiftlyAIKit.md) with provider-first Topics hierarchy
- **Documentation**: Each provider now has dedicated API reference page grouping all related types together
- **Documentation**: Core framework types organized into logical groups (AIGateway, Configuration, AIRequest, AIResponse, ImageGeneration, ModelProvider)

### Technical Details
- Created 9 provider-specific extension files in `Documentation.docc/APIReference/Providers/`:
  - AnthropicProvider.md (22 types)
  - OpenAIProvider.md (18 types)
  - GeminiProvider.md (Gemini types + GoogleProvider alias)
  - PerplexityProvider.md (Perplexity types + PerplexityOptions)
  - MistralProvider.md (Mistral types)
  - CohereProvider.md (Cohere types)
  - DeepSeekProvider.md (DeepSeek types)
  - GrokProvider.md (Grok types)
  - AppleIntelligenceProvider.md (Apple Intelligence types)
- Created 6 core API extension files in `Documentation.docc/APIReference/Core/`:
  - AIGateway.md
  - Configuration.md
  - AIRequest.md
  - AIResponse.md
  - ImageGeneration.md
  - ModelProvider.md
- Updated SwiftlyAIKit.md Topics section with provider-first organization
- All 41 existing guide files remain accessible and functional

## [0.9.0] - 2026-07-16

### Added
- **Anthropic provider parity — full tool calling, prompt caching, extended thinking, web search**
  - Neutral `[AITool]` and `AIToolChoice` are now mapped into Anthropic requests (previously silently dropped); raw JSON pass-through still takes precedence when supplied
  - Faithful `tool_use` argument round-trip in **both** directions — request-side serializes `AIToolCall.arguments` into `tool_use.input`, response-side decodes `tool_use.input` back into `AIToolCall.arguments`; a full `user → assistant(tool_use) → user(tool_result) → assistant(text)` turn survives encode/decode
  - Non-streaming `tool_use` blocks parsed into `AIMessageContent.toolCall` with real arguments and `stopReason == .toolUse`
  - Streaming `tool_use` accumulates `input_json_delta` fragments into complete tool-call arguments (surfaced via a reusable `ToolStreamAccumulator`)
  - Prompt caching (ephemeral) via `providerOptions["anthropic_cache"]` — targets system prompt, tools, and/or trailing message content (`true`/`"system"`/`"tools"`/`"messages"`/`"all"`)
  - Extended thinking via `providerOptions["anthropic_thinking"]` (bool or budget int, plus `anthropic_thinking_budget`); correct `{"type":"enabled","budget_tokens":N}` wire format; thinking blocks surfaced on `AIResponse.providerData["thinking"]`
  - Native server-side web search via `providerOptions["anthropic_web_search"]` with the `web-search-2025-03-05` beta header; `server_tool_use` / `web_search_tool_result` surfaced on `AIResponse.providerData` for citation relay
  - Fixed `thinking` content-block decoding (was reading the `text` key instead of `thinking`)
- **Provider-neutral nested tool schemas**
  - `AIToolProperty` and `AIToolPropertyItems` gained optional `properties`/`required` so nested objects and arrays-of-objects are representable (additive, existing call sites unaffected)
  - Shared `jsonSchemaDictionary()` serializer used by Anthropic, OpenAI, and Grok; Gemini's typed schema recurses into nested properties
- **OpenAI / Gemini / Grok agentic tool-calling readiness**
  - OpenAI and Gemini streaming now surface tool/function calls (not just text); OpenAI accumulates partial tool-call arguments across deltas
  - Gemini reports `stopReason == .toolUse` on function calls and round-trips tool results via the function name (Gemini has no tool-call IDs)
  - Grok maps the neutral `toolChoice`, round-trips assistant tool calls and tool-result messages (previously dropped), and surfaces streamed tool calls in message content
- **xAI Grok Provider** (~1,200 lines total)
  - GrokModels.swift with complete type definitions (~900 lines) for all Grok API features
  - GrokProvider implementation (~670 lines) with sendMessage, streamMessage, countTokens, image generation, deferred completions, and model listing
  - Support for 7 Grok models: Grok 4, Grok 4 Latest, Grok 3, Grok 3 Mini, Grok 2 Vision, Grok Code Fast, Grok 2 Image
  - OpenAI-compatible API format for straightforward integration
  - Reasoning tokens tracking via `AIUsage.reasoningTokens` and `completion_tokens_details.reasoning_tokens`
  - Automatic prompt caching with `prompt_tokens_details.cached_tokens` tracking
  - SSE streaming support with delta accumulation for real-time responses
  - Vision support for Grok 2 Vision model (image URLs and base64 data URLs)
  - Tool/function calling infrastructure (OpenAI-compatible format)
  - Live web search via `search_parameters` option
  - Deferred completions for long-running requests
  - Image generation with Grok 2 Image model (`generateImage` method)
  - Tokenization via dedicated `/tokenize-text` endpoint (`countTokens` method)
  - Bearer token authentication
  - Context windows: 1M tokens (Grok 3/3 Mini), 128K tokens (Grok 4/Vision/Code)
  - Output limits: 8K tokens for all chat models
  - Added `reasoningTokens` field to `AIUsage` struct for Grok 4 reasoning token tracking
- **Comprehensive Grok test coverage** (60+ tests)
  - MockGrokAPI.swift with sample responses for all Grok endpoints (40+ mock responses)
  - GrokProviderTests (60 tests) covering initialization, request/response mapping, streaming, reasoning tokens, cached tokens, deferred completions, image generation, tokenization, error handling, and model support

### Changed
- Updated ModelProvider enum to include 7 Grok models (total now 67 models)
- Updated ProviderType enum to include `.grok` (total now 8 providers: Anthropic, OpenAI, Google, Perplexity, Cohere, Mistral, DeepSeek, Grok)
- AIGateway now registers GrokProvider and PerplexityProvider by default
- Updated ProviderTypeTests switch statement to include `.grok` case

## [0.8.0] - 2025-11-24

### Removed
- **BREAKING:** SwiftlyAIKitVapor target (moved to separate SwiftlyAIServerKit package)
- Vapor framework dependency (no longer needed for device framework)

### Changed
- Package now focused on device platforms (iOS, macOS, watchOS, tvOS, visionOS)
- SwiftlyAIKitVapor users should migrate to SwiftlyAIServerKit package
- Updated README.md to remove Vapor-specific examples
- Updated CLAUDE.md to remove server-specific guidance

### Migration Guide

**For device app developers (iOS, macOS, watchOS, tvOS, visionOS):**

No changes needed! Continue using SwiftlyAIKit as before:

```swift
.package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.8.0")
// import SwiftlyAIKit
```

**For Vapor server developers:**

You need to add a second package dependency. Change from:

```swift
// Before (v0.7.0)
.package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.7.0")
// import SwiftlyAIKitVapor
```

To:

```swift
// After (v0.8.0+)
.package(url: "https://github.com/Swiftly-Developed/SwiftlyAIServerKit.git", from: "0.1.0")
// import SwiftlyAIServerKit
```

All APIs remain identical - only the import name changes.

## [0.7.0] - 2025-11-24

### Added
- **DeepSeek Provider** (~650 lines models + ~400 lines provider implementation)
  - Complete OpenAI-compatible API implementation
  - Two models: `deepseek-chat` (128K context) and `deepseek-reasoner` (64K context, R1)
  - Full feature set: chat completions, SSE streaming, tool calling (up to 128 functions), reasoning mode
  - Prompt caching support with `prompt_cache_hit_tokens` and `prompt_cache_miss_tokens` tracking
  - Reasoning mode with `reasoning_content` field for chain-of-thought transparency
  - Structured JSON output via `response_format`
  - Bearer token authentication
  - Added to ProviderType enum, ModelProvider enum, and AIGateway registration
  - Mock test infrastructure (MockDeepSeekAPI) with comprehensive test responses
- **Platform-Agnostic Architecture** - Framework now works on iOS, macOS, watchOS, tvOS, and visionOS
  - Separated SwiftlyAIKit (core) and SwiftlyAIKitVapor (Vapor extensions) targets in Package.swift
  - Core framework has no Vapor dependency - works on all Apple platforms
  - Vapor extensions available as separate import for server-side applications
  - Removed unnecessary Vapor imports from AIGateway, OpenAIProvider, and GeminiProvider
  - Added platform support: .macOS(.v13), .iOS(.v16), .watchOS(.v9), .tvOS(.v16), .visionOS(.v1)
  - Two usage patterns: (1) SwiftlyAIKit alone on devices, (2) SwiftlyAIKit + SwiftlyAIKitVapor on servers
- **Complete Tool/Function Calling Support** (~350 lines core + ~600 lines provider implementations)
  - AITool.swift with complete tool definition framework
  - `AITool` struct for defining functions the model can call (name, description, JSON Schema parameters)
  - `AIToolParameters` and `AIToolProperty` for JSON Schema-based parameter definitions
  - `AIToolChoice` enum (auto, required, none, specific) for controlling tool usage
  - `AIToolCall` struct for representing model tool invocations
  - Extended `AIMessageContent` enum with `toolCall` and `toolResult` cases
  - Extended `AIRequest` with `tools` and `toolChoice` properties
  - **Fully implemented tool calling in all providers:**
    - OpenAI: Maps to OpenAI function calling API with tool definitions and tool choice
    - Mistral: Maps to Mistral tool calling API (OpenAI-compatible format)
    - Gemini: Maps to Google function declarations with function calling config
    - Cohere: Maps to Cohere tool definitions with JSON Schema parameters
  - Bidirectional tool call mapping: AITool → Provider format and Provider response → AIToolCall
  - Tool result handling in message content for multi-turn tool usage
  - Removed all TODO comments - tool calling is now production-ready
- **Comprehensive README Documentation**
  - Complete configuration examples for all three API key strategies (company, client, hybrid)
  - Real-world usage examples with Vapor route handlers
  - Basic chat completion and streaming response examples
  - Detailed API key strategy descriptions with use cases
- **AIGateway Initialization Test Suite** (8 tests)
  - Tests for all configuration strategies (company key, client key, hybrid, per-provider)
  - Tests for development and production configurations
  - Custom provider registration tests
  - Ensures robust gateway initialization

### Changed
- **Restructured codebase to provider-centric organization**
  - Moved all provider-specific models from `Models/[Provider]/` to `Providers/[Provider]/`
  - Moved `ProviderProtocol.swift` from `Providers/` to `Core/` directory
  - Eliminated 6 single-file directories in Models/ (Anthropic, OpenAI, Gemini, Perplexity, Mistral, Cohere)
  - Each provider directory now contains 2-3 files (provider + models + options where applicable)
  - Test structure reorganized to mirror source structure with provider subdirectories
  - Mock API files moved from `Mocks/` to `ProviderTests/[Provider]/` directories
  - Updated CLAUDE.md documentation with new folder structure
  - **Benefits**: Improved code cohesion, easier navigation, better scalability, clearer module boundaries
- **All providers fully support tool/function calling**
  - Complete toolCall and toolResult handling in all provider implementations
  - Request mapping: AITool → provider-specific tool format
  - Response mapping: provider tool calls → AIToolCall
  - Message mapping: handles tool calls from assistant and tool results from user
  - Maintained backwards compatibility with existing code (tools are optional)

### Removed
- Removed unused `JSONHelpers.swift` placeholder file
- Removed unused `SwiftlyAIKit.swift` empty struct file
- Removed placeholder `SwiftlyAIKitTests.swift` test file
- Cleaned up dead code and TODO placeholders

## [0.6.0] - 2025-11-23

### Added
- **Complete Cohere AI integration** (~2,000 lines total)
  - CohereModels.swift with full type definitions (454 lines) for Cohere v2 API
  - CohereProvider implementation (465 lines) with sendMessage, streamMessage, and countTokens
  - Support for 11 Cohere models: Command A family (4 models), Command R family (5 models), legacy Command (2 models)
  - RAG (Retrieval Augmented Generation) with document support and citations
  - Function/tool calling infrastructure with CohereTool and CohereToolCall types
  - Token counting via dedicated tokenize endpoint
  - Structured JSON outputs with optional JSON Schema validation
  - Safety modes (NONE, CONTEXTUAL, STRICT) for content filtering
  - Vision support for Command A Vision model (base64 and URL images)
  - SSE streaming support with typed events (message-start, content-delta, message-end, citation-start)
  - Complete request/response mapping between AIRequest and Cohere's chat format
  - Bearer token authentication
  - Context windows: 256K tokens (A/R families), 16K tokens (A Translate), 4K tokens (legacy)
  - Output limits: 8K tokens for all models
  - Cohere-specific features: response_format for JSON mode, documents for RAG, safety_mode configuration
- **Comprehensive Cohere test coverage** (48 tests)
  - MockCohereAPI.swift with sample responses for all Cohere endpoints (30+ mock responses)
  - CohereProviderTests (48 tests) covering initialization, request/response mapping, streaming, RAG, tool calling, tokenization, error handling, and model support
  - Updated ModelProviderTests and ProviderTypeTests for Cohere models
  - All tests passing (464+ total tests, 100% pass rate)
- **Cohere implementation documentation**
  - COHERE_IMPLEMENTATION_PLAN.md (624 lines) with comprehensive API specs, streaming event types, model specifications, and usage examples
  - Complete RAG documentation with document structure and citation handling
  - Tool/function calling documentation with type definitions
  - JSON structured output documentation with schema examples
  - Updated CLAUDE.md with Cohere provider information

### Changed
- Updated ModelProvider enum to include 11 Cohere models (total now 60 models: 22 Claude + 8 GPT + 5 Gemini + 3 Perplexity + 11 Mistral + 11 Cohere)
- Updated ProviderType enum (total now 7 providers: Anthropic, OpenAI, Google, Perplexity, Mistral, Cohere, Other)
- CohereProvider.swift replaced placeholder implementation with full functionality
- Updated all test assertions to reflect new model and provider counts

## [0.5.0] - 2025-11-23

### Added
- **Complete Mistral AI integration** (~1,700 lines total)
  - MistralModels.swift with full type definitions (641 lines) for Mistral API
  - MistralProvider implementation (353 lines) with sendMessage and streamMessage
  - Support for 11 Mistral models: Large 2.1, Medium 3, Small 3.1, Codestral, Magistral Small/Medium, Ministral 3B/8B
  - OpenAI-compatible API format for straightforward integration
  - SSE streaming support with delta accumulation for real-time responses
  - Vision support via image URLs and base64 data URLs (Large, Medium, Small models)
  - Tool/function calling infrastructure (OpenAI-compatible format)
  - Complete request/response mapping between AIRequest and Mistral's chat completion format
  - Bearer token authentication (same as OpenAI)
  - Context windows: 128K tokens (most models), 32K tokens (Codestral)
  - Output limits: 8K tokens (most models), 32K tokens (Magistral models)
  - Unique features: safe_prompt for security, random_seed for determinism, reasoning mode for Magistral models
- **Comprehensive Mistral test coverage** (30+ tests)
  - MockMistralAPI.swift with sample responses, streaming events, and error responses
  - MistralProviderTests (30 tests) covering initialization, request/response mapping, streaming, error handling, vision, and tool support
  - Updated ModelProviderTests and ProviderTypeTests for Mistral models
  - All tests passing (416+ total tests, 100% pass rate)
- **Mistral implementation documentation**
  - MISTRAL_IMPLEMENTATION_PLAN.md with comprehensive API specs, usage examples, and technical details
  - Updated CLAUDE.md with Mistral provider information

### Changed
- Updated ModelProvider enum to include 11 Mistral models (total now 49 models: 22 Claude + 8 GPT + 5 Gemini + 3 Perplexity + 11 Mistral)
- Updated ProviderType enum to include .mistral (total now 7 providers: Anthropic, OpenAI, Google, Perplexity, Mistral, Cohere, Other)
- MistralProvider.swift replaced placeholder implementation with full functionality
- Updated all test assertions to reflect new model and provider counts

## [0.4.1] - 2025-11-23

### Added
- **PerplexityOptions type-safe helper** (~147 lines)
  - Type-safe convenience API for Perplexity-specific provider options
  - Support for search domain filtering, recency filtering, citations, and images
  - Support for ResponseFormat with JSON Schema structured outputs
  - `toProviderOptions()` method converts to `[String: AnyCodable]` for AIRequest
  - `webSearch()` convenience initializer for search-focused requests
  - `jsonSchema()` convenience initializer for structured output requests
  - Comprehensive documentation with usage examples
- **Comprehensive test coverage for provider options** (36 new tests)
  - PerplexityOptionsTests (28 tests) covering all helper methods and conversions
  - Integration tests in PerplexityProviderTests (8 tests) for options extraction
  - Tests for `toProviderOptions()` conversion for all option types
  - Tests for `webSearch()` and `jsonSchema()` convenience initializers
  - Tests for integration with AIRequest.providerOptions field
- **Perplexity sample requests** (6 new examples)
  - perplexityWebSearch: Basic web search with recency filter
  - perplexityDomainFilter: Academic research with domain filtering
  - perplexityJsonSchema: Structured output with JSON Schema
  - perplexityFullOptions: All search options demonstration
  - perplexityAcademicResearch: Research-focused query example
  - perplexityBasic: Simple query without special options

### Changed
- Updated PerplexityProvider extraction functions to use AIRequest.providerOptions
- Resolved 5 critical TODOs in PerplexityProvider (providerOptions extraction)
- Updated test counts to reflect new tests (386+ total tests, 100% pass rate)

## [0.4.0] - 2025-11-23

### Added
- **Complete Perplexity AI integration** (~800 lines total)
  - PerplexityModels.swift with full type definitions (316 lines) for all Perplexity API features
  - PerplexityProvider implementation (235 lines) with sendMessage and streamMessage
  - Support for Sonar, Sonar Pro, and Sonar Reasoning models
  - Real-time web search capabilities with citation support
  - Domain filtering for search results (search_domain_filter)
  - Recency filtering for time-based searches (day, week, month, year)
  - JSON Schema structured outputs via response_format
  - SSE streaming support with text accumulation for real-time responses
  - Complete request/response mapping between AIRequest and Perplexity's chat completion format
  - Bearer token authentication
  - Context windows: 127K tokens (Sonar/Reasoning), 200K tokens (Sonar Pro)
  - Output limits: 4K tokens for all models
- **Comprehensive Perplexity test coverage** (27+ tests)
  - MockPerplexityAPI.swift with sample responses for all Perplexity endpoints
  - PerplexityProviderTests (27 tests) covering initialization, request/response mapping, error handling, search features, streaming, and model support
  - Updated ModelProviderTests and ProviderTypeTests for Perplexity models
  - Updated test counts across all test suites (330+ total tests, 100% pass rate)

### Changed
- Updated ModelProvider enum to include 3 Perplexity models (total now 38 models: 22 Claude + 8 GPT + 5 Gemini + 3 Perplexity)
- Updated ProviderType enum to include .perplexity (total now 6 providers)
- Updated all test assertions to reflect new model and provider counts

## [0.3.0] - 2025-11-23

### Added
- **Complete Google Gemini API integration** (~787 lines total)
  - GeminiModels.swift with full type definitions (451 lines) for all Gemini API features
  - GeminiProvider implementation (335 lines) with sendMessage, streamMessage, and countTokens
  - Support for Gemini 2.5 Pro, 2.5 Flash, 2.0 Flash Exp, 1.5 Pro, and 1.5 Flash models
  - Complete request/response mapping between AIRequest and Gemini's generateContent format
  - SSE streaming support with text accumulation for real-time responses
  - Multimodal support: text, images (base64), documents (PDFs via base64 or fileUri)
  - Safety settings configuration with 4 harm categories and thresholds
  - Function calling support with JSON Schema-based tool declarations
  - Structured output support via responseMimeType and responseSchema
  - Generation config: temperature, topP, topK, maxOutputTokens, stopSequences
  - Token counting support via countTokens endpoint
  - Context windows: 2M tokens for Pro models, 1M tokens for Flash models
  - Output limits: 65K tokens for 2.5 Pro, 8K tokens for other models
  - API key authentication via query parameter (x-goog-api-key)
- **Comprehensive Gemini test coverage** (46 tests)
  - MockGeminiAPI.swift with sample responses for all Gemini endpoints
  - GeminiProviderTests (38 tests) covering initialization, request/response mapping, error handling, safety settings, function calling, token counting, streaming, and model support
  - ModelProviderTests updates (8 tests) for Gemini model properties
  - Updated TESTING.md documentation (323 total tests, 100% pass rate)

### Changed
- Updated ModelProvider enum to include 5 Gemini models (total now 35 models: 22 Claude + 8 GPT + 5 Gemini)
- Updated CLAUDE.md with Gemini implementation status (moved from placeholder to fully implemented)
- Updated test count in TESTING.md from 277 to 323 tests

## [0.2.0] - 2025-11-23

### Added
- **Complete OpenAI GPT API integration** (~963 lines total)
  - OpenAIModels.swift with full type definitions (639 lines) for all OpenAI API features
  - OpenAIProvider implementation (324 lines) with sendMessage and streaming support
  - Support for GPT-4o, GPT-4o Mini, GPT-4 Turbo, GPT-4, and GPT-3.5 Turbo models
  - Complete request/response mapping between AIRequest and OpenAI's chat completion format
  - SSE streaming support with delta accumulation for real-time responses
  - Vision support for GPT-4o models (image URLs and base64 data URLs)
  - System prompt handling (prepended to messages array per OpenAI conventions)
  - Content block mapping for text and images
  - Finish reason mapping (stop, length, content_filter, tool_calls)
  - Bearer token authentication with optional organization ID support
  - Context windows: 128K tokens for GPT-4o/Mini, 128K for GPT-4 Turbo
  - Output limits: 16K tokens for GPT-4o/Mini, 4K for others
- Comprehensive test suite with 277 tests across 7 test suites (100% pass rate)
  - Mock infrastructure for testing (MockHTTPClient, MockProvider, MockAnthropicAPI)
  - Test data samples (SampleRequests, SampleResponses, SampleErrors)
  - AIErrorTests (42 tests) - All error types, retryability, status codes, error categories
  - APIKeyStrategyTests (33 tests) - All 4 key strategies with edge cases and real-world scenarios
  - ConfigurationTests (39 tests) - All 6 factory methods, beta features, custom URLs
  - ModelProviderTests (55 tests) - All 30 models with feature support and token limits
  - ProviderTypeTests (36 tests) - All 5 providers with conformances and base URLs
  - AIModelsTests (38 tests) - All message/request/response types with integration tests
  - ProviderProtocolTests (32 tests) - Batch operations, protocol conformance, streaming
  - TESTING.md comprehensive testing documentation
  - Guidelines for test contributions and CI/CD integration
- Complete Anthropic Claude API integration with full Messages and Batch API support
- APIKeyStrategy enum with 4 key management strategies (companyKey, clientKey, hybrid, perProvider)
- Configuration struct with convenience factory methods (withCompanyKey, withClientKeys, withHybridKeys, development, production)
- Thread-safe AIGateway actor for provider coordination and API key resolution
- Comprehensive AIError with 20+ specialized error types (authentication, network, validation, rate limiting, etc.)
- AnthropicModels.swift with complete type definitions (~700 lines) for all Anthropic features
- ModelProvider enum with all 27 Claude models (Opus 4.1, Sonnet 4.5, Haiku 4.5, legacy models)
- HTTPClientManager with automatic retry logic, exponential backoff, and timeout management
- ProviderProtocol with default implementations for batch operations
- Complete AnthropicProvider implementation (~620 lines) with 3 flexible initializer variants
- Full support for advanced Anthropic features: prompt caching, extended thinking, tool use, vision, PDF processing
- Complete Batch API support (create, retrieve, cancel, list, results streaming with JSONL)
- Vapor Request+AI extension with convenience methods and automatic client key extraction from headers
- Vapor Application+AI extension with fluent initialization API
- SSE (Server-Sent Events) streaming support for real-time AI responses
- Git workflow guidelines in CLAUDE.md emphasizing small, atomic commits

### Changed
- Enhanced all model structures (AIRequest, AIResponse, AIMessage) to support multi-content and Anthropic features
- Updated ProviderProtocol with batch operation methods and default implementations
- Improved HTTPClientManager with streaming support and better error mapping

### Fixed
- Sendable conformance issues with AnyCodable using @unchecked Sendable
- Actor isolation issues in HTTPClientManager (streamPost, mapHTTPError)
- Actor isolation issues in AIGateway initialization
- Configuration parameter ordering in static factory methods
- Request+AI streaming methods with proper async Task wrapping

## [0.1.0] - 2025-11-22

### Added
- Initial project structure for SwiftlyAIKit AI Gateway framework
- Package configuration with Vapor 4.99.0+ and AsyncHTTPClient 1.19.0+ dependencies
- Core directory structure (Models, Providers, Core, Extensions, Utilities)
- Placeholder implementations for all major components:
  - Model structures (AIRequest, AIResponse, AIMessage, AIError)
  - Provider protocol and implementations (OpenAI, Anthropic, Cohere, Google, Mistral)
  - Core gateway and configuration components
  - Vapor integration extensions
  - HTTP client and JSON utilities
- MIT License
- Comprehensive README with installation and usage guidelines
- Basic test structure using Swift Testing framework

[Unreleased]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Swiftly-Developed/SwiftlyAIKit/releases/tag/v0.1.0
