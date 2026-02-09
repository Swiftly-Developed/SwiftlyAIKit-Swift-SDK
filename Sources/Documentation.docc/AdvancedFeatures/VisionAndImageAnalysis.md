# Vision and Image Analysis

Analyze images using AI vision models.

## Overview

SwiftlyAIKit supports vision (image analysis) through multiple providers:
- **OpenAI GPT-4o** - Best quality
- **Google Gemini** - Multimodal, good quality
- **Anthropic Claude** - Excellent analysis, supports PDFs
- **Mistral Large** - Cost-effective
- **xAI Grok 2 Vision** - Real-time data integration
- **Cohere Command A Vision** - Enterprise features

This guide shows you how to analyze images, process multiple images, and build vision-powered applications.

## Basic Image Analysis

### Analyze an Image URL

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .gpt4(.o),
    messages: [
        .user([
            .text("What's in this image?"),
            .image(url: "https://example.com/photo.jpg")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .openai)
print(response.message.content)
// "The image shows a golden retriever playing in a park..."
```

### Analyze Base64 Image

```swift
let imageData = UIImage(named: "photo")!.jpegData(compressionQuality: 0.8)!
let base64 = imageData.base64EncodedString()

let request = AIRequest(
    model: .gpt4(.o),
    messages: [
        .user([
            .text("Describe this image in detail"),
            .image(data: base64, mediaType: "image/jpeg")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .openai)
```

## Provider Comparison

### Quality Comparison

| Provider | Quality | Speed | Cost | Best For |
|----------|---------|-------|------|----------|
| **OpenAI GPT-4o** | Excellent | Fast | $$ | General vision |
| **Google Gemini** | Very Good | Fast | $ | Multimodal tasks |
| **Anthropic Claude** | Excellent | Medium | $$$ | Detailed analysis |
| **Mistral Large** | Good | Fast | $ | Cost-effective |
| **Grok 2 Vision** | Good | Fast | $$ | Real-time context |

### Provider Examples

#### OpenAI GPT-4o (Best Quality)

```swift
let request = AIRequest(
    model: .gpt4(.o),
    messages: [
        .user([
            .text("Identify all objects in this image and their locations"),
            .image(url: imageURL)
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .openai)
```

#### Google Gemini (Multimodal)

```swift
let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [
        .user([
            .text("Analyze this image"),
            .image(data: base64, mediaType: "image/jpeg")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .google)
```

**Note:** Gemini requires base64, not URLs

#### Anthropic Claude (PDF Support)

```swift
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [
        .user([
            .text("Summarize this PDF"),
            .document(base64: pdfBase64, mediaType: "application/pdf")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .anthropic)
```

## Multiple Images

### Compare Images

```swift
let request = AIRequest(
    model: .gpt4(.o),
    messages: [
        .user([
            .text("Compare these two images. What are the differences?"),
            .image(url: "https://example.com/before.jpg"),
            .image(url: "https://example.com/after.jpg")
        ])
    ]
)

let response = try await gateway.sendMessage(request, to: .openai)
```

### Analyze Image Sequence

```swift
let images = [
    "https://example.com/step1.jpg",
    "https://example.com/step2.jpg",
    "https://example.com/step3.jpg"
]

var content: [AIMessage.Content] = [.text("Describe the sequence of events in these images:")]
content.append(contentsOf: images.map { .image(url: $0) })

let request = AIRequest(
    model: .gpt4(.o),
    messages: [.user(content)]
)

let response = try await gateway.sendMessage(request, to: .openai)
```

## Common Use Cases

### OCR (Text Extraction)

```swift
func extractText(from imageURL: String) async throws -> String {
    let request = AIRequest(
        model: .gpt4(.o),
        messages: [
            .user([
                .text("Extract all text from this image. Return only the text, nothing else."),
                .image(url: imageURL)
            ])
        ]
    )

    let response = try await gateway.sendMessage(request, to: .openai)
    return response.message.content
}
```

### Product Description Generator

```swift
func describeProduct(imageURL: String) async throws -> ProductDescription {
    let request = AIRequest(
        model: .gpt4(.o),
        messages: [
            .user([
                .text("""
                Analyze this product image and provide:
                1. Product name and category
                2. Key features visible
                3. Marketing description (2 sentences)
                4. Suggested price range
                Return as JSON.
                """),
                .image(url: imageURL)
            ])
        ],
        responseFormat: .json
    )

    let response = try await gateway.sendMessage(request, to: .openai)
    let json = response.message.content.data(using: .utf8)!
    return try JSONDecoder().decode(ProductDescription.self, from: json)
}

struct ProductDescription: Codable {
    let name: String
    let category: String
    let features: [String]
    let description: String
    let priceRange: String
}
```

### Image Moderation

```swift
func moderateImage(_ imageURL: String) async throws -> ModerationResult {
    let request = AIRequest(
        model: .gpt4(.o),
        messages: [
            .user([
                .text("""
                Analyze this image for:
                - Inappropriate content
                - Violence
                - Explicit material
                Return: {"safe": boolean, "reason": "string"}
                """),
                .image(url: imageURL)
            ])
        ],
        responseFormat: .json
    )

    let response = try await gateway.sendMessage(request, to: .openai)
    let json = response.message.content.data(using: .utf8)!
    return try JSONDecoder().decode(ModerationResult.self, from: json)
}

struct ModerationResult: Codable {
    let safe: Bool
    let reason: String
}
```

### Diagram Understanding

```swift
func analyzeDiagram(_ imageURL: String) async throws -> DiagramAnalysis {
    let request = AIRequest(
        model: .claude(.sonnet4_5),
        messages: [
            .user([
                .text("""
                Analyze this technical diagram:
                1. What type of diagram is this? (flowchart, architecture, UML, etc.)
                2. What are the main components?
                3. How do they interact?
                4. What is the overall purpose?
                """),
                .image(url: imageURL)
            ])
        ]
    )

    let response = try await gateway.sendMessage(request, to: .anthropic)
    // Claude excels at technical diagram analysis
    return DiagramAnalysis(description: response.message.content)
}
```

## SwiftUI Complete Example

```swift
struct VisionAnalyzerView: View {
    @State private var selectedImage: UIImage?
    @State private var analysis = ""
    @State private var isAnalyzing = false
    @State private var showImagePicker = false
    @State private var selectedProvider: ProviderType = .openai

    let gateway: AIGateway

    var body: some View {
        VStack(spacing: 20) {
            // Provider picker
            Picker("Provider", selection: $selectedProvider) {
                Text("GPT-4o").tag(ProviderType.openai)
                Text("Claude").tag(ProviderType.anthropic)
                Text("Gemini").tag(ProviderType.google)
            }
            .pickerStyle(.segmented)

            // Image display
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)

                Button("Analyze with \(selectedProvider.rawValue)") {
                    Task {
                        await analyzeImage()
                    }
                }
                .disabled(isAnalyzing)

                Button("Select Different Image") {
                    showImagePicker = true
                }
            } else {
                Button("Select Image") {
                    showImagePicker = true
                }
            }

            // Analysis result
            if isAnalyzing {
                ProgressView("Analyzing...")
            }

            ScrollView {
                Text(analysis)
                    .padding()
            }
        }
        .padding()
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }

    func analyzeImage() async {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        isAnalyzing = true

        let base64 = imageData.base64EncodedString()

        let request = AIRequest(
            model: .custom("model"),
            messages: [
                .user([
                    .text("Provide a detailed analysis of this image"),
                    .image(data: base64, mediaType: "image/jpeg")
                ])
            ]
        )

        do {
            let response = try await gateway.sendMessage(request, to: selectedProvider)
            analysis = response.message.content
        } catch {
            analysis = "Error: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }
}
```

## See Also

- <doc:OpenAIGuide>
- <doc:GeminiGuide>
- <doc:AnthropicGuide>
- <doc:SwiftUIIntegration>
- ``AIRequest``
- ``AIMessage``
