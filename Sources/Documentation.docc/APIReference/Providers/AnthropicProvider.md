# ``AnthropicProvider``

Complete API reference for Anthropic Claude integration.

## Overview

The `AnthropicProvider` gives you access to Claude 3.5 Sonnet, Claude 3.5 Haiku, Claude 3 Opus, and other Claude models with industry-leading context windows and reasoning capabilities.

**Key Features:**
- ✅ Messages API (create, stream)
- ✅ Batch API (async bulk processing)
- ✅ Prompt caching (90% cost reduction on repeated content)
- ✅ Extended thinking mode (advanced reasoning)
- ✅ Tool use (function calling)
- ✅ Vision support (image analysis, PDF processing)

**Context Window**: 200K tokens | **Models**: 6 variants | **Streaming**: ✓

## Topics

### Provider Implementation
- ``AnthropicProvider``

### Request Types
- ``AnthropicRequest``
- ``AnthropicMessage``
- ``AnthropicSystemPrompt``
- ``AnthropicMessageRole``

### Response Types
- ``AnthropicResponse``
- ``AnthropicUsage``
- ``AnthropicStopReason``

### Content Blocks
- ``AnthropicContentBlock``
- ``AnthropicTextBlock``
- ``AnthropicImageBlock``
- ``AnthropicDocumentBlock``

### Tool Use
- ``AnthropicToolUse``
- ``AnthropicToolResult``
- ``AnthropicToolChoice``

### Batch Processing
- ``AnthropicBatch``
- ``AnthropicBatchRequest``
- ``AnthropicBatchStatus``
- ``AnthropicBatchProcessingStatus``
- ``AnthropicBatchResults``

### Streaming
- ``AnthropicStreamEvent``
- ``AnthropicStreamEventType``

### Models & Configuration
- <doc:AnthropicGuide>
