//
//  WorkspaceGraphChatViewController.swift
//  sphinx
//
//  Created on 3/13/26.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit
import SwiftyJSON

class WorkspaceGraphChatViewController: UIViewController {

    // MARK: - Properties

    private var workspace: Workspace
    private var messages: [HiveChatMessage] = []
    private var isStreaming: Bool = false {
        didSet { updateInputState() }
    }
    private var processingStepText: String? = nil
    private var sseManager: GraphChatSSEManager?
    private var streamingMessageIndex: Int? = nil

    private let newBubbleHelper = NewMessageBubbleHelper()

    // MARK: - UI

    private var chatTableView: UITableView!
    private var chatInputContainer: UIView!
    private var chatInputTextView: UITextView!
    private var sendButton: UIButton!
    private var chatInputBottomConstraint: NSLayoutConstraint!

    // MARK: - Init

    static func instantiate(workspace: Workspace) -> WorkspaceGraphChatViewController {
        return WorkspaceGraphChatViewController(workspace: workspace)
    }

    private init(workspace: Workspace) {
        self.workspace = workspace
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.Sphinx.Body
        setupUI()
        setupKeyboardObservers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            sseManager?.stopStream()
        }
    }

    deinit {
        sseManager?.stopStream()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Table view
        chatTableView = UITableView()
        chatTableView.translatesAutoresizingMaskIntoConstraints = false
        chatTableView.backgroundColor = .clear
        chatTableView.separatorStyle = .none
        chatTableView.delegate = self
        chatTableView.dataSource = self
        chatTableView.register(FeatureChatMessageCell.self, forCellReuseIdentifier: "FeatureChatMessageCell")
        chatTableView.register(HiveProcessingBubbleCell.self, forCellReuseIdentifier: "HiveProcessingBubbleCell")
        chatTableView.rowHeight = UITableView.automaticDimension
        chatTableView.estimatedRowHeight = 80
        chatTableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        chatTableView.keyboardDismissMode = .interactive
        view.addSubview(chatTableView)

        // Bottom fill view — covers gap between input container and screen bottom
        let bottomFillView = UIView()
        bottomFillView.translatesAutoresizingMaskIntoConstraints = false
        bottomFillView.backgroundColor = UIColor.Sphinx.HeaderBG
        view.addSubview(bottomFillView)

        // Input container
        chatInputContainer = UIView()
        chatInputContainer.translatesAutoresizingMaskIntoConstraints = false
        chatInputContainer.backgroundColor = UIColor.Sphinx.HeaderBG
        view.addSubview(chatInputContainer)

        // Text view
        chatInputTextView = UITextView()
        chatInputTextView.translatesAutoresizingMaskIntoConstraints = false
        chatInputTextView.backgroundColor = UIColor.Sphinx.Body
        chatInputTextView.textColor = UIColor.Sphinx.Text
        chatInputTextView.font = UIFont(name: "Roboto-Regular", size: 16)
        chatInputTextView.layer.cornerRadius = 20
        chatInputTextView.layer.borderWidth = 1
        chatInputTextView.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        chatInputTextView.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        chatInputTextView.delegate = self
        chatInputContainer.addSubview(chatInputTextView)

        // Send button
        sendButton = UIButton()
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("➤", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        sendButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        sendButton.layer.cornerRadius = 20
        sendButton.addTarget(self, action: #selector(sendButtonTouched), for: .touchUpInside)
        chatInputContainer.addSubview(sendButton)

        // Constraints
        chatInputBottomConstraint = chatInputContainer.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor
        )

        NSLayoutConstraint.activate([
            // Table view
            chatTableView.topAnchor.constraint(equalTo: view.topAnchor),
            chatTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatTableView.bottomAnchor.constraint(equalTo: chatInputContainer.topAnchor),

            // Input container
            chatInputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatInputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatInputBottomConstraint,
            chatInputContainer.heightAnchor.constraint(equalToConstant: 80),

            // Bottom fill
            bottomFillView.topAnchor.constraint(equalTo: chatInputContainer.bottomAnchor),
            bottomFillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFillView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Text view
            chatInputTextView.topAnchor.constraint(equalTo: chatInputContainer.topAnchor, constant: 12),
            chatInputTextView.leadingAnchor.constraint(equalTo: chatInputContainer.leadingAnchor, constant: 16),
            chatInputTextView.bottomAnchor.constraint(equalTo: chatInputContainer.bottomAnchor, constant: -12),
            chatInputTextView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),

            // Send button
            sendButton.centerYAnchor.constraint(equalTo: chatInputContainer.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: chatInputContainer.trailingAnchor, constant: -16),
            sendButton.widthAnchor.constraint(equalToConstant: 80),
            sendButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    // MARK: - Keyboard

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let keyboardHeight = keyboardFrame.height
        chatInputBottomConstraint.constant = -(keyboardHeight - view.safeAreaInsets.bottom)

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        scrollToBottom()
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        chatInputBottomConstraint.constant = 0
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Input State

    private func updateInputState() {
        sendButton.isEnabled = !isStreaming
        sendButton.alpha = isStreaming ? 0.5 : 1.0
        chatInputTextView.isEditable = !isStreaming
    }

    // MARK: - Send

    @objc private func sendButtonTouched() {
        guard !isStreaming,
              let text = chatInputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        chatInputTextView.resignFirstResponder()
        chatInputTextView.text = ""
        chatInputTextView.typingAttributes = [
            .foregroundColor: UIColor.Sphinx.Text,
            .font: UIFont(name: "Roboto-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        ]

        // Append user message
        let userMessage = HiveChatMessage(id: UUID().uuidString, message: text, role: "USER")
        messages.append(userMessage)
        let userIndexPath = IndexPath(row: messages.count - 1, section: 0)
        chatTableView.insertRows(at: [userIndexPath], with: .automatic)
        scrollToBottom()

        isStreaming = true

        // Build payload with ALL messages (stateless API)
        let messagesPayload: [[String: String]] = messages.map {
            ["role": $0.role.lowercased(), "content": $0.message]
        }
        let slug = workspace.slug ?? ""

        // Resolve token then stream
        API.sharedInstance.resolveHiveToken(
            callback: { [weak self] token in
                guard let self = self else { return }
                self.sseManager = GraphChatSSEManager()
                self.sseManager?.delegate = self
                self.sseManager?.startStream(
                    messages: messagesPayload,
                    workspaceSlug: slug,
                    token: token
                )
            },
            errorCallback: { [weak self] in
                guard let self = self else { return }
                self.isStreaming = false
                self.newBubbleHelper.showGenericMessageView(text: "Authentication failed. Please try again.")
            }
        )
    }

    // MARK: - Processing Bubble

    private func updateProcessingBubble(stepText: String) {
        if processingStepText == nil {
            processingStepText = stepText
            let indexPath = IndexPath(row: messages.count, section: 0)
            chatTableView.insertRows(at: [indexPath], with: .automatic)
            scrollToBottom()
        } else {
            processingStepText = stepText
            let indexPath = IndexPath(row: messages.count, section: 0)
            chatTableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private func hideProcessingBubble() {
        guard processingStepText != nil else { return }
        let indexPath = IndexPath(row: messages.count, section: 0)
        processingStepText = nil
        chatTableView.deleteRows(at: [indexPath], with: .automatic)
    }

    // MARK: - Scroll

    private func scrollToBottom() {
        let totalRows = messages.count + (processingStepText != nil ? 1 : 0)
        guard totalRows > 0 else { return }
        let lastIndexPath = IndexPath(row: totalRows - 1, section: 0)
        chatTableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: true)
    }
}

// MARK: - GraphChatSSEDelegate

extension WorkspaceGraphChatViewController: GraphChatSSEDelegate {

    func onTextDelta(_ delta: String) {
        if let idx = streamingMessageIndex {
            // Update in-place
            messages[idx].message += delta
            chatTableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
        } else {
            // First delta — create assistant bubble
            let assistantMsg = HiveChatMessage(id: UUID().uuidString, message: delta, role: "ASSISTANT")
            messages.append(assistantMsg)
            streamingMessageIndex = messages.count - 1
            chatTableView.insertRows(at: [IndexPath(row: streamingMessageIndex!, section: 0)], with: .automatic)
        }
        scrollToBottom()
    }

    func onToolInputAvailable(toolName: String) {
        let stepText = toolName == "learn_concept" ? "📚 Learning..." : "🔍 Searching..."
        updateProcessingBubble(stepText: stepText)
    }

    func onToolOutputAvailable() {
        hideProcessingBubble()
    }

    func onFinish() {
        hideProcessingBubble()
        streamingMessageIndex = nil
        isStreaming = false
        sseManager?.stopStream()
    }

    func onError(_ text: String) {
        // Remove partial streaming bubble if present
        if let idx = streamingMessageIndex {
            messages.remove(at: idx)
            chatTableView.deleteRows(at: [IndexPath(row: idx, section: 0)], with: .automatic)
            streamingMessageIndex = nil
        }
        hideProcessingBubble()
        isStreaming = false
        newBubbleHelper.showGenericMessageView(text: text.isEmpty ? "An error occurred. Please try again." : text)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension WorkspaceGraphChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count + (processingStepText != nil ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Processing bubble row
        if processingStepText != nil && indexPath.row == messages.count {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "HiveProcessingBubbleCell",
                for: indexPath
            ) as! HiveProcessingBubbleCell
            cell.configure(stepText: processingStepText ?? "Processing...")
            return cell
        }

        // Message row
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "FeatureChatMessageCell",
            for: indexPath
        ) as? FeatureChatMessageCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        let isLast = indexPath.row == messages.count - 1
        cell.configure(with: message, isLastMessage: isLast)
        cell.onHeightChanged = { [weak tableView] in
            tableView?.beginUpdates()
            tableView?.endUpdates()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - UITextViewDelegate

extension WorkspaceGraphChatViewController: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Allow return key to send on send button tap (not via keyboard return)
        return true
    }
}
