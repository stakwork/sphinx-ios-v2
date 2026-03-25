//
//  TaskChatViewController.swift
//  sphinx
//
//  Full-screen task chat: header (back + task title) + chat messages + input bar.
//  No CHAT/PLAN/TASKS tabs — this is purely the chat for a single task.
//

import UIKit
import AVKit
import AVFoundation
import PhotosUI

class TaskChatViewController: UIViewController {

    // MARK: - Properties
    private var task: WorkspaceTask
    private var workspaceSlug: String
    private var workspaceId: String
    private var messages: [HiveChatMessage] = []

    private var cqMessageIds: Set<String> {
        Set(messages.filter { $0.artifacts.contains(where: { $0.isClarifyingQuestions }) }.map { $0.id })
    }

    private var displayMessages: [HiveChatMessage] {
        messages.filter { $0.isDisplayable }
    }

    private var hasAppeared = false
    private var cachedStakworkProjectId: Int?
    private var anyCableManager: HiveAnyCableManager?
    private var agentEventsManager: AgentEventsSSEManager?

    // MARK: - Header
    private var headerView: UIView!
    private var headerStackView: UIStackView!
    private var backButton: UIButton!
    private var titleLabel: UILabel!
    private var releasePodButton: UIButton!
    private var shareButton: UIButton!

    private let bubbleHelper = NewMessageBubbleHelper()

    // MARK: - Chat
    private var chatTableView: UITableView!
    private var chatInputContainer: UIView!
    private var chatInputTextView: UITextView!
    private var sendButton: UIButton!
    private var chatInputBottomConstraint: NSLayoutConstraint!
    private var chatInputContainerHeightConstraint: NSLayoutConstraint!
    private var chatInputTextViewHeightConstraint: NSLayoutConstraint!
    private var workflowStatusView: WorkflowStatusView!
    private var workflowStatusHeightConstraint: NSLayoutConstraint!
    private var bottomFillView: UIView!

    // MARK: - Attachments
    private var attachButton: UIButton!
    private var pendingAttachmentsBar: PendingAttachmentsBarView!
    private var pendingAttachmentsBarHeightConstraint: NSLayoutConstraint!
    private var pendingAttachments: [PendingAttachment] = []

    // MARK: - Mic / Speech
    private var micButton: UIButton!
    private let speechManager = SpeechTranscriptionManager()

    // MARK: - Agent state
    private var isAgentWorking: Bool = false

    // Autocomplete
    private var availableWorkspaces: [Workspace] = []
    private var filteredWorkspaces: [Workspace] = []
    private var autocompleteContainer: UIView!
    private var autocompleteStack: UIStackView!
    private var autocompleteHeightConstraint: NSLayoutConstraint!
    /// NSRange of "@query" in chatInputTextView at the moment the popup is shown/updated
    private var atTriggerNSRange: NSRange?

    private var loadingWheel: UIActivityIndicatorView!
    private var emptyLabel: UILabel!

    // MARK: - Init
    static func instantiate(task: WorkspaceTask, workspaceSlug: String, workspaceId: String) -> TaskChatViewController {
        return TaskChatViewController(task: task, workspaceSlug: workspaceSlug, workspaceId: workspaceId)
    }

    private init(task: WorkspaceTask, workspaceSlug: String, workspaceId: String) {
        self.task = task
        self.workspaceSlug = workspaceSlug
        self.workspaceId = workspaceId
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
        speechManager.requestPermission { [weak self] granted in
            self?.micButton.isHidden = !granted
            if !granted {
                self?.bubbleHelper.showGenericMessageView(
                    text: "Speech recognition permission denied.",
                    delay: 3, textColor: .white,
                    backColor: UIColor.Sphinx.PrimaryRed, backAlpha: 1.0)
            }
        }
        cachedStakworkProjectId = task.stakworkProjectId
        connectWebSocket()         // connect Pusher immediately with known taskId
        fetchMessages()
        fetchTaskDetailAndConnect() // will call connectAnyCable() once projectId is known
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        API.sharedInstance.fetchWorkspacesWithAuth(
            callback: { [weak self] workspaces in
                DispatchQueue.main.async { self?.availableWorkspaces = workspaces }
            },
            errorCallback: { /* silent fail — autocomplete just won't show */ }
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layoutIfNeeded()   // forces constraint resolution before push transition animates
        if hasAppeared {
            reconnectAndRefresh()
        } else {
            hasAppeared = true
            connectWebSocket()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        HivePusherManager.shared.disconnect()
        anyCableManager?.disconnect()
        anyCableManager = nil
        agentEventsManager?.stopStream()
        agentEventsManager = nil
    }

    @objc private func appWillEnterForeground() {
        reconnectAndRefresh()
    }

    private func reconnectAndRefresh() {
        connectWebSocket()
        fetchMessages()
        fetchTaskDetailAndConnect()
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

        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = task.title
        titleLabel.font = UIFont(name: "Roboto-Medium", size: 14)
        titleLabel.textColor = UIColor.Sphinx.Text
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        shareButton = UIButton(type: .system)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        shareButton.addTarget(self, action: #selector(shareTappedAction), for: .touchUpInside)

        releasePodButton = UIButton(type: .system)
        releasePodButton.translatesAutoresizingMaskIntoConstraints = false
        releasePodButton.setImage(UIImage(systemName: "server.rack"), for: .normal)
        releasePodButton.tintColor = UIColor.Sphinx.PrimaryGreen
        releasePodButton.addTarget(self, action: #selector(releasePodTapped), for: .touchUpInside)
        releasePodButton.isHidden = true

        // Fix sizes for icon buttons
        backButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
        backButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        shareButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        shareButton.heightAnchor.constraint(equalToConstant: 35).isActive = true
        releasePodButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        releasePodButton.heightAnchor.constraint(equalToConstant: 35).isActive = true

        // Build the stack
        headerStackView = UIStackView(arrangedSubviews: [backButton, titleLabel, releasePodButton, shareButton])
        headerStackView.axis = .horizontal
        headerStackView.alignment = .center
        headerStackView.distribution = .fill
        headerStackView.spacing = 0
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerStackView)

        // Custom spacing
        headerStackView.setCustomSpacing(8, after: backButton)
        headerStackView.setCustomSpacing(8, after: titleLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            headerStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerStackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            headerStackView.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerStackView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),

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
        chatTableView.register(ClarifyingQuestionMessageCell.self, forCellReuseIdentifier: "ClarifyingQuestionMessageCell")
        chatTableView.rowHeight = UITableView.automaticDimension
        chatTableView.estimatedRowHeight = 200
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

        // Attach button
        attachButton = UIButton(type: .system)
        attachButton.translatesAutoresizingMaskIntoConstraints = false
        let paperclipConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        attachButton.setImage(UIImage(systemName: "paperclip", withConfiguration: paperclipConfig), for: .normal)
        attachButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        attachButton.addTarget(self, action: #selector(attachTapped), for: .touchUpInside)

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

        // Send button
        sendButton = UIButton()
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("➤", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        sendButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        sendButton.layer.cornerRadius = singleLineTextViewHeight() / 2
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        // Mic button
        let micConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        micButton = UIButton(type: .system)
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micConfig), for: .normal)
        micButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(micLongPressed(_:)))
        lp.minimumPressDuration = 0.1
        micButton.addGestureRecognizer(lp)

        // Layout: [chatInputTextView --- flex ---][attachButton 32][micButton 32][sendButton ●]
        chatInputContainer.addSubview(chatInputTextView)
        chatInputContainer.addSubview(attachButton)
        chatInputContainer.addSubview(micButton)
        chatInputContainer.addSubview(sendButton)

        NSLayoutConstraint.activate([
            // Send button — right edge
            sendButton.trailingAnchor.constraint(equalTo: chatInputContainer.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: chatInputContainer.centerYAnchor),
            sendButton.heightAnchor.constraint(equalToConstant: singleLineTextViewHeight()),
            sendButton.widthAnchor.constraint(equalTo: sendButton.heightAnchor),

            // Mic button — immediately left of send button
            micButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            micButton.centerYAnchor.constraint(equalTo: chatInputContainer.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 32),
            micButton.heightAnchor.constraint(equalToConstant: 32),

            // Attach button — immediately left of mic button
            attachButton.trailingAnchor.constraint(equalTo: micButton.leadingAnchor, constant: -4),
            attachButton.centerYAnchor.constraint(equalTo: chatInputContainer.centerYAnchor),
            attachButton.widthAnchor.constraint(equalToConstant: 32),
            attachButton.heightAnchor.constraint(equalToConstant: 32),

            // Text view — fills from left edge to attach button
            chatInputTextView.topAnchor.constraint(equalTo: chatInputContainer.topAnchor, constant: 12),
            chatInputTextView.leadingAnchor.constraint(equalTo: chatInputContainer.leadingAnchor, constant: 16),
            chatInputTextView.trailingAnchor.constraint(equalTo: attachButton.leadingAnchor, constant: -4),
            {
                chatInputTextViewHeightConstraint = chatInputTextView.heightAnchor.constraint(equalToConstant: singleLineTextViewHeight())
                return chatInputTextViewHeightConstraint
            }()
        ])

        // Workflow Status View
        workflowStatusView = WorkflowStatusView()
        workflowStatusView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(workflowStatusView)

        workflowStatusView.onRetryTapped = { [weak self] in
            guard let self else { return }
            API.sharedInstance.retryTaskWorkflowWithAuth(taskId: self.task.id, callback: {}, errorCallback: {})
        }

        chatTableView.keyboardDismissMode = .interactive

        // Autocomplete table view
        // Autocomplete popup (scroll view + stack of buttons — avoids UITableView delegate timing issues)
        autocompleteContainer = UIView()
        autocompleteContainer.translatesAutoresizingMaskIntoConstraints = false
        autocompleteContainer.backgroundColor = UIColor.Sphinx.HeaderBG
        autocompleteContainer.isHidden = true
        autocompleteContainer.clipsToBounds = true
        view.addSubview(autocompleteContainer)

        let autocompleteScrollView = UIScrollView()
        autocompleteScrollView.translatesAutoresizingMaskIntoConstraints = false
        autocompleteScrollView.showsVerticalScrollIndicator = true
        autocompleteScrollView.bounces = true
        autocompleteContainer.addSubview(autocompleteScrollView)

        autocompleteStack = UIStackView()
        autocompleteStack.translatesAutoresizingMaskIntoConstraints = false
        autocompleteStack.axis = .vertical
        autocompleteStack.spacing = 0
        autocompleteStack.distribution = .fill
        autocompleteScrollView.addSubview(autocompleteStack)

        NSLayoutConstraint.activate([
            autocompleteScrollView.topAnchor.constraint(equalTo: autocompleteContainer.topAnchor),
            autocompleteScrollView.leadingAnchor.constraint(equalTo: autocompleteContainer.leadingAnchor),
            autocompleteScrollView.trailingAnchor.constraint(equalTo: autocompleteContainer.trailingAnchor),
            autocompleteScrollView.bottomAnchor.constraint(equalTo: autocompleteContainer.bottomAnchor),

            autocompleteStack.topAnchor.constraint(equalTo: autocompleteScrollView.topAnchor),
            autocompleteStack.leadingAnchor.constraint(equalTo: autocompleteScrollView.leadingAnchor),
            autocompleteStack.trailingAnchor.constraint(equalTo: autocompleteScrollView.trailingAnchor),
            autocompleteStack.bottomAnchor.constraint(equalTo: autocompleteScrollView.bottomAnchor),
            autocompleteStack.widthAnchor.constraint(equalTo: autocompleteScrollView.widthAnchor)
        ])

        chatInputTextView.delegate = self

        // Pending attachments bar — inserted between workflowStatusView and chatInputContainer
        pendingAttachmentsBar = PendingAttachmentsBarView()
        pendingAttachmentsBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pendingAttachmentsBar)

        pendingAttachmentsBar.onRemove = { [weak self] id in
            guard let self = self else { return }
            self.pendingAttachments.removeAll { $0.id == id }
            self.refreshAttachmentsBar()
            self.updateSendButtonState()
        }

        chatInputBottomConstraint = chatInputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        workflowStatusHeightConstraint = workflowStatusView.heightAnchor.constraint(equalToConstant: 0)
        autocompleteHeightConstraint = autocompleteContainer.heightAnchor.constraint(equalToConstant: 0)
        pendingAttachmentsBarHeightConstraint = pendingAttachmentsBar.heightAnchor.constraint(equalToConstant: 0)

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
            workflowStatusView.bottomAnchor.constraint(equalTo: pendingAttachmentsBar.topAnchor),
            workflowStatusHeightConstraint,

            pendingAttachmentsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pendingAttachmentsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pendingAttachmentsBar.bottomAnchor.constraint(equalTo: chatInputContainer.topAnchor),
            pendingAttachmentsBarHeightConstraint,

            chatInputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatInputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatInputBottomConstraint,
            {
                let oneLine = singleLineTextViewHeight()
                chatInputContainerHeightConstraint = chatInputContainer.heightAnchor.constraint(equalToConstant: containerHeight(for: oneLine))
                return chatInputContainerHeightConstraint
            }(),

            bottomFillView.topAnchor.constraint(equalTo: chatInputContainer.bottomAnchor),
            bottomFillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFillView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            autocompleteContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            autocompleteContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            autocompleteContainer.bottomAnchor.constraint(equalTo: chatInputContainer.topAnchor),
            autocompleteHeightConstraint
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
                self?.bubbleHelper.showGenericMessageView(
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

    // MARK: - Actions

    @objc private func attachTapped() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 0 // unlimited
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func refreshAttachmentsBar() {
        pendingAttachmentsBar.configure(with: pendingAttachments)
        pendingAttachmentsBarHeightConstraint.constant = pendingAttachments.isEmpty ? 0 : 88
        view.layoutIfNeeded()
        scrollToBottom(animated: false)
    }

    private func updateSendButtonState() {
        let uploading = pendingAttachments.contains { $0.state == .uploading || $0.state == .failed }
        let blocked = isAgentWorking || uploading
        sendButton.isEnabled = !blocked
        sendButton.alpha = blocked ? 0.5 : 1.0
        micButton.isEnabled = !blocked
        micButton.alpha = blocked ? 0.5 : 1.0
    }

    @objc private func releasePodTapped() {
        AlertHelper.showTwoOptionsAlert(
            title: "Release Pod",
            message: "Are you sure you want to release the pod for this task?",
            on: self,
            confirm: { [weak self] in self?.performReleasePod() }
        )
    }

    private func performReleasePod() {
        guard let podId = task.podId else { return }
        releasePodButton.isEnabled = false
        releasePodButton.alpha = 0.4
        API.sharedInstance.releasePodWithAuth(
            workspaceId: workspaceId,
            podId: podId,
            taskId: task.id,
            callback: { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.releasePodButton.isEnabled = true
                    self.releasePodButton.alpha = 1.0
                    self.releasePodButton.isHidden = true
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.releasePodButton.isEnabled = true
                    self.releasePodButton.alpha = 1.0
                    AlertHelper.showAlert(
                        title: "generic.error.title".localized,
                        message: "Failed to release pod. Please try again.",
                        on: self
                    )
                }
            }
        )
    }

    @objc private func shareTappedAction() {
        let url = "https://hive.sphinx.chat/w/\(workspaceSlug)/task/\(task.id)"
        let label = "Check out this task: \(task.title) — \(url)"
        let shareVC = HiveShareViewController.instantiate(url: url, label: label, workspaceSlug: workspaceSlug)
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
        chatInputTextView.typingAttributes = [
            .foregroundColor: UIColor.Sphinx.Text,
            .font: UIFont(name: "Roboto-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        ]
        let oneLine = singleLineTextViewHeight()
        chatInputTextViewHeightConstraint.constant = oneLine
        chatInputContainerHeightConstraint.constant = containerHeight(for: oneLine)
        chatInputTextView.isScrollEnabled = false
        view.layoutIfNeeded()
        chatInputTextView.resignFirstResponder()

        let attachmentsPayload: [[String: AnyObject]] = pendingAttachments
            .filter { $0.state == .done }
            .compactMap { pending in
                guard let s3Path = pending.s3Path else { return nil }
                return [
                    "path": s3Path as AnyObject,
                    "filename": pending.filename as AnyObject,
                    "mimeType": pending.mimeType as AnyObject,
                    "size": pending.size as AnyObject
                ]
            }

        // Dismiss the attachments preview bar immediately on send tap
        pendingAttachments = []
        refreshAttachmentsBar()
        updateSendButtonState()

        API.sharedInstance.sendTaskChatMessageWithAuth(
            taskId: task.id,
            message: message,
            socketId: HivePusherManager.shared.socketId,
            attachments: attachmentsPayload,
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
                    // Reload the CQ cell so it recomputes height with answered state
                    if let displayIdx = self.displayMessages.firstIndex(where: { $0.id == replyId }) {
                        self.chatTableView.reloadRows(at: [IndexPath(row: displayIdx, section: 0)], with: .none)
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
            callback: { [weak self] messages, podId in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingWheel.stopAnimating()
                    self.messages = messages
                    self.chatTableView.isHidden = false
                    self.emptyLabel.isHidden = !messages.isEmpty
                    self.chatTableView.reloadData()
                    if !messages.isEmpty { self.scrollToBottom(animated: false) }
                    self.task.podId = podId
                    self.releasePodButton.isHidden = (podId == nil)
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
            scrollToBottom(animated: false)
        }

        if chatInputTextView.isScrollEnabled {
            let end = NSRange(location: chatInputTextView.text.utf16.count, length: 0)
            chatInputTextView.scrollRangeToVisible(end)
        }
    }

    private func scrollToBottom(animated: Bool = true) {
        let totalRows = displayMessages.count
        guard totalRows > 0 else { return }
        let indexPath = IndexPath(row: totalRows - 1, section: 0)
        chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    // MARK: - WebSocket

    /// Fetches task detail to resolve cachedStakworkProjectId, then connects AnyCable.
    private func fetchTaskDetailAndConnect() {
        API.sharedInstance.fetchTaskDetailWithAuth(
            taskId: task.id,
            callback: { [weak self] updatedTask in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let updated = updatedTask {
                        let podId = self.task.podId ?? updated.podId
                        self.task = updated
                        self.task.podId = podId
                        self.cachedStakworkProjectId = updated.stakworkProjectId
                    }
                    self.connectAnyCable()
                }
            },
            errorCallback: { [weak self] in
                print("[TaskChatVC] Failed to fetch task detail for stakworkProjectId")
            }
        )
    }

    /// Connects (or re-points) Pusher only. Safe to call any time — no projectId needed.
    private func connectWebSocket() {
        HivePusherManager.shared.delegate = self
        HivePusherManager.shared.connect(taskId: task.id)
    }

    /// Connects AnyCable. Only called after cachedStakworkProjectId is populated.
    private func connectAnyCable() {
        guard let projectId = cachedStakworkProjectId else { return }
        guard anyCableManager == nil else { return }
        anyCableManager = HiveAnyCableManager()
        anyCableManager?.delegate = self
        anyCableManager?.connect(projectId: projectId)
    }

    // MARK: - Workflow Status
    private func updateStatusViewHeight() {
        workflowStatusHeightConstraint.constant = workflowStatusView.hasDetailText ? 48 : 32
    }

    private func applyWorkflowStatus(_ status: WorkflowStatus, animated: Bool = true) {
        workflowStatusView.status = status
        switch status {
        case .IN_PROGRESS, .HALTED:
            updateStatusViewHeight()
            workflowStatusView.show(animated: animated)
            if animated {
                UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
            } else {
                self.view.layoutIfNeeded()
            }
            setInputEnabled(false)
        case .PENDING, .COMPLETED, .ERROR, .FAILED:
            workflowStatusView.setStepDetail(nil)
            workflowStatusHeightConstraint.constant = 0
            workflowStatusView.hide(animated: animated)
            if animated {
                UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
            } else {
                self.view.layoutIfNeeded()
            }
            setInputEnabled(true)
        }
    }

    /// Enables or disables the input bar (send + attach + mic + text field) when the agent is working.
    private func setInputEnabled(_ enabled: Bool) {
        isAgentWorking = !enabled
        chatInputTextView.isEditable = enabled
        attachButton.isEnabled = enabled
        attachButton.alpha = enabled ? 1.0 : 0.5
        micButton.isEnabled = enabled
        micButton.alpha = enabled ? 1.0 : 0.5
        // Let updateSendButtonState handle send button — it checks both workflow + upload state
        updateSendButtonState()
    }

    private func applyInitialWorkflowStatus() {
        guard let raw = task.workflowStatus,
              let status = WorkflowStatus(rawValue: raw),
              status == .IN_PROGRESS || status == .HALTED else { return }
        applyWorkflowStatus(status, animated: false)
    }
}

// MARK: - HivePusherDelegate
extension TaskChatViewController: HivePusherDelegate {
    func taskGenerationStatusChanged(status: String, featureId: String) {
        
    }
    
    func workflowStatusChanged(status: WorkflowStatus) {
        DispatchQueue.main.async {
            self.applyWorkflowStatus(status)
            
//            if status == .IN_PROGRESS || status == .PENDING {
//                self.showProcessingBubble()
//                self.fetchAndUpdateWorkflowStep()
//            }
        }
    }

    func featureUpdateReceived(featureId: String) {
        // no-op: TaskChatViewController does not display feature-level updates
    }

    func newMessageReceived(_ message: HiveChatMessage) {
        // STREAM artifact → open agent events SSE for status bar second line
        if let streamInfo = message.artifacts.first(where: { $0.isStream })?.streamInfo {
            connectAgentEventsStream(
                requestId: streamInfo.requestId,
                eventsToken: streamInfo.eventsToken,
                baseUrl: streamInfo.baseUrl
            )
        }

        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        guard message.isDisplayable else { return }
        let indexPath = IndexPath(row: displayMessages.count - 1, section: 0)
        UIView.performWithoutAnimation {
            chatTableView.insertRows(at: [indexPath], with: .none)
        }
        // If it's a CQ answer, also reload the CQ cell to show answered state
        if cqMessageIds.contains(message.replyId ?? "") {
            if let displayIdx = displayMessages.firstIndex(where: { $0.id == message.replyId }) {
                chatTableView.reloadRows(at: [IndexPath(row: displayIdx, section: 0)], with: .none)
            }
        }
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
            if let displayIdx = self.displayMessages.firstIndex(where: { $0.id == self.messages[idx].id }) {
                self.chatTableView.reloadRows(at: [IndexPath(row: displayIdx, section: 0)], with: .none)
            }
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

}

// MARK: - HiveAnyCableDelegate
extension TaskChatViewController: HiveAnyCableDelegate {
    func workflowStepTextReceived(stepText: String) {
        workflowStatusView.setStatusText(stepText)
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }
}

// MARK: - Agent Events SSE (second stream for working status bar)
extension TaskChatViewController {

    func connectAgentEventsStream(requestId: String, eventsToken: String, baseUrl: String) {
        agentEventsManager?.stopStream()
        agentEventsManager = AgentEventsSSEManager()
        agentEventsManager?.delegate = self
        agentEventsManager?.startStream(requestId: requestId, eventsToken: eventsToken, baseUrl: baseUrl)
    }
}

extension TaskChatViewController: AgentEventsSSEDelegate {

    func agentEventToolCall(toolName: String, input: [String: Any]?) {
        let display = agentToolDisplayText(toolName: toolName, input: input)
        workflowStatusView.setStepDetail(display)
        updateStatusViewHeight()
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    func agentEventText(_ text: String) {
        let sanitised = text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        workflowStatusView.setStepDetail(sanitised)
        updateStatusViewHeight()
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    func agentEventFinish() {
        agentEventsManager?.stopStream()
        agentEventsManager = nil
    }

    func agentEventError(_ message: String) {
        print("[AgentEventsSSE] TaskChat error: \(message)")
        agentEventsManager?.stopStream()
        agentEventsManager = nil
    }

    private func agentToolDisplayText(toolName: String, input: [String: Any]?) -> String {
        let baseTool = toolName.components(separatedBy: "__").last ?? toolName
        let icon: String
        switch baseTool {
        case "list_concepts":        icon = "📚 Browsing concepts"
        case "learn_concept":        icon = "📖 Reading documentation"
        case "recent_commits":       icon = "🔍 Checking recent commits"
        case "recent_contributions": icon = "👤 Reviewing contributions"
        case "repo_agent":           icon = "🤖 Deep code analysis"
        case "search_logs":          icon = "📝 Searching logs"
        case "web_search":           icon = "🌐 Searching the web"
        default:                     icon = "⚙️ \(baseTool)"
        }
        guard let input = input, let first = input.first else { return icon }
        let value = String(describing: first.value)
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let detail = "\(first.key): \(value)"
        let combined = "\(icon) — \(detail)"
        return combined
    }
}

// MARK: - UITableView
extension TaskChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayMessages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let isLast = indexPath.row == displayMessages.count - 1
        if displayMessages[indexPath.row].artifacts.contains(where: { $0.isClarifyingQuestions }) {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: "ClarifyingQuestionMessageCell",
                for: indexPath
            ) as? ClarifyingQuestionMessageCell else { return UITableViewCell() }
            let cqMessage = displayMessages[indexPath.row]
            let answerMessage = messages.first(where: { $0.replyId == cqMessage.id && $0.isUserMessage })
            cell.configure(with: cqMessage, isLastMessage: isLast, answerMessage: answerMessage)
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
        ) as? FeatureChatMessageCell else { return UITableViewCell() }
        let msg = displayMessages[indexPath.row]
        // If this message is a CQ answer, show italic summary instead of raw text
        let italic = cqAnswerItalicText(for: msg)
        cell.configure(with: msg, isLastMessage: isLast, italicText: italic)
        cell.onHeightChanged = { [weak tableView] in
            UIView.performWithoutAnimation {
                    tableView?.beginUpdates()
                    tableView?.endUpdates()
                }
        }
        cell.onAttachmentTap = { [weak self] attachment in
            self?.handleAttachmentTap(attachment)
        }
        return cell
    }

    private func cqAnswerItalicText(for message: HiveChatMessage) -> String? {
        guard let replyId = message.replyId, cqMessageIds.contains(replyId) else { return nil }
        let count = messages.first(where: { $0.id == replyId })
            .flatMap { $0.artifacts.first(where: { $0.isClarifyingQuestions }) }
            .flatMap { $0.clarifyingQuestions }?.count ?? 1
        return count == 1 ? "1 clarifying question answered" : "\(count) clarifying questions answered"
    }

    private func handleAttachmentTap(_ attachment: HiveChatMessageAttachment) {
        guard let s3Key = attachment.resolvedUrl else { return }
        let mime = attachment.mimeType ?? ""
        bubbleHelper.showLoadingWheel()
        API.sharedInstance.fetchPresignedUrlWithAuth(s3Key: s3Key) { [weak self] presignedStr in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let urlStr = presignedStr, let url = URL(string: urlStr) else {
                    self.bubbleHelper.hideLoadingWheel()
                    return
                }
                if mime.hasPrefix("image/") {
                    if let vc = AttachmentFullScreenViewController.instantiate(imageUrl: url) {
                        self.present(vc, animated: true) {
                            self.bubbleHelper.hideLoadingWheel()
                        }
                    } else {
                        self.bubbleHelper.hideLoadingWheel()
                    }
                } else if mime.hasPrefix("video/") {
                    let player = AVPlayer(url: url)
                    let vc = AVPlayerViewController()
                    vc.player = player
                    self.present(vc, animated: true) {
                        self.bubbleHelper.hideLoadingWheel()
                        player.play()
                    }
                } else {
                    self.bubbleHelper.hideLoadingWheel()
                }
            }
        }
    }

    // Dismiss autocomplete when user scrolls the chat
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === chatTableView else { return }
        hideAutocomplete()
    }
}

// MARK: - UITextViewDelegate (autocomplete)
extension TaskChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard textView == chatInputTextView else { return }
        let text = textView.text ?? ""
        let cursor = textView.selectedRange

        applyMentionColoring(to: textView, preservingCursor: cursor)

        let cursorPos = cursor.location
        guard cursorPos <= (text as NSString).length else { hideAutocomplete(); return }
        let upToCursor = (text as NSString).substring(to: cursorPos)
        if let atRange = upToCursor.range(of: "@", options: .backwards),
           (atRange.lowerBound == upToCursor.startIndex ||
            upToCursor[upToCursor.index(before: atRange.lowerBound)].isWhitespace) {
            let query = String(upToCursor[atRange.upperBound...])
            if query.contains(" ") || query.contains("\n") {
                hideAutocomplete()
                return
            }
            let atNSIdx = upToCursor.distance(from: upToCursor.startIndex, to: atRange.lowerBound)
            atTriggerNSRange = NSRange(location: atNSIdx, length: cursorPos - atNSIdx)
            filteredWorkspaces = availableWorkspaces.filter {
                query.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.slug ?? "").localizedCaseInsensitiveContains(query)
            }
            showAutocomplete()
        } else {
            hideAutocomplete()
        }

        updateInputBarHeight()
    }

    private static let mentionRegex = try? NSRegularExpression(pattern: "@\\S+")

    /// Recolors the text view: `@word` (@ + non-whitespace) = blue, all else = default text color.
    private func applyMentionColoring(to textView: UITextView, preservingCursor cursor: NSRange) {
        let text = textView.text ?? ""
        let defaultFont = UIFont(name: "Roboto-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [.foregroundColor: UIColor.Sphinx.Text, .font: defaultFont]
        )
        if let regex = TaskChatViewController.mentionRegex {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                attr.addAttribute(.foregroundColor, value: UIColor.Sphinx.PrimaryBlue, range: match.range)
            }
        }
        textView.attributedText = attr
        textView.selectedRange = cursor
        textView.typingAttributes = [.foregroundColor: UIColor.Sphinx.Text, .font: defaultFont]
    }

    private func showAutocomplete() {
        guard !filteredWorkspaces.isEmpty else { hideAutocomplete(); return }

        autocompleteStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, ws) in filteredWorkspaces.enumerated() {
            let row = UIView()
            row.backgroundColor = UIColor.Sphinx.HeaderBG

            let nameLabel = UILabel()
            nameLabel.text = ws.name
            nameLabel.textColor = UIColor.Sphinx.Text
            nameLabel.font = UIFont(name: "Roboto-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)

            let slugLabel = UILabel()
            slugLabel.text = ws.slug
            slugLabel.textColor = UIColor.Sphinx.SecondaryText
            slugLabel.font = UIFont(name: "Roboto-Regular", size: 12) ?? .systemFont(ofSize: 12)

            let labelStack = UIStackView(arrangedSubviews: [nameLabel, slugLabel])
            labelStack.axis = .vertical
            labelStack.spacing = 2
            labelStack.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(labelStack)
            NSLayoutConstraint.activate([
                labelStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
                labelStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
                labelStack.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])

            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.backgroundColor = .clear
            btn.tag = i
            btn.addTarget(self, action: #selector(autocompleteRowTapped(_:)), for: .touchUpInside)
            row.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: row.topAnchor),
                btn.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                btn.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                btn.bottomAnchor.constraint(equalTo: row.bottomAnchor)
            ])

            row.heightAnchor.constraint(equalToConstant: 52).isActive = true
            autocompleteStack.addArrangedSubview(row)

            if i < filteredWorkspaces.count - 1 {
                let divider = UIView()
                divider.backgroundColor = UIColor.Sphinx.LightDivider
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                autocompleteStack.addArrangedSubview(divider)
            }
        }

        let maxRows = min(filteredWorkspaces.count, 4)
        let dividerCount = max(0, maxRows - 1)
        let visibleHeight = CGFloat(maxRows) * 52 + CGFloat(dividerCount)
        autocompleteHeightConstraint.constant = visibleHeight
        autocompleteContainer.isHidden = false
        view.layoutIfNeeded()
    }

    @objc private func autocompleteRowTapped(_ sender: UIButton) {
        guard sender.tag < filteredWorkspaces.count,
              let triggerRange = atTriggerNSRange,
              let currentText = chatInputTextView.text else { hideAutocomplete(); return }
        let ws = filteredWorkspaces[sender.tag]
        let slug = ws.slug ?? ws.name
        let insertText = "@\(slug) "
        let nsText = currentText as NSString
        let safeLength = min(triggerRange.length, nsText.length - triggerRange.location)
        guard triggerRange.location >= 0, triggerRange.location + safeLength <= nsText.length else {
            hideAutocomplete(); return
        }
        let newText = nsText.replacingCharacters(in: NSRange(location: triggerRange.location, length: safeLength), with: insertText)
        let newCursor = NSRange(location: triggerRange.location + insertText.count, length: 0)
        let defaultFont = UIFont(name: "Roboto-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        let attr = NSMutableAttributedString(string: newText, attributes: [.foregroundColor: UIColor.Sphinx.Text, .font: defaultFont])
        if let regex = TaskChatViewController.mentionRegex {
            let matches = regex.matches(in: newText, range: NSRange(newText.startIndex..., in: newText))
            for match in matches {
                attr.addAttribute(.foregroundColor, value: UIColor.Sphinx.PrimaryBlue, range: match.range)
            }
        }
        chatInputTextView.attributedText = attr
        chatInputTextView.selectedRange = newCursor
        chatInputTextView.typingAttributes = [.foregroundColor: UIColor.Sphinx.Text, .font: defaultFont]
        hideAutocomplete()
        chatInputTextView.becomeFirstResponder()
    }

    private func hideAutocomplete() {
        autocompleteContainer.isHidden = true
        autocompleteHeightConstraint.constant = 0
        atTriggerNSRange = nil
    }
}

// MARK: - PHPickerViewControllerDelegate
extension TaskChatViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        guard !results.isEmpty else { return }

        let allowedMimes: Set<String> = ["image/jpeg", "image/png", "image/gif", "image/webp"]
        let maxBytes = 10 * 1024 * 1024 // 10 MB

        for result in results {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let self = self, let image = object as? UIImage else { return }

                let mimeType = "image/jpeg"
                guard let data = image.jpegData(compressionQuality: 0.85) else { return }
                let filename = "image_\(UUID().uuidString).jpg"
                let size = data.count

                guard allowedMimes.contains(mimeType), size <= maxBytes else {
                    DispatchQueue.main.async {
                        AlertHelper.showAlert(
                            title: "Invalid file",
                            message: size > maxBytes ? "File exceeds 10 MB limit." : "Unsupported file type.",
                            on: self
                        )
                    }
                    return
                }

                let pending = PendingAttachment(
                    id: UUID(),
                    image: image,
                    filename: filename,
                    mimeType: mimeType,
                    size: size,
                    state: .uploading,
                    s3Path: nil
                )
                DispatchQueue.main.async {
                    self.pendingAttachments.append(pending)
                    self.refreshAttachmentsBar()
                    self.updateSendButtonState()
                }

                API.sharedInstance.requestUploadPresignedUrlWithAuth(
                    taskId: self.task.id,
                    filename: filename,
                    contentType: mimeType,
                    size: size,
                    callback: { [weak self] presignedUrl, s3Path in
                        guard let self = self,
                              let presignedUrl = presignedUrl,
                              let s3Path = s3Path else {
                            self?.markPending(id: pending.id, state: .failed)
                            return
                        }
                        API.sharedInstance.uploadFileToS3(
                            presignedUrl: presignedUrl,
                            data: data,
                            contentType: mimeType,
                            callback: { [weak self] in
                                self?.markPending(id: pending.id, state: .done, s3Path: s3Path)
                            },
                            errorCallback: { [weak self] in
                                self?.markPending(id: pending.id, state: .failed)
                            }
                        )
                    },
                    errorCallback: { [weak self] in
                        self?.markPending(id: pending.id, state: .failed)
                    }
                )
            }
        }
    }

    private func markPending(id: UUID, state: PendingAttachmentState, s3Path: String? = nil) {
        DispatchQueue.main.async {
            guard let idx = self.pendingAttachments.firstIndex(where: { $0.id == id }) else { return }
            self.pendingAttachments[idx].state = state
            if let s3Path = s3Path { self.pendingAttachments[idx].s3Path = s3Path }
            self.refreshAttachmentsBar()
            self.updateSendButtonState()
        }
    }
}
