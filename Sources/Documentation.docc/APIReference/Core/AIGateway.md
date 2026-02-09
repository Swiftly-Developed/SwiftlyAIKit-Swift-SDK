# ``AIGateway``

Main coordinator actor for multi-provider AI operations.

## Overview

The `AIGateway` is a thread-safe actor that coordinates all AI operations across multiple providers. It provides a unified interface for sending messages, streaming responses, managing batches, and generating images.

**Key Responsibilities:**
- Routes requests to appropriate AI providers
- Manages API key resolution and authentication
- Coordinates batch operations across providers
- Handles provider registration and lifecycle
- Provides unified error handling

## Topics

### Creating a Gateway
- ``init(configuration:)``
- ``init(configuration:providers:)``
- ``Configuration``

### Core Operations
- ``sendMessage(_:to:clientAPIKey:)``
- ``streamMessage(_:to:clientAPIKey:)``
- ``countTokens(_:for:clientAPIKey:)``

### Batch Processing
- ``createBatch(_:for:clientAPIKey:)``
- ``retrieveBatch(_:from:clientAPIKey:)``
- ``cancelBatch(_:from:clientAPIKey:)``
- ``listBatches(limit:afterId:from:clientAPIKey:)``
- ``getBatchResults(_:from:clientAPIKey:)``

### Image Generation
- ``generateImage(_:using:clientAPIKey:)``
- ``supportsImageGeneration(for:)``
- ``imageGenerationModels(for:)``

### Provider Management
- ``registerProvider(_:for:)``
- ``isProviderRegistered(_:)``
- ``registeredProviders``

### Configuration
- ``config``
