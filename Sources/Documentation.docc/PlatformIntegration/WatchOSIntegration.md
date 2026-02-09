# watchOS, tvOS, and visionOS Integration

Build AI-powered apps for Apple's extended platforms.

## Overview

SwiftlyAIKit works on all Apple platforms:
- **watchOS** - AI on your wrist
- **tvOS** - AI on the big screen
- **visionOS** - AI in spatial computing

This guide shows platform-specific considerations and examples.

## watchOS Integration

### Considerations

**Constraints:**
- Limited screen space
- Shorter user sessions
- Battery life concerns
- Smaller memory footprint

**Best practices:**
- Use shorter prompts
- Set lower maxTokens (100-200)
- Prefer non-streaming for simplicity
- Use Claude Haiku or GPT-4o Mini (faster)

### Simple watchOS View

```swift
import SwiftUI
import SwiftlyAIKit

struct WatchChatView: View {
    @State private var question = ""
    @State private var answer = ""
    @State private var isLoading = false

    let gateway: AIGateway

    var body: some View {
        VStack {
            ScrollView {
                Text(answer)
                    .font(.caption)
            }

            TextField("Ask", text: $question)
                .textFieldStyle(.roundedBorder)

            Button("Send") {
                Task {
                    await ask()
                }
            }
            .disabled(isLoading || question.isEmpty)
        }
        .padding()
    }

    func ask() async {
        isLoading = true

        let request = AIRequest(
            model: .claude(.haiku3_5), // Fast model for watch
            prompt: question,
            maxTokens: 150 // Keep responses short
        )

        do {
            let response = try await gateway.sendMessage(request)
            answer = response.message.content
        } catch {
            answer = "Error: \(error.localizedDescription)"
        }

        isLoading = false
        question = ""
    }
}
```

### Watch Complications

```swift
import ClockKit
import SwiftlyAIKit

class ComplicationController: CLKComplicationDataSource {
    let gateway: AIGateway

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        Task {
            let summary = await fetchDailySummary()
            // Display in complication
            handler(createEntry(summary: summary))
        }
    }

    func fetchDailySummary() async -> String {
        let request = AIRequest(
            model: .claude(.haiku3_5),
            prompt: "Summarize today's events in 20 words",
            maxTokens: 50
        )

        do {
            let response = try await gateway.sendMessage(request)
            return response.message.content
        } catch {
            return "Unable to load summary"
        }
    }
}
```

## tvOS Integration

### Considerations

**Platform features:**
- Large display
- Remote control input
- Voice input via Siri Remote
- No keyboard by default

**Best practices:**
- Use larger text
- Optimize for remote navigation
- Support voice input
- Consider streaming for better UX

### tvOS Chat Interface

```swift
import SwiftUI
import SwiftlyAIKit

struct TVChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var inputFocused: Bool

    init(gateway: AIGateway) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(gateway: gateway))
    }

    var body: some View {
        HStack(spacing: 40) {
            // Messages (larger for TV viewing distance)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.messages) { message in
                        MessageRow(message: message)
                            .font(.title3) // Larger for TV
                    }

                    if viewModel.isStreaming {
                        StreamingRow(text: viewModel.streamingText)
                            .font(.title3)
                    }
                }
                .padding(60) // More padding for TV
            }
            .frame(maxWidth: 1200)

            // Input sidebar
            VStack {
                TextField("Ask anything", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)

                Button("Send") {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.inputText.isEmpty || viewModel.isStreaming)
            }
            .frame(width: 400)
        }
    }
}
```

## visionOS Integration

### Considerations

**Spatial computing features:**
- 3D space
- Hand tracking
- Eye tracking
- Immersive experiences

**Best practices:**
- Consider spatial UI placement
- Use volumes for rich content
- Leverage eye tracking for input
- Support immersive modes

### visionOS Chat Window

```swift
import SwiftUI
import SwiftlyAIKit

struct SpatialChatView: View {
    @StateObject private var viewModel: ChatViewModel

    init(gateway: AIGateway) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(gateway: gateway))
    }

    var body: some View {
        NavigationSplitView {
            // Conversation list in sidebar
            List(viewModel.conversations) { conversation in
                Text(conversation.title)
            }
        } detail: {
            // Chat view in main area
            ChatView(viewModel: viewModel)
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            // Input field as ornament
            ChatInputOrnament(viewModel: viewModel)
        }
    }
}

struct ChatInputOrnament: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        HStack {
            TextField("Message", text: $viewModel.inputText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)

            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(viewModel.inputText.isEmpty)
        }
        .padding()
        .glassBackgroundEffect()
    }
}
```

## Shared Code Across Platforms

### Universal Gateway Setup

```swift
#if os(watchOS)
import WatchKit
#elseif os(tvOS)
import TVUIKit
#elseif os(visionOS)
import RealityKit
#endif

import SwiftlyAIKit

class AIService: ObservableObject {
    let gateway: AIGateway

    init() {
        guard let apiKey = getAPIKey() else {
            fatalError("API key not configured")
        }

        let config = Configuration.withCompanyKey(apiKey)
        self.gateway = AIGateway(configuration: config)
    }

    private func getAPIKey() -> String? {
        #if os(watchOS) || os(tvOS)
        // Use shared container with iPhone app
        if let sharedDefaults = UserDefaults(suiteName: "group.com.yourapp.shared") {
            return sharedDefaults.string(forKey: "apiKey")
        }
        #elseif os(visionOS)
        return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        #endif

        return nil
    }
}
```

### Platform-Optimized Models

```swift
func selectModelForPlatform() -> ModelProvider {
    #if os(watchOS)
    return .claude(.haiku3_5) // Fastest for watch
    #elseif os(tvOS)
    return .claude(.sonnet4_5) // Quality for big screen
    #elseif os(visionOS)
    return .claude(.sonnet4_5) // Premium experience
    #else
    return .claude(.sonnet4_5) // Default
    #endif
}
```

## Best Practices by Platform

### watchOS
- ✅ Use Haiku or GPT-4o Mini (fast)
- ✅ Limit maxTokens (100-200)
- ✅ Keep prompts short
- ✅ Non-streaming preferred
- ❌ Avoid long conversations (memory)
- ❌ Don't use image generation

### tvOS
- ✅ Use larger fonts
- ✅ Optimize for remote navigation
- ✅ Streaming for better UX
- ✅ Support voice input
- ❌ Avoid small touch targets
- ❌ Don't assume keyboard

### visionOS
- ✅ Use spatial layout
- ✅ Support immersive modes
- ✅ Leverage eye tracking
- ✅ Use volumes for rich content
- ❌ Don't force 2D thinking
- ❌ Avoid cluttered interfaces

## See Also

- <doc:SwiftUIIntegration>
- <doc:UIKitIntegration>
- <doc:StreamingResponses>
- ``AIGateway``
