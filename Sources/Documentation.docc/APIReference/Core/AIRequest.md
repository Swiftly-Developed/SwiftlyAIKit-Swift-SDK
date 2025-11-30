# ``AIRequest``

Unified request types for AI operations.

## Overview

The `AIRequest` type provides a unified interface for making requests across all AI providers. It abstracts provider-specific details while supporting advanced features like tool calling, vision, and streaming.

**Key Features:**
- Model selection from any provider
- Message history with roles (system, user, assistant)
- Tool/function calling support
- Vision support (image URLs and data)
- Streaming configuration
- Provider-specific options

## Topics

### Request Types
- ``AIRequest``
- ``AIMessage``
- ``AIMessageRole``
- ``AIMessageContent``

### Tool Calling
- ``AITool``
- ``AIToolParameter``
- ``AIToolChoice``

### Content Types
- ``AIContentPart``
- ``AIImageSource``
- ``AIDocumentSource``

### Model Selection
- ``ModelProvider``
- ``ProviderType``
