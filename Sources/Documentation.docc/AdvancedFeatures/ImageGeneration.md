# Image Generation

Generate images from text prompts using AI.

## Overview

SwiftlyAIKit supports image generation through three providers:
- **OpenAI DALL-E 3** - Highest quality, most features
- **xAI Grok 2 Image** - Fast, competitive quality
- **Apple Intelligence** - On-device, free, privacy-focused

Learn how to generate images, customize parameters, and display results.

## Quick Start

### Basic Image Generation

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-...")
let gateway = AIGateway(configuration: config)

let request = ImageGenerationRequest.dallE3(
    prompt: "A serene mountain landscape at sunset",
    size: .square1024,
    quality: .hd
)

let response = try await gateway.generateImage(request, using: .openai)

for image in response.images {
    if let url = image.url {
        print("Image URL: \(url)")
        // Download and display
    }
}
```

## Supported Providers

### OpenAI DALL-E 3 (Recommended)

**Best for:** Highest quality, most control

```swift
let request = ImageGenerationRequest.dallE3(
    prompt: "A cyberpunk cityscape at night, neon lights reflecting in rain",
    size: .landscape1792x1024,
    quality: .hd,
    style: .vivid
)

let response = try await gateway.generateImage(request, using: .openai)
```

**Specifications:**
- **Sizes:** 1024x1024, 1024x1792, 1792x1024
- **Quality:** standard, hd
- **Style:** natural, vivid
- **Pricing:** $0.040 (standard), $0.080 (hd), $0.120 (hd + 1792x1024)

### xAI Grok 2 Image

**Best for:** Fast generation, competitive quality

```swift
let request = ImageGenerationRequest(
    prompt: "An astronaut riding a horse on Mars",
    model: "grok-2-image",
    numberOfImages: 1,
    size: .square1024
)

let response = try await gateway.generateImage(request, using: .grok)
```

**Specifications:**
- **Sizes:** Multiple aspect ratios
- **Pricing:** $0.005 per image
- **Speed:** < 10 seconds
- **Quality:** Good

### Apple Intelligence (On-Device)

**Best for:** Privacy, zero cost

```swift
let request = ImageGenerationRequest(
    prompt: "A peaceful garden scene",
    model: "apple-image-playground",
    numberOfImages: 1
)

let response = try await gateway.generateImage(request, using: .appleIntelligence)
```

**Specifications:**
- **Privacy:** Completely on-device
- **Cost:** FREE
- **Network:** Not required
- **Requirements:** Apple Silicon Mac or A17 Pro+ iPhone

## Image Sizes and Formats

### DALL-E 3 Sizes

```swift
// Square
let square = ImageGenerationRequest.dallE3(
    prompt: "A sunset",
    size: .square1024 // 1024x1024
)

// Landscape
let landscape = ImageGenerationRequest.dallE3(
    prompt: "A wide vista",
    size: .landscape1792x1024 // 1792x1024
)

// Portrait
let portrait = ImageGenerationRequest.dallE3(
    prompt: "A tall building",
    size: .portrait1024x1792 // 1024x1792
)
```

### Image Quality

```swift
// Standard quality (cheaper, faster)
let standard = ImageGenerationRequest.dallE3(
    prompt: "A sunset",
    size: .square1024,
    quality: .standard // $0.040
)

// HD quality (better detail)
let hd = ImageGenerationRequest.dallE3(
    prompt: "A sunset",
    size: .square1024,
    quality: .hd // $0.080
)
```

### Art Styles

```swift
// Natural style (realistic)
let natural = ImageGenerationRequest.dallE3(
    prompt: "A forest scene",
    style: .natural
)

// Vivid style (more dramatic)
let vivid = ImageGenerationRequest.dallE3(
    prompt: "A forest scene",
    style: .vivid
)
```

## SwiftUI Integration

### Display Generated Image

```swift
import SwiftUI
import SwiftlyAIKit

struct ImageGenerationView: View {
    @State private var prompt = "A serene mountain landscape"
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false

    let gateway: AIGateway

    var body: some View {
        VStack {
            TextField("Describe an image", text: $prompt)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("Generate") {
                Task {
                    await generateImage()
                }
            }
            .disabled(isGenerating || prompt.isEmpty)

            if isGenerating {
                ProgressView("Generating...")
                    .padding()
            }

            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .cornerRadius(12)
                    .shadow(radius: 8)
            }
        }
        .padding()
    }

    func generateImage() async {
        isGenerating = true

        let request = ImageGenerationRequest.dallE3(
            prompt: prompt,
            size: .square1024,
            quality: .hd
        )

        do {
            let response = try await gateway.generateImage(request, using: .openai)

            if let imageURL = response.images.first?.url,
               let url = URL(string: imageURL) {
                let (data, _) = try await URLSession.shared.data(from: url)
                generatedImage = UIImage(data: data)
            }
        } catch {
            print("Error: \(error)")
        }

        isGenerating = false
    }
}
```

### Save Generated Images

```swift
func saveGeneratedImage(_ image: UIImage) throws {
    guard let data = image.jpegData(compressionQuality: 0.9) else {
        throw ImageError.cannotConvert
    }

    let filename = "generated-\(UUID().uuidString).jpg"
    let documentsURL = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0]

    let fileURL = documentsURL.appendingPathComponent(filename)

    try data.write(to: fileURL)
    print("Saved to: \(fileURL.path)")
}
```

## Advanced Techniques

### Batch Generation

Generate multiple variations:

```swift
let prompts = [
    "A sunset over mountains",
    "A sunrise over ocean",
    "A moonlit forest",
    "A starry night sky"
]

var images: [UIImage] = []

for prompt in prompts {
    let request = ImageGenerationRequest.dallE3(
        prompt: prompt,
        size: .square1024
    )

    let response = try await gateway.generateImage(request, using: .openai)

    if let imageURL = response.images.first?.url,
       let url = URL(string: imageURL),
       let data = try? Data(contentsOf: url),
       let image = UIImage(data: data) {
        images.append(image)
    }
}
```

### Refined Prompts

```swift
func refinePrompt(_ userPrompt: String) -> String {
    """
    \(userPrompt),
    high quality, detailed,
    professional photography,
    8k resolution,
    dramatic lighting
    """
}

let prompt = refinePrompt("A coffee shop")
let request = ImageGenerationRequest.dallE3(
    prompt: prompt,
    quality: .hd
)
```

### Error Handling

```swift
func generateImageSafely(_ prompt: String) async -> UIImage? {
    let request = ImageGenerationRequest.dallE3(
        prompt: prompt,
        size: .square1024
    )

    do {
        let response = try await gateway.generateImage(request, using: .openai)

        guard let imageURL = response.images.first?.url,
              let url = URL(string: imageURL) else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)

    } catch AIError.validationError(let message) {
        print("Invalid prompt: \(message)")
        return nil
    } catch AIError.rateLimitExceeded(let retryAfter) {
        print("Rate limited. Retry after \(retryAfter)s")
        return nil
    } catch {
        print("Error: \(error)")
        return nil
    }
}
```

## Cost Management

### Track Generation Costs

```swift
actor ImageCostTracker {
    private var totalImages = 0
    private var totalCost: Double = 0

    func recordGeneration(quality: ImageQuality, size: ImageSize) {
        totalImages += 1

        let cost: Double
        switch (quality, size) {
        case (.standard, .square1024):
            cost = 0.040
        case (.hd, .square1024):
            cost = 0.080
        case (.hd, .landscape1792x1024), (.hd, .portrait1024x1792):
            cost = 0.120
        default:
            cost = 0.040
        }

        totalCost += cost
    }

    func getStats() -> (images: Int, cost: Double) {
        (totalImages, totalCost)
    }
}

let tracker = ImageCostTracker()

let response = try await gateway.generateImage(request, using: .openai)
await tracker.recordGeneration(quality: .hd, size: .square1024)

let stats = await tracker.getStats()
print("Generated \(stats.images) images for $\(String(format: "%.2f", stats.cost))")
```

## Best Practices

### ✅ Do

- Be specific in prompts (more detail = better results)
- Use HD quality for important images
- Cache/save generated images (don't regenerate)
- Handle errors gracefully
- Track costs
- Validate prompts before generating

### ❌ Don't

- Generate same image repeatedly (cache it!)
- Use low-quality prompts
- Ignore content policy violations
- Generate excessively (costs add up)
- Forget to save images (they expire)

## Prompt Engineering

### Good Prompts

✅ **Specific and detailed:**
```swift
"A professional photograph of a modern minimalist living room,
large windows with natural light, white walls, wooden floors,
indoor plants, Scandinavian furniture, 8k quality"
```

❌ **Vague:**
```swift
"A nice room"
```

✅ **With style guidance:**
```swift
"An oil painting in the style of Van Gogh, swirling brushstrokes,
vibrant colors, a wheat field under a starry night sky"
```

✅ **With composition details:**
```swift
"A portrait photograph, medium shot, shallow depth of field,
golden hour lighting, subject looking off-camera, blurred background"
```

## Provider Comparison

| Feature | DALL-E 3 | Grok 2 Image | Apple Intelligence |
|---------|----------|--------------|-------------------|
| **Quality** | Excellent | Good | Good |
| **Speed** | 10-20s | < 10s | Fast |
| **Cost** | $0.04-$0.12 | $0.005 | FREE |
| **Sizes** | 3 options | Multiple | Limited |
| **Styles** | Natural/Vivid | Standard | Standard |
| **Privacy** | Cloud | Cloud | On-device |

## Content Policy

All providers have content policies:

**Not allowed:**
- Violence or gore
- Sexual or suggestive content
- Hate symbols or content
- Illegal activities
- Deceptive content

**Handling violations:**
```swift
do {
    let response = try await gateway.generateImage(request)
} catch AIError.validationError(let message) where message.contains("content_policy") {
    print("Prompt violates content policy")
    // Show user-friendly message
}
```

## See Also

- ``ImageGenerationRequest``
- ``ImageGenerationResponse``
- ``ImageGenerationProvider``
- <doc:OpenAIGuide>
- <doc:GrokGuide>
- <doc:AppleIntelligenceGuide>
