# ``GeminiProvider``

Complete API reference for Google Gemini integration.

## Overview

The `GeminiProvider` (also available as `GoogleProvider`) gives you access to Gemini 2.5 Pro, 2.5 Flash, and other Google models with massive context windows and advanced multimodal capabilities.

**Key Features:**
- ✅ GenerateContent API (create, stream)
- ✅ Token counting support
- ✅ Multimodal (text, images, documents)
- ✅ Function calling with JSON Schema
- ✅ Safety settings configuration
- ✅ Structured output support

**Context Window**: 2M tokens | **Models**: 5+ variants | **Multimodal**: ✓

## Topics

### Provider Implementation
- ``GeminiProvider``
- ``GoogleProvider``

### Request Types
- ``GeminiRequest``
- ``GeminiContent``
- ``GeminiPart``
- ``GeminiRole``

### Response Types
- ``GeminiResponse``
- ``GeminiCandidate``
- ``GeminiUsageMetadata``
- ``GeminiFinishReason``

### Safety Settings
- ``GeminiSafetySetting``
- ``GeminiHarmCategory``
- ``GeminiHarmBlockThreshold``
- ``GeminiSafetyRating``

### Function Calling
- ``GeminiFunctionDeclaration``
- ``GeminiTool``
- ``GeminiFunctionCall``
- ``GeminiFunctionResponse``

### Generation Configuration
- ``GeminiGenerationConfig``

### Token Counting
- ``GeminiTokenCountRequest``
- ``GeminiTokenCountResponse``

### Models & Configuration
- <doc:GeminiGuide>
