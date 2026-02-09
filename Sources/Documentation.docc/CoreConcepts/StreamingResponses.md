# Streaming Responses

Display AI responses in real-time as they're generated.

## Overview

Streaming provides a better user experience by showing responses as they're generated, rather than waiting for the complete response. This creates the familiar ChatGPT-style interface where text appears word-by-word.

SwiftlyAIKit supports streaming through ``AIGateway/streamMessage(_:to:clientAPIKey:)``, which returns an `AsyncThrowingStream<AIResponse, Error>` that yields response chunks in real-time.

## Why Stream?

### User Experience

**Without Streaming:**
```
User: "Write a story about space"
[... 30 seconds of waiting ...]
AI: [Complete 500-word story appears at once]
```

**With Streaming:**
```
User: "Write a story about space"
AI: "Once upon a time..." [text appears word by word]
```

### Benefits

- **Perceived Performance** - Feels faster even if total time is similar
- **Early Cancellation** - Users can stop if response goes wrong
- **Progress Feedback** - Users know request is working
- **Better UX** - Standard for modern AI apps

## Basic Streaming

### Simple Console Output

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-ant-...")
let gateway = AIGateway(configuration: config)

let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Write a haiku")

// Stream the response
let stream = try await gateway.streamMessage(request)

for try await chunk in stream {
    print(chunk.message.content, terminator: "")
}
print() // New line at end
```

**Output:**
```
Moonlight filters through
Ancient pines whisper secrets
Night's quiet wisdom
```

### Accumulating Full Response

```swift
var fullResponse = ""

let stream = try await gateway.streamMessage(request)

for try await chunk in stream {
    fullResponse += chunk.message.content
    print(chunk.message.content, terminator: "")
}

print("\n\nFull response: \(fullResponse)")
```

## SwiftUI Integration

### Basic Streaming View

```swift
import SwiftUI
import SwiftlyAIKit

struct StreamingChatView: View {
    @State private var prompt = ""
    @State private var streamedResponse = ""
    @State private var isStreaming = false

    let gateway: AIGateway

    var body: some View {
        VStack {
            // Display streamed response
            ScrollView {
                Text(streamedResponse)
                    .padding()
            }

            // Input field
            HStack {
                TextField("Ask anything...", text: $prompt)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    Task {
                        await sendMessage()
                    }
                }
                .disabled(isStreaming || prompt.isEmpty)
            }
            .padding()
        }
    }

    func sendMessage() async {
        isStreaming = true
        streamedResponse = ""

        let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)

        do {
            let stream = try await gateway.streamMessage(request)

            for try await chunk in stream {
                streamedResponse += chunk.message.content
            }
        } catch {
            streamedResponse = "Error: \(error.localizedDescription)"
        }

        isStreaming = false
        prompt = ""
    }
}
```

### Advanced Streaming with ViewModel

```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var streamingText = ""
    @Published var isStreaming = false
    @Published var error: String?

    private let gateway: AIGateway
    private var streamTask: Task<Void, Never>?

    init(gateway: AIGateway) {
        self.gateway = gateway
    }

    func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        // Start streaming
        isStreaming = true
        streamingText = ""
        error = nil

        do {
            let request = AIRequest(
                model: .claude(.sonnet4_5),
                messages: messages.map { .user($0.content) }
            )

            let stream = try await gateway.streamMessage(request)

            for try await chunk in stream {
                streamingText += chunk.message.content
            }

            // Add complete response to messages
            let assistantMessage = ChatMessage(role: .assistant, content: streamingText)
            messages.append(assistantMessage)
            streamingText = ""

        } catch {
            self.error = error.localizedDescription
        }

        isStreaming = false
    }

    func cancelStreaming() {
        streamTask?.cancel()
        isStreaming = false
        streamingText = ""
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

### Complete Chat Interface

```swift
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText = ""

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

                        // Streaming message
                        if viewModel.isStreaming {
                            StreamingMessageRow(text: viewModel.streamingText)
                                .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.streamingText) { _ in
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }

            // Input
            HStack {
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty || viewModel.isStreaming)
            }
            .padding()
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

    private func send() {
        let text = inputText
        inputText = ""

        Task {
            await viewModel.sendMessage(text)
        }
    }
}

struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            Text(message.content)
                .padding()
                .background(
                    message.role == .user ? Color.blue : Color.gray.opacity(0.2)
                )
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(12)

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

struct StreamingMessageRow: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)

            // Typing indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                        .scaleEffect(/* animated */ 1.0)
                }
            }
            .padding(.leading, 8)

            Spacer()
        }
    }
}
```

## UIKit Integration

```swift
import UIKit
import SwiftlyAIKit

class ChatViewController: UIViewController {
    let gateway: AIGateway
    var streamTask: Task<Void, Never>?

    private let textView = UITextView()
    private let inputField = UITextField()
    private let sendButton = UIButton()

    init(gateway: AIGateway) {
        self.gateway = gateway
        super.init(nibName: nil, bundle: nil)
    }

    @objc func sendMessage() {
        guard let text = inputField.text, !text.isEmpty else { return }
        inputField.text = ""

        streamTask = Task {
            await streamResponse(for: text)
        }
    }

    func streamResponse(for prompt: String) async {
        let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)

        do {
            let stream = try await gateway.streamMessage(request)

            for try await chunk in stream {
                await MainActor.run {
                    textView.text += chunk.message.content
                }
            }
        } catch {
            await MainActor.run {
                textView.text += "\nError: \(error.localizedDescription)"
            }
        }
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

## Advanced Streaming Techniques

### Debouncing UI Updates

For better performance, batch UI updates:

```swift
actor StreamBuffer {
    private var buffer = ""
    private var lastUpdate = Date()
    private let updateInterval: TimeInterval = 0.1 // 100ms

    func append(_ text: String) -> String? {
        buffer += text

        let now = Date()
        if now.timeIntervalSince(lastUpdate) >= updateInterval {
            lastUpdate = now
            let result = buffer
            buffer = ""
            return result
        }

        return nil
    }

    func flush() -> String {
        let result = buffer
        buffer = ""
        return result
    }
}

class OptimizedChatViewModel: ObservableObject {
    @Published var streamingText = ""

    private let buffer = StreamBuffer()
    private let gateway: AIGateway

    init(gateway: AIGateway) {
        self.gateway = gateway
    }

    func sendMessage(_ prompt: String) async {
        let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)

        do {
            let stream = try await gateway.streamMessage(request)

            for try await chunk in stream {
                if let buffered = await buffer.append(chunk.message.content) {
                    await MainActor.run {
                        streamingText += buffered
                    }
                }
            }

            // Flush remaining
            let remaining = await buffer.flush()
            if !remaining.isEmpty {
                await MainActor.run {
                    streamingText += remaining
                }
            }

        } catch {
            print("Streaming error: \(error)")
        }
    }
}
```

### Handling Tool Calls in Streams

```swift
func streamWithTools(_ request: AIRequest) async throws {
    let stream = try await gateway.streamMessage(request)
    var accumulatedContent = ""
    var toolCalls: [AIToolCall] = []

    for try await chunk in stream {
        // Accumulate content
        accumulatedContent += chunk.message.content

        // Check for tool calls
        if let calls = chunk.toolCalls {
            toolCalls.append(contentsOf: calls)
        }

        // Update UI
        print(chunk.message.content, terminator: "")
    }

    // Handle tool calls after stream completes
    if !toolCalls.isEmpty {
        print("\n\nAI wants to call tools: \(toolCalls.map { $0.name })")
        // Execute tools and continue conversation
    }
}
```

### Cancellation

```swift
class CancellableStreamingService {
    var currentTask: Task<Void, Never>?

    func startStreaming(_ request: AIRequest, gateway: AIGateway) {
        currentTask = Task {
            do {
                let stream = try await gateway.streamMessage(request)

                for try await chunk in stream {
                    // Check for cancellation
                    if Task.isCancelled {
                        print("Stream cancelled by user")
                        return
                    }

                    print(chunk.message.content, terminator: "")
                }
            } catch is CancellationError {
                print("\nStream was cancelled")
            } catch {
                print("\nError: \(error)")
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}
```

## Error Handling in Streams

```swift
func streamWithErrorHandling(_ request: AIRequest) async {
    do {
        let stream = try await gateway.streamMessage(request)

        for try await chunk in stream {
            print(chunk.message.content, terminator: "")
        }

    } catch AIError.authenticationFailed(let provider) {
        print("\nAuthentication failed for \(provider)")
    } catch AIError.rateLimitExceeded(let retryAfter) {
        print("\nRate limited. Retry after \(retryAfter)s")
    } catch AIError.networkError(let message) {
        print("\nNetwork error: \(message)")
    } catch {
        print("\nUnexpected error: \(error)")
    }
}
```

## Performance Optimization

### Batch UI Updates

Instead of updating on every chunk:

```swift
@MainActor
class PerformantChatViewModel: ObservableObject {
    @Published var displayText = ""

    private var accumulator = ""
    private var updateTimer: Timer?

    func startStreaming(_ stream: AsyncThrowingStream<AIResponse, Error>) async {
        // Update UI every 100ms instead of every chunk
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.flushAccumulator()
        }

        do {
            for try await chunk in stream {
                accumulator += chunk.message.content
            }
        } catch {
            print("Error: \(error)")
        }

        // Final flush
        flushAccumulator()
        updateTimer?.invalidate()
    }

    private func flushAccumulator() {
        if !accumulator.isEmpty {
            displayText += accumulator
            accumulator = ""
        }
    }
}
```

### Memory Management

For very long responses:

```swift
class MemoryEfficientStreamHandler {
    private let maxBufferSize = 10_000 // characters

    func stream(_ request: AIRequest, gateway: AIGateway) async throws {
        var buffer = ""

        let stream = try await gateway.streamMessage(request)

        for try await chunk in stream {
            buffer += chunk.message.content

            // Flush to disk if buffer gets too large
            if buffer.count > maxBufferSize {
                try saveToFile(buffer)
                buffer = ""
            }
        }

        // Save remaining
        if !buffer.isEmpty {
            try saveToFile(buffer)
        }
    }

    private func saveToFile(_ content: String) throws {
        // Save to temporary file or database
    }
}
```

## Provider-Specific Streaming Behavior

Different providers handle streaming slightly differently:

### Anthropic Claude

```swift
// Claude sends complete words
let stream = try await gateway.streamMessage(request, to: .anthropic)
// Chunks: "Hello", " there", "!", " How", " can", " I", " help", "?"
```

### OpenAI GPT

```swift
// GPT sends smaller tokens
let stream = try await gateway.streamMessage(request, to: .openai)
// Chunks: "H", "ello", " there", "!", " How", " can"...
```

### Google Gemini

```swift
// Gemini sends variable-length chunks
let stream = try await gateway.streamMessage(request, to: .google)
// Chunks can be words, phrases, or sentences
```

**All providers:** SwiftlyAIKit normalizes the differences - just iterate the stream!

## Testing Streaming

```swift
@Test("Stream response chunks")
func testStreaming() async throws {
    let config = Configuration.withCompanyKey("test-key")
    let gateway = AIGateway(configuration: config)

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Count to 5")

    var chunks: [String] = []
    let stream = try await gateway.streamMessage(request)

    for try await chunk in stream {
        chunks.append(chunk.message.content)
    }

    // Verify chunks received
    #expect(chunks.count > 0)

    // Verify can reconstruct full response
    let fullText = chunks.joined()
    #expect(fullText.contains("1"))
}

@Test("Handle streaming errors")
func testStreamingError() async throws {
    let config = Configuration.withCompanyKey("invalid-key")
    let gateway = AIGateway(configuration: config)

    let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello")
    let stream = try await gateway.streamMessage(request)

    do {
        for try await _ in stream {
            Issue.record("Should have thrown error")
        }
    } catch AIError.authenticationFailed {
        // Expected
    } catch {
        Issue.record("Wrong error type")
    }
}
```

## Common Patterns

### Chat Conversation with History

```swift
class ConversationManager {
    private var history: [AIMessage] = []

    func streamMessage(_ userText: String, gateway: AIGateway) async throws -> String {
        // Add user message to history
        history.append(.user(userText))

        // Create request with full history
        let request = AIRequest(
            model: .claude(.sonnet4_5),
            messages: history
        )

        var fullResponse = ""
        let stream = try await gateway.streamMessage(request)

        for try await chunk in stream {
            fullResponse += chunk.message.content
            print(chunk.message.content, terminator: "")
        }

        // Add assistant response to history
        history.append(.assistant(fullResponse))

        return fullResponse
    }
}
```

### Streaming with Markdown Rendering

```swift
import MarkdownUI

struct MarkdownStreamView: View {
    @State private var streamedMarkdown = ""
    let gateway: AIGateway

    var body: some View {
        ScrollView {
            Markdown(streamedMarkdown)
                .padding()
        }
        .task {
            await streamMarkdown()
        }
    }

    func streamMarkdown() async {
        let request = AIRequest(
            model: .claude(.sonnet4_5),
            prompt: "Write a markdown document with headings and lists"
        )

        do {
            let stream = try await gateway.streamMessage(request)

            for try await chunk in stream {
                streamedMarkdown += chunk.message.content
            }
        } catch {
            streamedMarkdown = "Error: \(error.localizedDescription)"
        }
    }
}
```

### Streaming with Stop Button

```swift
struct StreamingWithCancelView: View {
    @State private var response = ""
    @State private var isStreaming = false
    @State private var streamTask: Task<Void, Never>?

    let gateway: AIGateway

    var body: some View {
        VStack {
            ScrollView {
                Text(response)
            }

            if isStreaming {
                Button("Stop") {
                    streamTask?.cancel()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Generate") {
                    startStreaming()
                }
            }
        }
    }

    func startStreaming() {
        isStreaming = true
        response = ""

        streamTask = Task {
            let request = AIRequest(
                model: .claude(.sonnet4_5),
                prompt: "Write a long story"
            )

            do {
                let stream = try await gateway.streamMessage(request)

                for try await chunk in stream {
                    if Task.isCancelled {
                        response += "\n\n[Stopped by user]"
                        break
                    }

                    response += chunk.message.content
                }
            } catch is CancellationError {
                response += "\n\n[Cancelled]"
            } catch {
                response += "\n\nError: \(error.localizedDescription)"
            }

            isStreaming = false
        }
    }
}
```

## Best Practices

### ✅ Do

- Use streaming for responses longer than a few sentences
- Update UI on the main actor
- Handle cancellation gracefully
- Batch UI updates for performance (100ms intervals)
- Show a loading indicator while streaming
- Provide a way to cancel streaming
- Accumulate full response for history

### ❌ Don't

- Update UI on every single chunk (causes performance issues)
- Block the main thread while streaming
- Ignore cancellation
- Forget error handling
- Stream for very short responses (adds latency)
- Keep all chunks in memory for very long responses

## Troubleshooting

### Stream Hangs

**Problem:** Stream never yields chunks or finishes

**Solutions:**
- Check timeout settings (increase if needed)
- Verify API key is valid
- Check network connectivity
- Enable logging to see what's happening

### Chunks Appear Slowly

**Problem:** Stream updates feel laggy

**Solutions:**
- Use debouncing/batching (update every 100ms)
- Check network latency
- Try a faster provider (Gemini Flash, GPT-4o Mini)

### Memory Usage Grows

**Problem:** App uses too much memory during long streams

**Solutions:**
- Flush accumulator to disk periodically
- Limit history size (keep last N messages)
- Use lazy loading for message list

## See Also

- ``AIGateway/streamMessage(_:to:clientAPIKey:)``
- ``AIResponse``
- <doc:SwiftUIIntegration>
- <doc:UIKitIntegration>
- <doc:PerformanceOptimization>
- <doc:ErrorHandling>
