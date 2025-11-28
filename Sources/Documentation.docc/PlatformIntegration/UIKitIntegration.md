# UIKit Integration

Build AI-powered UIKit apps with SwiftlyAIKit.

## Overview

This guide shows you how to integrate SwiftlyAIKit into UIKit applications:
- MVVM architecture with UIKit
- Streaming chat interfaces
- Image generation and vision
- Proper threading and updates

## Basic Integration

### Simple AI View Controller

```swift
import UIKit
import SwiftlyAIKit

class AIViewController: UIViewController {
    let gateway: AIGateway

    private let textView = UITextView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    init(gateway: AIGateway) {
        self.gateway = gateway
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Text view (response)
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 16)
        view.addSubview(textView)

        // Input field
        inputField.placeholder = "Ask anything..."
        inputField.borderStyle = .roundedRect
        inputField.delegate = self
        view.addSubview(inputField)

        // Send button
        sendButton.setTitle("Send", for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        view.addSubview(sendButton)

        // Activity indicator
        view.addSubview(activityIndicator)

        // Layout
        textView.translatesAutoresizingMaskIntoConstraints = false
        inputField.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            inputField.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 16),
            inputField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputField.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sendButton.widthAnchor.constraint(equalToConstant: 60),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func sendTapped() {
        guard let text = inputField.text, !text.isEmpty else { return }

        inputField.text = ""
        sendButton.isEnabled = false
        activityIndicator.startAnimating()

        Task {
            await sendMessage(text)
        }
    }

    private func sendMessage(_ prompt: String) async {
        let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)

        do {
            let response = try await gateway.sendMessage(request)

            await MainActor.run {
                textView.text = response.message.content
                sendButton.isEnabled = true
                activityIndicator.stopAnimating()
            }
        } catch {
            await MainActor.run {
                textView.text = "Error: \(error.localizedDescription)"
                sendButton.isEnabled = true
                activityIndicator.stopAnimating()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AIViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}
```

## Streaming Chat

### Streaming View Controller

```swift
class StreamingChatViewController: UIViewController {
    let gateway: AIGateway

    private let tableView = UITableView()
    private let inputField = UITextField()
    private let sendButton = UIButton()

    private var messages: [ChatMessage] = []
    private var streamingText = ""
    private var streamTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")

        setupUI()
    }

    @objc func sendMessage() {
        guard let text = inputField.text, !text.isEmpty else { return }

        // Add user message
        messages.append(ChatMessage(role: .user, content: text))
        tableView.reloadData()

        inputField.text = ""
        streamingText = ""

        streamTask = Task {
            await streamResponse(text)
        }
    }

    func streamResponse(_ userText: String) async {
        let allMessages = messages.map { msg in
            AIMessage(role: msg.role == .user ? .user : .assistant, content: msg.content)
        }

        let request = AIRequest(
            model: .claude(.sonnet4_5),
            messages: allMessages
        )

        do {
            let stream = try await gateway.streamMessage(request)

            // Add streaming message
            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: ""))
                tableView.reloadData()
            }

            for try await chunk in stream {
                streamingText += chunk.message.content

                await MainActor.run {
                    if let lastIndex = messages.indices.last {
                        messages[lastIndex].content = streamingText
                        tableView.reloadRows(at: [IndexPath(row: lastIndex, section: 0)], with: .none)
                    }
                }
            }

        } catch {
            await MainActor.run {
                showError(error)
            }
        }
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

struct ChatMessage {
    enum Role {
        case user, assistant
    }

    let role: Role
    var content: String
}

extension StreamingChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

class MessageCell: UITableViewCell {
    private let messageLabel = UILabel()
    private let bubbleView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear

        bubbleView.layer.cornerRadius = 16
        contentView.addSubview(bubbleView)

        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 16)
        bubbleView.addSubview(messageLabel)

        // Layout constraints...
    }

    func configure(with message: ChatMessage) {
        messageLabel.text = message.content

        if message.role == .user {
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
        } else {
            bubbleView.backgroundColor = .systemGray5
            messageLabel.textColor = .label
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

## Image Generation

```swift
class ImageGenerationViewController: UIViewController {
    let gateway: AIGateway

    private let promptField = UITextField()
    private let generateButton = UIButton()
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView()

    @objc func generateTapped() {
        guard let prompt = promptField.text, !prompt.isEmpty else { return }

        generateButton.isEnabled = false
        activityIndicator.startAnimating()

        Task {
            await generateImage(prompt: prompt)
        }
    }

    func generateImage(prompt: String) async {
        let request = ImageGenerationRequest.dallE3(
            prompt: prompt,
            size: .square1024,
            quality: .hd
        )

        do {
            let response = try await gateway.generateImage(request, using: .openai)

            if let imageURL = response.images.first?.url,
               let url = URL(string: imageURL),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {

                await MainActor.run {
                    imageView.image = image
                    generateButton.isEnabled = true
                    activityIndicator.stopAnimating()
                }
            }
        } catch {
            await MainActor.run {
                showError(error)
                generateButton.isEnabled = true
                activityIndicator.stopAnimating()
            }
        }
    }
}
```

## Threading Best Practices

### Always Update UI on Main Thread

```swift
// ✅ Good
Task {
    let response = try await gateway.sendMessage(request)

    await MainActor.run {
        textView.text = response.message.content
    }
}

// ❌ Bad
Task {
    let response = try await gateway.sendMessage(request)
    textView.text = response.message.content // May not be on main thread!
}
```

### Cancel Tasks on Dismiss

```swift
class AIViewController: UIViewController {
    var currentTask: Task<Void, Never>?

    func startRequest() {
        currentTask = Task {
            await performAIRequest()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Cancel ongoing tasks
        currentTask?.cancel()
        currentTask = nil
    }
}
```

## See Also

- <doc:SwiftUIIntegration>
- <doc:StreamingResponses>
- <doc:ErrorHandling>
- ``AIGateway``
