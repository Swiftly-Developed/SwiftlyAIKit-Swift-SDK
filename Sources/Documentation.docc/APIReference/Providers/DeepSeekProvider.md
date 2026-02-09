# ``DeepSeekProvider``

Complete API reference for DeepSeek AI integration.

## Overview

The `DeepSeekProvider` gives you access to DeepSeek Chat and DeepSeek Coder models with cost optimization, prompt caching, and reasoning capabilities.

**Key Features:**
- ✅ Chat Completions API (create, stream)
- ✅ Tool/function calling support
- ✅ Prompt caching for cost reduction
- ✅ Reasoning mode (DeepSeek-R1)
- ✅ SSE streaming support
- ✅ Cost-effective pricing

**Context Window**: 64K tokens | **Models**: 2+ variants | **Reasoning**: ✓

## Topics

### Provider Implementation
- ``DeepSeekProvider``

### Request Types
- ``DeepSeekRequest``
- ``DeepSeekMessage``
- ``DeepSeekMessageRole``

### Response Types
- ``DeepSeekResponse``
- ``DeepSeekChoice``
- ``DeepSeekUsage``
- ``DeepSeekFinishReason``

### Tool Calling
- ``DeepSeekTool``
- ``DeepSeekToolCall``
- ``DeepSeekFunction``

### Streaming
- ``DeepSeekStreamChunk``
- ``DeepSeekStreamDelta``

### Models & Configuration
- <doc:DeepSeekGuide>
