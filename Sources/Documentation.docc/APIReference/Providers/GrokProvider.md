# ``GrokProvider``

Complete API reference for xAI Grok integration.

## Overview

The `GrokProvider` gives you access to Grok 4, Grok 3, Grok 2 Vision, Grok Code Fast, and Grok 2 Image models with reasoning capabilities, web search, and image generation.

**Key Features:**
- ✅ Chat Completions API (create, stream)
- ✅ Reasoning tokens tracking
- ✅ Automatic prompt caching
- ✅ Tool/function calling
- ✅ Vision support (Grok 2 Vision)
- ✅ Token counting endpoint
- ✅ Live web search
- ✅ Image generation (Grok 2 Image)

**Context Window**: 1M tokens | **Models**: 7 variants | **Vision**: ✓

## Topics

### Provider Implementation
- ``GrokProvider``

### Request Types
- ``GrokRequest``
- ``GrokMessage``
- ``GrokMessageRole``
- ``GrokMessageContent``

### Response Types
- ``GrokResponse``
- ``GrokChoice``
- ``GrokUsage``
- ``GrokFinishReason``

### Streaming Types
- ``GrokStreamChunk``
- ``GrokStreamDelta``
- ``GrokStreamChoice``

### Tool Calling
- ``GrokTool``
- ``GrokToolCall``
- ``GrokToolType``
- ``GrokFunction``

### Image Generation
- ``GrokImageRequest``
- ``GrokImageResponse``
- ``GrokImageData``

### Token Counting
- ``GrokTokenizeRequest``
- ``GrokTokenizeResponse``

### Web Search
- ``GrokSearchParameters``

### Models & Configuration
- <doc:GrokGuide>
