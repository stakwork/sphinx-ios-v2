//
//  TaskChatViewController.swift
//  sphinx
//
//  Full-screen task chat: header (back + task title) + chat messages + input bar.
//  No CHAT/PLAN/TASKS tabs — this is purely the chat for a single task.
//

import UIKit

class TaskChatViewController: UIViewController {

    // MARK: - Properties
    private var task: WorkspaceTask
    private var workspaceSlug: String
    private var messages: [HiveChatMessage] = []
    private var processingStepText: String? = nil

    // MARK: - Header
    private var headerView: UIView!
    private var backButton: UIButton!
    private var titleLabel: UILabel!
    private var shareButton: UIButton!

    // MARK: - Chat
    private var chatTableView: UITableView!
    private var chatInputContainer: UIView!
    private var chatInputTextView: UITextView!
    private var sendButton: UIButton!
    private var chatInputBottomConstraint: NSLayoutConstraint!
    private var workflowStatusView: WorkflowStatusView!
    private var workflowStatusHeightConstraint: NSLayoutConstraint!
    private var bottomFillView: UIView!

    private var loadingWheel: UIActivityIndicatorView!
    private var emptyLabel: UILabel!

    // MARK: - Init
    static func instantiate(task: WorkspaceTask, workspaceSlug: String) -> TaskChatViewController {
        return TaskChatViewController(task: task, workspaceSlug: workspaceSlug)
    }

    private init(task: WorkspaceTask, workspaceSlug: String) {
        self.task = task
        self.workspaceSlug = workspaceSlug
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyInitialWorkflowStatus()
        setupKeyboardObservers()
        fetchMessages()
        connectWebSocket()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            HivePusherManager.shared.disconnect()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.Sphinx.Body
        setupHeader()
        setupChatArea()
    }

    private func setupHeader() {
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor.Sphinx.Body
        view.addSubview(headerView)

        // Bottom divider line
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.Sphinx.LightDivider
        headerView.addSubview(divider)

        backButton = UIButton(type: .custom)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.titleLabel?.font = UIFont(name: "MaterialIcons-Regular", size: 21)
        backButton.setTitle("\u{E5C4}", for: .normal)
        backButton.setTitleColor(UIColor.Sphinx.WashedOutReceivedText, for: .normal)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        headerView.addSubview(backButton)

        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = task.title
        titleLabel.font = UIFont(name: "Roboto-Medium", size: 14)
        titleLabel.textColor = UIColor.Sphinx.Text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        headerView.addSubview(titleLabel)

        shareButton = UIButton(type: .system)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        shareButton.addTarget(self, action: #selector(shareTappedAction), for: .touchUpInside)
        headerView.addSubview(shareButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 50),
            backButton.heightAnchor.constraint(equalToConstant: 50),

            shareButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            shareButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 50),
            shareButton.heightAnchor.constraint(equalToConstant: 50),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: shareButton.leadingAnchor, constant: -8),

            divider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupChatArea() {
        // Loading wheel (while fetching)
        loadingWheel = UIActivityIndicatorView(style: .medium)
        loadingWheel.translatesAutoresizingMaskIntoConstraints = false
        loadingWheel.hidesWhenStopped = true
        loadingWheel.color = UIColor.Sphinx.Text
        view.addSubview(loadingWheel)

        // Empty state label
        emptyLabel = UILabel()
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "No messages yet"
        emptyLabel.textColor = UIColor.Sphinx.SecondaryText
        emptyLabel.font = UIFont(name: "Roboto-Regular", size: 15)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        // Chat table view
        chatTableView = UITableView()
        chatTableView.translatesAutoresizingMaskIntoConstraints = false
        chatTableView.backgroundColor = .clear
        chatTableView.separatorStyle = .none
        chatTableView.delegate = self
        chatTableView.dataSource = self
        chatTableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        chatTableView.register(FeatureChatMessageCell.self, forCellReuseIdentifier: "FeatureChatMessageCell")
        chatTableView.register(HiveProcessingBubbleCell.self, forCellReuseIdentifier: "HiveProcessingBubbleCell")
        view.addSubview(chatTableView)

        // Bottom Fill View — covers the gap between chatInputContainer and the physical screen bottom
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
        chatInputContainer.addSubview(chatInputTextView)

        // Send button
        sendButton = UIButton()
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("➤", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        sendButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        sendButton.layer.cornerRadius = 20
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        chatInputContainer.addSubview(sendButton)

        // Workflow Status View
        workflowStatusView = WorkflowStatusView()
        workflowStatusView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(workflowStatusView)

        workflowStatusView.onRetryTapped = { [weak self] in
            guard let self else { return }
            API.sharedInstance.retryTaskWorkflowWithAuth(taskId: self.task.id, callback: {}, errorCallback: {})
        }

        chatTableView.keyboardDismissMode = .interactive

        chatInputBottomConstraint = chatInputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        workflowStatusHeightConstraint = workflowStatusView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            loadingWheel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingWheel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            chatTableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            chatTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatTableView.bottomAnchor.constraint(equalTo: workflowStatusView.topAnchor),

            workflowStatusView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            workflowStatusView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            workflowStatusView.bottomAnchor.constraint(equalTo: chatInputContainer.topAnchor),
            workflowStatusHeightConstraint,

            chatInputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatInputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatInputBottomConstraint,
            chatInputContainer.heightAnchor.constraint(equalToConstant: 80),

            bottomFillView.topAnchor.constraint(equalTo: chatInputContainer.bottomAnchor),
            bottomFillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFillView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            chatInputTextView.topAnchor.constraint(equalTo: chatInputContainer.topAnchor, constant: 12),
            chatInputTextView.leadingAnchor.constraint(equalTo: chatInputContainer.leadingAnchor, constant: 16),
            chatInputTextView.bottomAnchor.constraint(equalTo: chatInputContainer.bottomAnchor, constant: -12),
            chatInputTextView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),

            sendButton.centerYAnchor.constraint(equalTo: chatInputContainer.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: chatInputContainer.trailingAnchor, constant: -16),
            sendButton.widthAnchor.constraint(equalToConstant: 80),
            sendButton.heightAnchor.constraint(equalToConstant: 40)
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
        guard let info = notification.userInfo,
              let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        chatInputBottomConstraint.constant = -(frame.height - view.safeAreaInsets.bottom)
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
        scrollToBottom(animated: true)
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let info = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        chatInputBottomConstraint.constant = 0
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    // MARK: - Actions
    @objc private func shareTappedAction() {
        let url = "https://hive.sphinx.chat/w/\(workspaceSlug)/task/\(task.id)"
        let label = "Check out this task: \(task.title) — \(url)"
        let shareVC = HiveShareViewController.instantiate(url: url, label: label)
        present(shareVC, animated: true)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func sendTapped() {
        guard let message = chatInputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            chatInputTextView.resignFirstResponder()
            return
        }
        chatInputTextView.text = ""
        chatInputTextView.resignFirstResponder()
        showProcessingBubble()

        API.sharedInstance.sendTaskChatMessageWithAuth(
            taskId: task.id,
            message: message,
            socketId: HivePusherManager.shared.socketId,
            callback: { [weak self] sentMessage in
                DispatchQueue.main.async {
                    guard let self = self, let sentMessage = sentMessage else { return }
                    self.newMessageReceived(sentMessage)
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.showSendMessageError()
                }
            }
        )
    }

    private func sendClarifyingAnswers(answers: [String], replyId: String) {
        showProcessingBubble()
        let joined = answers.joined(separator: "\n\n")
        API.sharedInstance.sendTaskChatMessageWithAuth(
            taskId: task.id,
            message: joined,
            replyId: replyId,
            socketId: HivePusherManager.shared.socketId,
            callback: { [weak self] sentMessage in
                DispatchQueue.main.async {
                    guard let self = self, let sentMessage = sentMessage else { return }
                    self.newMessageReceived(sentMessage)
                    // Lock the cell that triggered the submit
                    if let idx = self.messages.firstIndex(where: { $0.id == replyId }),
                       let cell = self.chatTableView.cellForRow(at: IndexPath(row: idx, section: 0)) as? FeatureChatMessageCell {
                        cell.lockClarifyingQuestionsView()
                    }
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.showSendMessageError()
                }
            }
        )
    }

    private func showSendMessageError() {
        AlertHelper.showAlert(
            title: "generic.error.title".localized,
            message: "Failed to send message",
            on: self
        )
    }

    // MARK: - Data
    private func fetchMessages() {
        loadingWheel.startAnimating()
        chatTableView.isHidden = true
        emptyLabel.isHidden = true

        API.sharedInstance.fetchTaskMessagesWithAuth(
            taskId: task.id,
            callback: { [weak self] messages in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingWheel.stopAnimating()
                    self.messages = messages
                    self.chatTableView.isHidden = false
                    self.emptyLabel.isHidden = !messages.isEmpty
                    self.chatTableView.reloadData()
                    if !messages.isEmpty { self.scrollToBottom(animated: false) }
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingWheel.stopAnimating()
                    self.chatTableView.isHidden = false
                    self.emptyLabel.isHidden = false
                    self.emptyLabel.text = "Could not load messages"
                }
            }
        )
    }

    // MARK: - Processing Bubble
    private func showProcessingBubble() {
        guard processingStepText == nil else { return }
        processingStepText = "Communicating with workflow"
        let indexPath = IndexPath(row: messages.count, section: 0)
        chatTableView.insertRows(at: [indexPath], with: .automatic)
        scrollToBottom(animated: true)
    }

    private func hideProcessingBubble() {
        guard processingStepText != nil else { return }
        let indexPath = IndexPath(row: messages.count, section: 0)
        processingStepText = nil
        chatTableView.deleteRows(at: [indexPath], with: .automatic)
    }

    private func updateProcessingBubble(stepText: String) {
        guard processingStepText != nil else { return }
        processingStepText = stepText
        let indexPath = IndexPath(row: messages.count, section: 0)
        chatTableView.reloadRows(at: [indexPath], with: .none)
    }

    private func scrollToBottom(animated: Bool = true) {
        let totalRows = messages.count + (processingStepText != nil ? 1 : 0)
        guard totalRows > 0 else { return }
        let indexPath = IndexPath(row: totalRows - 1, section: 0)
        chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    // MARK: - WebSocket
    private func connectWebSocket() {
        HivePusherManager.shared.delegate = self
        HivePusherManager.shared.connect(taskId: task.id)
    }

    // MARK: - Workflow Status
    private func applyWorkflowStatus(_ status: WorkflowStatus) {
        workflowStatusView.status = status
        switch status {
        case .IN_PROGRESS, .PENDING, .HALTED:
            workflowStatusHeightConstraint.constant = 32
            workflowStatusView.show(animated: true)
            UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
        case .COMPLETED, .ERROR, .FAILED:
            workflowStatusHeightConstraint.constant = 0
            workflowStatusView.hide(animated: true)
            UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
            hideProcessingBubble()
        }
    }

    private func applyInitialWorkflowStatus() {
        guard let raw = task.workflowStatus,
              let status = WorkflowStatus(rawValue: raw),
              status == .IN_PROGRESS || status == .PENDING || status == .HALTED else { return }
        applyWorkflowStatus(status)
    }
}

// MARK: - HivePusherDelegate
extension TaskChatViewController: HivePusherDelegate {
    func taskGenerationStatusChanged(status: String, featureId: String) {
        
    }
    
    func workflowStatusChanged(status: WorkflowStatus) {
        DispatchQueue.main.async {
            self.applyWorkflowStatus(status)
        }
    }

    func featureUpdateReceived(featureId: String) {
        // no-op: TaskChatViewController does not display feature-level updates
    }

    func newMessageReceived(_ message: HiveChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        hideProcessingBubble()
        messages.append(message)
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        chatTableView.insertRows(at: [indexPath], with: .automatic)
        scrollToBottom()
    }

    func prStatusChanged(taskId: String?, prNumber: Int, state: String, artifactStatus: String, prUrl: String?, problemDetails: String?) {
        guard let idx = messages.firstIndex(where: {
            $0.artifacts.first(where: { $0.isPullRequest })?.prContent?.number == prNumber
        }) else { return }
        guard let artifactIdx = messages[idx].artifacts.firstIndex(where: { $0.isPullRequest }) else { return }
        messages[idx].artifacts[artifactIdx].prContent?.state = state
        messages[idx].artifacts[artifactIdx].prContent?.status = artifactStatus
        if let url = prUrl { messages[idx].artifacts[artifactIdx].prContent?.url = url }
        DispatchQueue.main.async {
            self.chatTableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
        }
    }

    func featureTitleUpdated(featureId: String, newTitle: String) {
        // no-op: TaskChatViewController is not scoped to a feature
    }

    func taskTitleUpdated(taskId: String, newTitle: String) {
        guard taskId == task.id else { return }
        task.title = newTitle
        DispatchQueue.main.async { self.titleLabel.text = newTitle }
    }

    func processingStepReceived(message: String) {
        DispatchQueue.main.async {
            if self.processingStepText == nil {
                self.showProcessingBubble()
            }
            self.updateProcessingBubble(stepText: message)
        }
    }
}

// MARK: - UITableView
extension TaskChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count + (processingStepText != nil ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if processingStepText != nil && indexPath.row == messages.count {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "HiveProcessingBubbleCell",
                for: indexPath
            ) as! HiveProcessingBubbleCell
            cell.configure(stepText: processingStepText ?? "Communicating with workflow")
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "FeatureChatMessageCell",
            for: indexPath
        ) as? FeatureChatMessageCell else { return UITableViewCell() }
        cell.configure(with: messages[indexPath.row])
        cell.onClarifyingAnswerSubmit = { [weak self] answers, replyId in
            self?.sendClarifyingAnswers(answers: answers, replyId: replyId)
        }
        return cell
    }
}
