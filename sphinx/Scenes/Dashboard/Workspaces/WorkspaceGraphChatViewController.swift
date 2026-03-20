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

    private var cqMessageIds: Set<String> {
        Set(messages.filter { $0.artifacts.contains(where: { $0.isClarifyingQuestions }) }.map { $0.id })
    }

    private var displayMessages: [HiveChatMessage] {
        messages
    }
    private var isStreaming: Bool = false {
        didSet {
            updateInputState()
            updateEmptyState()
        }
    }
    private var processingStepText: String? = nil
    private var sseManager: GraphChatSSEManager?
    /// Accumulates all text-delta chunks; committed to `messages` as one bubble on `onFinish`.
    private var streamingBuffer: String = ""

    private let newBubbleHelper = NewMessageBubbleHelper()

    // MARK: - ISO8601 timestamp helper

    private func nowISO() -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: Date())
    }

    // MARK: - Owner avatar URL (cached per VC lifetime)

    private lazy var ownerAvatarUrl: String? = {
        return UserContact.getOwner()?.avatarUrl
    }()

    // MARK: - UI

    private var chatTableView: UITableView!
    private var chatInputContainer: UIView!
    private var chatInputTextView: UITextView!
    private var sendButton: UIButton!
    private var micButton: UIButton!
    private let speechManager = SpeechTranscriptionManager()
    private var chatInputBottomConstraint: NSLayoutConstraint!
    private var chatInputContainerHeightConstraint: NSLayoutConstraint!
    private var chatInputTextViewHeightConstraint: NSLayoutConstraint!
    private var bottomFillView: UIView!
    private var emptyStateLabel: UILabel!

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
        updateEmptyState()
        speechManager.requestPermission { [weak self] granted in
            self?.micButton.isHidden = !granted
            if !granted {
                self?.newBubbleHelper.showGenericMessageView(
                    text: "Speech recognition permission denied.",
                    delay: 3, textColor: .white,
                    backColor: UIColor.Sphinx.PrimaryRed, backAlpha: 1.0)
            }
        }
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
        chatTableView.register(ClarifyingQuestionMessageCell.self, forCellReuseIdentifier: "ClarifyingQuestionMessageCell")
        chatTableView.register(HiveProcessingBubbleCell.self, forCellReuseIdentifier: "HiveProcessingBubbleCell")
        chatTableView.rowHeight = UITableView.automaticDimension
        chatTableView.estimatedRowHeight = 80
        chatTableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        chatTableView.keyboardDismissMode = .interactive
        view.addSubview(chatTableView)

        // Empty state label — centred over the table, hidden once messages arrive
        emptyStateLabel = UILabel()
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.text = "Ask me about your codebase"
        emptyStateLabel.textColor = UIColor.Sphinx.SecondaryText
        emptyStateLabel.font = UIFont(name: "Roboto-Regular", size: 16)
        emptyStateLabel.textAlignment = .center
        view.addSubview(emptyStateLabel)

        // Bottom fill view — covers gap between input container and screen bottom
        bottomFillView = UIView()
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
        chatInputTextView.isScrollEnabled = false
        chatInputTextView.delegate = self
        chatInputContainer.addSubview(chatInputTextView)

        // Send button
        sendButton = UIButton()
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("➤", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        sendButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        sendButton.layer.cornerRadius = singleLineTextViewHeight() / 2
        sendButton.addTarget(self, action: #selector(sendButtonTouched), for: .touchUpInside)
        chatInputContainer.addSubview(sendButton)

        // Mic button
        let micConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        micButton = UIButton(type: .system)
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micConfig), for: .normal)
        micButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(micLongPressed(_:)))
        lp.minimumPressDuration = 0.1
        micButton.addGestureRecognizer(lp)
        chatInputContainer.addSubview(micButton)

        // Constraints
        chatInputBottomConstraint = chatInputContainer.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor
        )

        NSLayoutConstraint.activate([
            // Empty state label — centred in the table area (above the input bar)
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: chatTableView.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),

            // Table view
            chatTableView.topAnchor.constraint(equalTo: view.topAnchor),
            chatTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatTableView.bottomAnchor.constraint(equalTo: chatInputContainer.topAnchor),

            // Input container
            chatInputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatInputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatInputBottomConstraint,
            {
                let oneLine = singleLineTextViewHeight()
                chatInputContainerHeightConstraint = chatInputContainer.heightAnchor.constraint(equalToConstant: containerHeight(for: oneLine))
                return chatInputContainerHeightConstraint
            }(),

            // Bottom fill
            bottomFillView.topAnchor.constraint(equalTo: chatInputContainer.bottomAnchor),
            bottomFillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFillView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Text view
            chatInputTextView.topAnchor.constraint(equalTo: chatInputContainer.topAnchor, constant: 12),
            chatInputTextView.leadingAnchor.constraint(equalTo: chatInputContainer.leadingAnchor, constant: 16),
            chatInputTextView.trailingAnchor.constraint(equalTo: micButton.leadingAnchor, constant: -8),
            {
                chatInputTextViewHeightConstraint = chatInputTextView.heightAnchor.constraint(equalToConstant: singleLineTextViewHeight())
                return chatInputTextViewHeightConstraint
            }(),

            // Mic button
            micButton.centerYAnchor.constraint(equalTo: chatInputContainer.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 32),
            micButton.heightAnchor.constraint(equalToConstant: 32),
            micButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            // Send button
            sendButton.centerYAnchor.constraint(equalTo: chatInputContainer.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: chatInputContainer.trailingAnchor, constant: -16),
            sendButton.heightAnchor.constraint(equalToConstant: singleLineTextViewHeight()),
            sendButton.widthAnchor.constraint(equalTo: sendButton.heightAnchor),
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

    // MARK: - Empty State

    private func updateEmptyState() {
        emptyStateLabel?.isHidden = !messages.isEmpty || isStreaming
    }

    // MARK: - Input State

    private func updateInputState() {
        sendButton.isEnabled = !isStreaming
        sendButton.alpha = isStreaming ? 0.5 : 1.0
        chatInputTextView.isEditable = !isStreaming
        micButton.isEnabled = !isStreaming
        micButton.alpha = isStreaming ? 0.5 : 1.0
    }

    // MARK: - Mic Recording

    @objc private func micLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began: startRecording()
        case .ended, .cancelled: stopRecording()
        default: break
        }
    }

    private func startRecording() {
        startRecordingBarAnimation()
        let prefix = chatInputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        speechManager.startTranscribing(
            textHandler: { [weak self] text in
                guard let self else { return }
                self.chatInputTextView.text = prefix.isEmpty ? text : prefix + " " + text
                self.updateInputBarHeight()
            },
            errorHandler: { [weak self] _ in
                self?.stopRecording()
                self?.newBubbleHelper.showGenericMessageView(
                    text: "Speech recognition unavailable.",
                    delay: 3, textColor: .white,
                    backColor: UIColor.Sphinx.PrimaryRed, backAlpha: 1.0)
            }
        )
    }

    private func stopRecording() {
        speechManager.stopTranscribing()
        micButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        stopRecordingBarAnimation()
    }

    private func startRecordingBarAnimation() {
        micButton.tintColor = .white
        let green = UIColor.Sphinx.PrimaryGreen
        chatInputContainer.backgroundColor = green
        bottomFillView.backgroundColor = green
        UIView.animate(
            withDuration: 0.7,
            delay: 0,
            options: [.repeat, .autoreverse, .allowUserInteraction],
            animations: { [weak self] in
                self?.chatInputContainer.alpha = 0.45
                self?.bottomFillView.alpha = 0.45
            }
        )
    }

    private func stopRecordingBarAnimation() {
        chatInputContainer.layer.removeAllAnimations()
        bottomFillView.layer.removeAllAnimations()
        chatInputContainer.alpha = 1.0
        bottomFillView.alpha = 1.0
        chatInputContainer.backgroundColor = UIColor.Sphinx.HeaderBG
        bottomFillView.backgroundColor = UIColor.Sphinx.HeaderBG
        micButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
    }

    // MARK: - Clarifying Answers

    private func sendClarifyingAnswers(answers: [String], replyId: String) {
        let joined = answers.joined(separator: "\n\n")
        let ownerCreatedBy: HiveChatMessageCreatedBy? = ownerAvatarUrl.flatMap { url in
            HiveChatMessageCreatedBy(json: JSON(["id": "owner", "image": url]))
        }
        let userMessage = HiveChatMessage(
            id: UUID().uuidString,
            message: joined,
            role: "USER",
            createdAt: nowISO(),
            createdBy: ownerCreatedBy,
            replyId: replyId
        )
        messages.append(userMessage)
        // Insert the answer row (shown as italic summary text)
        let answerIndexPath = IndexPath(row: displayMessages.count - 1, section: 0)
        chatTableView.insertRows(at: [answerIndexPath], with: .automatic)
        // Reload the CQ cell so it recomputes height with answered state
        if let displayIdx = displayMessages.firstIndex(where: { $0.id == replyId }) {
            chatTableView.reloadRows(at: [IndexPath(row: displayIdx, section: 0)], with: .none)
        }
        scrollToBottom()

        // Build payload and stream response
        let messagesPayload: [[String: String]] = messages.map {
            ["role": $0.role.lowercased(), "content": $0.message]
        }
        let slug = workspace.slug ?? ""
        isStreaming = true
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
        let oneLine = singleLineTextViewHeight()
        chatInputTextViewHeightConstraint.constant = oneLine
        chatInputContainerHeightConstraint.constant = containerHeight(for: oneLine)
        chatInputTextView.isScrollEnabled = false
        view.layoutIfNeeded()

        // Append user message — stamp time now; pass owner avatar so the cell shows the real photo
        let ownerCreatedBy: HiveChatMessageCreatedBy? = ownerAvatarUrl.flatMap { url in
            HiveChatMessageCreatedBy(json: JSON(["id": "owner", "image": url]))
        }
        let userMessage = HiveChatMessage(
            id: UUID().uuidString,
            message: text,
            role: "USER",
            createdAt: nowISO(),
            createdBy: ownerCreatedBy
        )
        messages.append(userMessage)
        let userIndexPath = IndexPath(row: displayMessages.count - 1, section: 0)
        chatTableView.insertRows(at: [userIndexPath], with: .automatic)
        updateEmptyState()
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
            let indexPath = IndexPath(row: displayMessages.count, section: 0)
            chatTableView.insertRows(at: [indexPath], with: .automatic)
            scrollToBottom()
        } else {
            processingStepText = stepText
            let indexPath = IndexPath(row: displayMessages.count, section: 0)
            chatTableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private func hideProcessingBubble() {
        guard processingStepText != nil else { return }
        let indexPath = IndexPath(row: displayMessages.count, section: 0)
        processingStepText = nil
        chatTableView.deleteRows(at: [indexPath], with: .automatic)
    }

    // MARK: - Input Bar Sizing Helpers

    private func singleLineTextViewHeight() -> CGFloat {
        let font = UIFont(name: "Roboto-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        let insets: CGFloat = 10 + 10
        return ceil(font.lineHeight + insets)
    }

    private func containerHeight(for textViewHeight: CGFloat) -> CGFloat {
        return textViewHeight + 12 + 12
    }

    private func updateInputBarHeight() {
        let font = chatInputTextView.font ?? UIFont.systemFont(ofSize: 16)
        let insets = chatInputTextView.textContainerInset.top + chatInputTextView.textContainerInset.bottom
        let padding = chatInputTextView.textContainer.lineFragmentPadding * 2
        let fittingSize = chatInputTextView.sizeThatFits(
            CGSize(width: chatInputTextView.bounds.width, height: .greatestFiniteMagnitude))
        let maxHeight = ceil(font.lineHeight * 4 + insets + padding)
        let newTextViewHeight = min(fittingSize.height, maxHeight)

        chatInputTextView.isScrollEnabled = fittingSize.height > maxHeight

        if newTextViewHeight != chatInputTextViewHeightConstraint.constant {
            chatInputTextViewHeightConstraint.constant = newTextViewHeight
            chatInputContainerHeightConstraint.constant = containerHeight(for: newTextViewHeight)
            view.layoutIfNeeded()
            scrollToBottom()
        }

        if chatInputTextView.isScrollEnabled {
            let end = NSRange(location: chatInputTextView.text.utf16.count, length: 0)
            chatInputTextView.scrollRangeToVisible(end)
        }
    }

    // MARK: - Scroll

    private func scrollToBottom() {
        let totalRows = displayMessages.count + (processingStepText != nil ? 1 : 0)
        guard totalRows > 0 else { return }
        let lastIndexPath = IndexPath(row: totalRows - 1, section: 0)
        chatTableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: true)
    }
}

// MARK: - GraphChatSSEDelegate

extension WorkspaceGraphChatViewController: GraphChatSSEDelegate {

    func onTextDelta(_ delta: String) {
        // Silently accumulate — do NOT update the table until onFinish
        streamingBuffer += delta
    }

    func onToolInputAvailable(toolName: String) {
        updateProcessingBubble(stepText: toolDisplayName(toolName))
    }

    private func toolDisplayName(_ toolName: String) -> String {
        // Strip workspace prefix for multi-workspace mode (e.g. "hive__learn_concept" → "learn_concept")
        let baseTool = toolName.components(separatedBy: "__").last ?? toolName
        switch baseTool {
        case "list_concepts":       return "📚 Browsing concepts"
        case "learn_concept":       return "📖 Reading documentation"
        case "recent_commits":      return "🔍 Checking recent commits"
        case "recent_contributions": return "👤 Reviewing contributions"
        case "repo_agent":          return "🤖 Deep code analysis"
        case "search_logs":         return "📝 Searching logs"
        case "web_search":          return "🌐 Searching the web"
        default:                    return "⚙️ Working..."
        }
    }

    func onToolOutputAvailable() {
        // Keep the processing bubble visible — it will be dismissed in onFinish
        // once the completed assistant message is ready to take its place.
    }

    func onFinish() {
        guard !streamingBuffer.isEmpty else {
            // Nothing to show — just clean up the bubble if present.
            hideProcessingBubble()
            streamingBuffer = ""
            isStreaming = false
            sseManager?.stopStream()
            return
        }

        let assistantMsg = HiveChatMessage(
            id: UUID().uuidString,
            message: streamingBuffer,
            role: "ASSISTANT",
            createdAt: nowISO()
        )
        messages.append(assistantMsg)
        let insertIndexPath = IndexPath(row: displayMessages.count - 1, section: 0)

        if processingStepText != nil {
            // Atomically swap the processing bubble out and the assistant message in —
            // no visible gap between the two.
            let bubbleIndexPath = IndexPath(row: displayMessages.count - 1, section: 0)
            processingStepText = nil
            chatTableView.performBatchUpdates({
                chatTableView.deleteRows(at: [bubbleIndexPath], with: .fade)
                chatTableView.insertRows(at: [insertIndexPath], with: .automatic)
            }, completion: { [weak self] _ in
                self?.scrollToBottom()
            })
        } else {
            chatTableView.insertRows(at: [insertIndexPath], with: .automatic)
            scrollToBottom()
        }

        updateEmptyState()
        streamingBuffer = ""
        isStreaming = false
        sseManager?.stopStream()
    }

    func onError(_ text: String) {
        // Discard any partial buffer — nothing was shown, nothing to remove
        streamingBuffer = ""
        hideProcessingBubble()
        isStreaming = false
        newBubbleHelper.showGenericMessageView(text: text.isEmpty ? "An error occurred. Please try again." : text)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension WorkspaceGraphChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayMessages.count + (processingStepText != nil ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Processing bubble row
        if processingStepText != nil && indexPath.row == displayMessages.count {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "HiveProcessingBubbleCell",
                for: indexPath
            ) as! HiveProcessingBubbleCell
            cell.configure(stepText: processingStepText ?? "Processing...")
            return cell
        }

        // Message row
        let message = displayMessages[indexPath.row]
        let isLast = indexPath.row == displayMessages.count - 1

        if message.artifacts.contains(where: { $0.isClarifyingQuestions }) {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: "ClarifyingQuestionMessageCell",
                for: indexPath
            ) as? ClarifyingQuestionMessageCell else { return UITableViewCell() }
            let answerMessage = messages.first(where: { $0.replyId == message.id && $0.isUserMessage })
            cell.configure(with: message, isLastMessage: isLast, answerMessage: answerMessage)
            cell.onClarifyingAnswerSubmit = { [weak self] answers, replyId in
                self?.sendClarifyingAnswers(answers: answers, replyId: replyId)
            }
            cell.onHeightChanged = { [weak tableView] in
                UIView.performWithoutAnimation {
                    tableView?.beginUpdates()
                    tableView?.endUpdates()
                }
            }
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "FeatureChatMessageCell",
            for: indexPath
        ) as? FeatureChatMessageCell else {
            return UITableViewCell()
        }
        // If this message is a CQ answer, show italic summary instead of raw text
        let italic = cqAnswerItalicText(for: message)
        cell.configure(with: message, isLastMessage: isLast, italicText: italic)
        cell.onHeightChanged = { [weak tableView] in
            UIView.performWithoutAnimation {
                    tableView?.beginUpdates()
                    tableView?.endUpdates()
                }
        }
        return cell
    }

    private func cqAnswerItalicText(for message: HiveChatMessage) -> String? {
        guard let replyId = message.replyId, cqMessageIds.contains(replyId) else { return nil }
        let count = messages.first(where: { $0.id == replyId })
            .flatMap { $0.artifacts.first(where: { $0.isClarifyingQuestions }) }
            .flatMap { $0.clarifyingQuestions }?.count ?? 1
        return count == 1 ? "1 question answered" : "\(count) questions answered"
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

    func textViewDidChange(_ textView: UITextView) {
        guard textView == chatInputTextView else { return }
        updateInputBarHeight()
    }
}
