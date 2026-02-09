# ``ImageGenerationRequest``

Image generation types and operations.

## Overview

SwiftlyAIKit supports image generation through providers like OpenAI (DALL-E) and xAI (Grok 2 Image). The unified interface allows you to generate images from text prompts with various size, quality, and style options.

**Supported Providers:**
- OpenAI DALL-E 3 (high-quality, photorealistic)
- xAI Grok 2 Image (creative, diverse styles)

**Key Features:**
- Text-to-image generation
- Size customization (256x256 to 1792x1024)
- Quality settings (standard, HD)
- Style options (natural, vivid)
- URL or base64 data responses

## Topics

### Request Types
- ``ImageGenerationRequest``
- ``ImageGenerationSize``
- ``ImageGenerationQuality``
- ``ImageGenerationStyle``

### Response Types
- ``ImageGenerationResponse``
- ``GeneratedImage``
- ``ImageFormat``

### Provider Support
- ``AIGateway/generateImage(_:using:clientAPIKey:)``
- ``AIGateway/supportsImageGeneration(for:)``
- ``AIGateway/imageGenerationModels(for:)``
