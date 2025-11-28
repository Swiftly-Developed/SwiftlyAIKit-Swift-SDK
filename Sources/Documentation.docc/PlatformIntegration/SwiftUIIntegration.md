# SwiftUI Integration

Build AI-powered SwiftUI apps with SwiftlyAIKit.

## Overview

This guide shows you how to integrate SwiftlyAIKit into SwiftUI applications. You'll learn:
- MVVM architecture with AI
- Streaming chat interfaces
- Error handling in SwiftUI
- State management
- Complete working examples

## Quick Start

### Basic AI View

```swift
import SwiftUI
import SwiftlyAIKit

struct AIView: View {
    @State private var prompt = ""
    @State private var response = ""
    @State private var isLoading = false

    let gateway: AIGateway

    var body: some View {
        VStack {
            TextEditor(text: $response)
                .frame(height: 200)

            TextField("Ask anything...", text: $prompt)
                .textFieldStyle(.roundedBorder)

            Button("Send") {
                Task {
                    await sendMessage()
                }
            }
            .disabled(isLoading || prompt.isEmpty)
        }
        .padding()
    }

    func sendMessage() async {
        isLoading = true
        let userPrompt = prompt
        prompt = ""

        let request = AIRequest(model: .claude(.sonnet4_5), prompt: userPrompt)

        do {
            let aiResponse = try await gateway.sendMessage(request)
            response = aiResponse.message.content
        } catch {
            response = "Error: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
```

## MVVM Architecture

### ViewModel

```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var error: String?

    private let gateway: AIGateway

    init(gateway: AIGateway) {
        self.gateway = gateway
    }

    func sendMessage() async {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)

        let userInput = inputText
        inputText = ""
        isLoading = true
        error = nil

        do {
            let request = AIRequest(
                model: .claude(.sonnet4_5),
                messages: messages.map { AIMessage(role: $0.role == .user ? .user : .assistant, content: $0.content) }
            )

            let response = try await gateway.sendMessage(request)

            let assistantMessage = ChatMessage(role: .assistant, content: response.message.content)
            messages.append(assistantMessage)

        } catch {
            self.error = error.localizedDescription

            // Remove user message on error
            messages.removeLast()
            inputText = userInput
        }

        isLoading = false
    }

    func clearChat() {
        messages.removeAll()
        inputText = ""
        error = nil
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String

    enum MessageRole {
        case user, assistant
    }
}
```

### View

```swift
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    init(gateway: AIGateway) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(gateway: gateway))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            HStack {
                TextField("Message", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .disabled(viewModel.isLoading)

                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.inputText.isEmpty ? .gray : .blue)
                    }
                }
                .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
            }
            .padding()
        }
        .navigationTitle("AI Chat")
        .toolbar {
            Button("Clear") {
                viewModel.clearChat()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading) {
                Text(message.content)
                    .padding(12)
                    .background(
                        message.role == .user
                            ? Color.blue
                            : Color(.systemGray5)
                    )
                    .foregroundColor(
                        message.role == .user
                            ? .white
                            : .primary
                    )
                    .cornerRadius(16)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}
```

## Streaming Chat

### Streaming ViewModel

```swift
@MainActor
class StreamingChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var streamingText = ""
    @Published var inputText = ""
    @Published var isStreaming = false

    private let gateway: AIGateway
    private var streamTask: Task<Void, Never>?

    init(gateway: AIGateway) {
        self.gateway = gateway
    }

    func sendMessage() async {
        guard !inputText.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)

        inputText = ""
        isStreaming = true
        streamingText = ""

        do {
            let request = AIRequest(
                model: .claude(.sonnet4_5),
                messages: messages.map { AIMessage(role: $0.role == .user ? .user : .assistant, content: $0.content) }
            )

            let stream = try await gateway.streamMessage(request)

            for try await chunk in stream {
                streamingText += chunk.message.content
            }

            // Add complete response
            let assistantMessage = ChatMessage(role: .assistant, content: streamingText)
            messages.append(assistantMessage)
            streamingText = ""

        } catch {
            print("Error: \(error)")
        }

        isStreaming = false
    }

    func cancelStreaming() {
        streamTask?.cancel()
        isStreaming = false
        streamingText = ""
    }
}
```

### Streaming View

```swift
struct StreamingChatView: View {
    @StateObject private var viewModel: StreamingChatViewModel

    init(gateway: AIGateway) {
        _viewModel = StateObject(wrappedValue: StreamingChatViewModel(gateway: gateway))
    }

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }

                        // Show streaming message
                        if viewModel.isStreaming {
                            StreamingMessageRow(text: viewModel.streamingText)
                                .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.streamingText) { _ in
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }

            HStack {
                TextField("Message", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)

                if viewModel.isStreaming {
                    Button("Stop") {
                        viewModel.cancelStreaming()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Send") {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                    .disabled(viewModel.inputText.isEmpty)
                }
            }
            .padding()
        }
    }
}

struct StreamingMessageRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top) {
            Text(text)
                .padding(12)
                .background(Color(.systemGray5))
                .cornerRadius(16)

            // Typing indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()
        }
    }
}
```

## Provider Selection

### Provider Picker

```swift
struct ProviderPickerView: View {
    @State private var selectedProvider: ProviderType = .anthropic
    @State private var response = ""

    let gateway: AIGateway

    var body: some View {
        VStack {
            Picker("Provider", selection: $selectedProvider) {
                Text("Claude").tag(ProviderType.anthropic)
                Text("GPT-4").tag(ProviderType.openai)
                Text("Gemini").tag(ProviderType.google)
            }
            .pickerStyle(.segmented)

            Button("Ask AI") {
                Task {
                    await askAI()
                }
            }

            Text(response)
        }
        .padding()
    }

    func askAI() async {
        let request = AIRequest(
            model: .custom("model"),
            prompt: "Explain recursion"
        )

        do {
            let aiResponse = try await gateway.sendMessage(request, to: selectedProvider)
            response = aiResponse.message.content
        } catch {
            response = "Error: \(error)"
        }
    }
}
```

## Error Handling

### User-Friendly Errors

```swift
@MainActor
class ErrorHandlingViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError = false

    let gateway: AIGateway

    init(gateway: AIGateway) {
        self.gateway = gateway
    }

    func sendMessage(_ request: AIRequest) async {
        do {
            let response = try await gateway.sendMessage(request)
            // Handle success
        } catch let error as AIError {
            errorMessage = toUserFriendlyMessage(error)
            showError = true
        } catch {
            errorMessage = "An unexpected error occurred"
            showError = true
        }
    }

    private func toUserFriendlyMessage(_ error: AIError) -> String {
        switch error {
        case .authenticationFailed:
            return "Invalid API key. Please check your settings."
        case .rateLimitExceeded(let retryAfter):
            return "Too many requests. Please wait \(retryAfter) seconds."
        case .networkError:
            return "Network connection issue. Please check your internet."
        case .validationError(let message):
            return "Invalid request: \(message)"
        case .providerError:
            return "The AI service is temporarily unavailable."
        default:
            return "An error occurred. Please try again."
        }
    }
}
```

## Complete Chat App Example

### App Entry Point

```swift
@main
struct MyChatApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

@MainActor
class AppState: ObservableObject {
    let gateway: AIGateway

    init() {
        let config: Configuration

        if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            config = Configuration.withCompanyKey(apiKey)
        } else {
            // Fallback for development
            config = Configuration.withCompanyKey("test-key")
        }

        self.gateway = AIGateway(configuration: config)
    }
}
```

### Main Content View

```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: StreamingChatViewModel

    init() {
        // ViewModel created in init to access EnvironmentObject
    }

    var body: some View {
        NavigationView {
            StreamingChatView(gateway: appState.gateway)
        }
    }
}
```

## Advanced Patterns

### Image Generation

```swift
struct ImageGenerationView: View {
    @State private var prompt = ""
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false

    let gateway: AIGateway

    var body: some View {
        VStack {
            TextField("Describe an image", text: $prompt)
                .textFieldStyle(.roundedBorder)

            Button("Generate") {
                Task {
                    await generateImage()
                }
            }
            .disabled(isGenerating || prompt.isEmpty)

            if isGenerating {
                ProgressView("Generating...")
            }

            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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

### Vision Analysis

```swift
struct VisionView: View {
    @State private var selectedImage: UIImage?
    @State private var analysis = ""
    @State private var isAnalyzing = false
    @State private var showingImagePicker = false

    let gateway: AIGateway

    var body: some View {
        VStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)

                Button("Analyze") {
                    Task {
                        await analyzeImage()
                    }
                }
                .disabled(isAnalyzing)
            } else {
                Button("Select Image") {
                    showingImagePicker = true
                }
            }

            if isAnalyzing {
                ProgressView("Analyzing...")
            }

            Text(analysis)
                .padding()
        }
        .sheet(isPresented: $showingImagePicker) {
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
            model: .gpt4(.o),
            messages: [
                .user([
                    .text("Describe this image in detail"),
                    .image(data: base64, mediaType: "image/jpeg")
                ])
            ]
        )

        do {
            let response = try await gateway.sendMessage(request, to: .openai)
            analysis = response.message.content
        } catch {
            analysis = "Error: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }
}
```

## State Management

### Conversation History

```swift
@MainActor
class ConversationManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var activeConversation: Conversation?

    func createConversation() {
        let conversation = Conversation()
        conversations.append(conversation)
        activeConversation = conversation
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if activeConversation?.id == id {
            activeConversation = conversations.first
        }
    }
}

class Conversation: ObservableObject, Identifiable {
    let id = UUID()
    @Published var messages: [ChatMessage] = []
    @Published var title: String = "New Chat"

    func updateTitle(from firstMessage: String) {
        if title == "New Chat" {
            title = String(firstMessage.prefix(30))
        }
    }
}
```

## See Also

- <doc:StreamingResponses>
- <doc:ErrorHandling>
- <doc:UIKitIntegration>
- ``AIGateway``
