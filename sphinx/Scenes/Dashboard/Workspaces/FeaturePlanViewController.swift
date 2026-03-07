//
//  FeaturePlanViewController.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class FeaturePlanViewController: UIViewController {
    
    // MARK: - Properties
    private var feature: HiveFeature
    private var workspace: Workspace
    private var messages: [HiveChatMessage] = []
    private var processingStepText: String? = nil
    private var cachedStakworkProjectId: Int?
    private var isAIWorking: Bool = false {
        didSet {
            updateAIWorkingState()
        }
    }
    private var isGeneratingTasks: Bool = false
    private var lastGenerationFailed: Bool = false
    
    // MARK: - UI Components
    private var headerView: UIView!
    private var backButton: UIButton!
    private var titleLabel: UILabel!
    private var shareButton: UIButton!
    
    private var topSegmentedControl: CustomSegmentedControl!
    private var chatContainerView: UIView!
    private var planContainerView: UIView!
    private var tasksContainerView: UIView!
    private var tasksTableView: UITableView!
    private lazy var tasksRefreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = .Sphinx.Text
        return control
    }()
    
    // Chat Panel Components
    private var chatTableView: UITableView!
    private var chatInputContainer: UIView!
    private var chatInputTextView: UITextView!
    private var sendButton: UIButton!
    private var chatInputContainerBottomConstraint: NSLayoutConstraint!
    private var workflowStatusView: WorkflowStatusView!
    private var workflowStatusHeightConstraint: NSLayoutConstraint!
    private var bottomFillView: UIView!
    private var tasksEmptyLabel: UILabel!
    private var taskProgressBarView: TaskProgressBarView!
    private var startTasksButton: UIButton!

    // Plan Panel Components
    private var planSegmentedControl: CustomSegmentedControl!
    private var planTextView: UITextView!
    private var generateTasksButton: UIButton!
    private var retryButton: UIButton!
    /// Switches between pinning planTextView bottom to the button (button visible)
    /// or to the container bottom (button hidden).
    private var planTextViewBottomToButton: NSLayoutConstraint!
    private var planTextViewBottomToRetry: NSLayoutConstraint!
    private var planTextViewBottomToContainer: NSLayoutConstraint!
    private lazy var markdownRenderer: MarkdownRenderer = {
        var style = MarkdownStyle()
        style.baseFontSize = 15
        return MarkdownRenderer(style: style)
    }()
    
    // MARK: - Initialization
    static func instantiate(feature: HiveFeature, workspace: Workspace) -> FeaturePlanViewController {
        return FeaturePlanViewController(feature: feature, workspace: workspace)
    }
    
    private init(feature: HiveFeature, workspace: Workspace) {
        self.feature = feature
        self.workspace = workspace
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
        cachedStakworkProjectId = feature.stakworkProjectId
        fetchFeatureDetail()
        checkForActiveTaskGeneration()
        fetchChatHistory()
        connectWebSocket()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !HivePusherManager.shared.isConnected else { return }
        connectWebSocket()
        fetchFeatureDetail()
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
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = UIColor.Sphinx.Body
        
        setupHeader()
        setupTopSegmentedControl()
        setupChatPanel()
        setupPlanPanel()
        setupTasksPanel()
        
        // Initially show chat panel
        showPanel(at: 0)
        // Set initial generate button visibility
        updateGenerateTasksButton()
    }
    
    private func setupHeader() {
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor.Sphinx.Body
        view.addSubview(headerView)

        // Back button — matches WorkspaceViewController storyboard style:
        // UIButton(.custom) so setTitleColor is respected, MaterialIcons-Regular 21pt
        // U+E5C4 = arrow_back in Material Icons font
        backButton = UIButton(type: .custom)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.titleLabel?.font = UIFont(name: "MaterialIcons-Regular", size: 21)
        backButton.setTitle("\u{E5C4}", for: .normal)
        backButton.setTitleColor(UIColor.Sphinx.WashedOutReceivedText, for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTouched), for: .touchUpInside)
        headerView.addSubview(backButton)

        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = feature.name
        titleLabel.font = UIFont(name: "Roboto-Medium", size: 14)
        titleLabel.textColor = UIColor.Sphinx.Text
        titleLabel.textAlignment = .center
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

            shareButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            shareButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 50),
            shareButton.heightAnchor.constraint(equalToConstant: 50),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: shareButton.leadingAnchor, constant: -8)
        ])
    }
    
    private func setupTopSegmentedControl() {
        topSegmentedControl = CustomSegmentedControl(frame: .zero, buttonTitles: ["CHAT", "PLAN", "TASKS"])
        topSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        // Set colors BEFORE configure so configureSelectorView picks up the right color
        topSegmentedControl.buttonBackgroundColor = UIColor.Sphinx.HeaderBG
        topSegmentedControl.backgroundColor = UIColor.Sphinx.HeaderBG
        topSegmentedControl.selectorViewColor = UIColor.Sphinx.PrimaryGreen
        topSegmentedControl.configureFromOutlet(
            buttonTitles: ["CHAT", "PLAN", "TASKS"],
            initialIndex: 0,
            delegate: self
        )
        view.addSubview(topSegmentedControl)
        
        NSLayoutConstraint.activate([
            topSegmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            topSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topSegmentedControl.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupChatPanel() {
        chatContainerView = UIView()
        chatContainerView.translatesAutoresizingMaskIntoConstraints = false
        chatContainerView.backgroundColor = UIColor.Sphinx.Body
        view.addSubview(chatContainerView)
        
        // Chat Table View
        chatTableView = UITableView()
        chatTableView.translatesAutoresizingMaskIntoConstraints = false
        chatTableView.backgroundColor = .clear
        chatTableView.separatorStyle = .none
        chatTableView.delegate = self
        chatTableView.dataSource = self
        chatTableView.register(FeatureChatMessageCell.self, forCellReuseIdentifier: "FeatureChatMessageCell")
        chatTableView.register(HiveProcessingBubbleCell.self, forCellReuseIdentifier: "HiveProcessingBubbleCell")
        chatTableView.rowHeight = UITableView.automaticDimension
        chatTableView.estimatedRowHeight = 200
        chatTableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        chatContainerView.addSubview(chatTableView)
        
        // Bottom Fill View — covers the gap between chatInputContainer and the physical screen bottom
        bottomFillView = UIView()
        bottomFillView.translatesAutoresizingMaskIntoConstraints = false
        bottomFillView.backgroundColor = UIColor.Sphinx.HeaderBG
        chatContainerView.addSubview(bottomFillView)

        // Chat Input Container
        chatInputContainer = UIView()
        chatInputContainer.translatesAutoresizingMaskIntoConstraints = false
        chatInputContainer.backgroundColor = UIColor.Sphinx.HeaderBG
        chatContainerView.addSubview(chatInputContainer)
        
        // Chat Input Text View
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
        
        // Send Button
        sendButton = UIButton()
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("➤", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        sendButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        sendButton.layer.cornerRadius = 20
        sendButton.addTarget(self, action: #selector(sendButtonTouched), for: .touchUpInside)
        chatInputContainer.addSubview(sendButton)
        
        // Workflow Status View
        workflowStatusView = WorkflowStatusView()
        workflowStatusView.translatesAutoresizingMaskIntoConstraints = false
        chatContainerView.addSubview(workflowStatusView)

        workflowStatusView.onRetryTapped = { [weak self] in
            guard let self else { return }
            guard let lastUserMsg = self.messages.last(where: { $0.isUserMessage }) else { return }
            self.sendChatMessage(lastUserMsg.message)
        }

        chatTableView.keyboardDismissMode = .interactive

        chatInputContainerBottomConstraint = chatInputContainer.bottomAnchor.constraint(equalTo: chatContainerView.safeAreaLayoutGuide.bottomAnchor)
        workflowStatusHeightConstraint = workflowStatusView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            chatContainerView.topAnchor.constraint(equalTo: topSegmentedControl.bottomAnchor),
            chatContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            chatTableView.topAnchor.constraint(equalTo: chatContainerView.topAnchor),
            chatTableView.leadingAnchor.constraint(equalTo: chatContainerView.leadingAnchor),
            chatTableView.trailingAnchor.constraint(equalTo: chatContainerView.trailingAnchor),
            chatTableView.bottomAnchor.constraint(equalTo: workflowStatusView.topAnchor),

            workflowStatusView.leadingAnchor.constraint(equalTo: chatContainerView.leadingAnchor),
            workflowStatusView.trailingAnchor.constraint(equalTo: chatContainerView.trailingAnchor),
            workflowStatusView.bottomAnchor.constraint(equalTo: chatInputContainer.topAnchor),
            workflowStatusHeightConstraint,
            
            chatInputContainer.leadingAnchor.constraint(equalTo: chatContainerView.leadingAnchor),
            chatInputContainer.trailingAnchor.constraint(equalTo: chatContainerView.trailingAnchor),
            chatInputContainerBottomConstraint,
            chatInputContainer.heightAnchor.constraint(equalToConstant: 80),

            bottomFillView.topAnchor.constraint(equalTo: chatInputContainer.bottomAnchor),
            bottomFillView.leadingAnchor.constraint(equalTo: chatContainerView.leadingAnchor),
            bottomFillView.trailingAnchor.constraint(equalTo: chatContainerView.trailingAnchor),
            bottomFillView.bottomAnchor.constraint(equalTo: chatContainerView.bottomAnchor),
            
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
    
    private func setupPlanPanel() {
        planContainerView = UIView()
        planContainerView.translatesAutoresizingMaskIntoConstraints = false
        planContainerView.backgroundColor = UIColor.Sphinx.Body
        planContainerView.isHidden = true
        view.addSubview(planContainerView)
        
        // Plan Segmented Control — SF Symbol icons
        planSegmentedControl = CustomSegmentedControl(
            frame: .zero,
            buttonTitles: ["Brief", "User Stories", "Requirements", "Architecture"]
        )
        planSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        // Set colors BEFORE configure so configureSelectorView picks up the right color
        planSegmentedControl.buttonBackgroundColor = UIColor.Sphinx.HeaderBG
        planSegmentedControl.backgroundColor = UIColor.Sphinx.HeaderBG
        planSegmentedControl.configureWithSymbols(
            symbolNames: ["doc.plaintext", "person.2", "checklist", "cpu"],
            placeholderTitles: ["Brief", "User Stories", "Requirements", "Architecture"],
            initialIndex: 0,
            delegate: self
        )
        planContainerView.addSubview(planSegmentedControl)
        
        // Plan Text View — displays rendered markdown
        planTextView = UITextView()
        planTextView.translatesAutoresizingMaskIntoConstraints = false
        planTextView.backgroundColor = UIColor.Sphinx.Body
        planTextView.isEditable = false
        planTextView.isSelectable = true
        planTextView.dataDetectorTypes = [.link]
        planTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        planTextView.linkTextAttributes = [
            .foregroundColor: UIColor.Sphinx.PrimaryBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        planContainerView.addSubview(planTextView)
        
        // Generate Tasks Button
        generateTasksButton = UIButton()
        generateTasksButton.translatesAutoresizingMaskIntoConstraints = false
        generateTasksButton.setTitle("GENERATE TASKS", for: .normal)
        generateTasksButton.setTitle("GENERATING TASKS…", for: .disabled)
        generateTasksButton.setTitleColor(.white, for: .normal)
        generateTasksButton.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .disabled)
        generateTasksButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 16)
        generateTasksButton.backgroundColor = UIColor.Sphinx.PrimaryGreen
        generateTasksButton.layer.cornerRadius = 25
        generateTasksButton.addTarget(self, action: #selector(generateTasksButtonTouched), for: .touchUpInside)
        planContainerView.addSubview(generateTasksButton)

        // Retry Button
        retryButton = UIButton()
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("RETRY", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 16)
        retryButton.backgroundColor = UIColor.Sphinx.SphinxOrange
        retryButton.layer.cornerRadius = 25
        retryButton.addTarget(self, action: #selector(retryButtonTouched), for: .touchUpInside)
        retryButton.isHidden = true
        planContainerView.addSubview(retryButton)

        planTextViewBottomToButton = planTextView.bottomAnchor.constraint(
            equalTo: generateTasksButton.topAnchor, constant: -16
        )
        planTextViewBottomToRetry = planTextView.bottomAnchor.constraint(
            equalTo: retryButton.topAnchor, constant: -16
        )
        planTextViewBottomToContainer = planTextView.bottomAnchor.constraint(
            equalTo: planContainerView.safeAreaLayoutGuide.bottomAnchor
        )

        NSLayoutConstraint.activate([
            planContainerView.topAnchor.constraint(equalTo: topSegmentedControl.bottomAnchor),
            planContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            planContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            planContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            planSegmentedControl.topAnchor.constraint(equalTo: planContainerView.topAnchor),
            planSegmentedControl.leadingAnchor.constraint(equalTo: planContainerView.leadingAnchor),
            planSegmentedControl.trailingAnchor.constraint(equalTo: planContainerView.trailingAnchor),
            planSegmentedControl.heightAnchor.constraint(equalToConstant: 44),

            planTextView.topAnchor.constraint(equalTo: planSegmentedControl.bottomAnchor),
            planTextView.leadingAnchor.constraint(equalTo: planContainerView.leadingAnchor),
            planTextView.trailingAnchor.constraint(equalTo: planContainerView.trailingAnchor),

            generateTasksButton.leadingAnchor.constraint(equalTo: planContainerView.leadingAnchor, constant: 32),
            generateTasksButton.trailingAnchor.constraint(equalTo: planContainerView.trailingAnchor, constant: -32),
            generateTasksButton.bottomAnchor.constraint(equalTo: planContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            generateTasksButton.heightAnchor.constraint(equalToConstant: 50),

            retryButton.leadingAnchor.constraint(equalTo: planContainerView.leadingAnchor, constant: 32),
            retryButton.trailingAnchor.constraint(equalTo: planContainerView.trailingAnchor, constant: -32),
            retryButton.bottomAnchor.constraint(equalTo: planContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            retryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        updatePlanText()
    }
    
    // MARK: - Keyboard Handling
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
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        chatInputContainerBottomConstraint.constant = -(keyboardHeight - view.safeAreaInsets.bottom)
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        
        scrollToBottom()
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        chatInputContainerBottomConstraint.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Actions
    @objc private func shareTappedAction() {
        let url = "https://hive.sphinx.chat/w/\(workspace.slug ?? "")/plan/\(feature.id)"
        let label = "Check out this feature: \(feature.title) — \(url)"
        let shareVC = HiveShareViewController.instantiate(url: url, label: label)
        present(shareVC, animated: true)
    }

    @objc private func backButtonTouched() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func sendButtonTouched() {
        guard let message = chatInputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return
        }
        chatInputTextView.resignFirstResponder()
        sendChatMessage(message)
    }
    
    @objc private func generateTasksButtonTouched() {
        triggerGeneration(includeHistory: false)
    }

    @objc private func retryButtonTouched() {
        triggerGeneration(includeHistory: true)
    }

    private func triggerGeneration(includeHistory: Bool) {
        isGeneratingTasks = true
        lastGenerationFailed = false
        applyGenerationState()

        API.sharedInstance.triggerTaskGenerationWithAuth(
            workspaceId: workspace.id,
            featureId: feature.id,
            includeHistory: includeHistory,
            callback: { [weak self] run in
                DispatchQueue.main.async {
                    print("[FeaturePlanVC] Task generation run started: \(run?.id ?? "unknown")")
                    // No alert, no re-fetch — Pusher drives completion
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.isGeneratingTasks = false
                    self?.applyGenerationState()
                    self?.showGenerateTasksError()
                }
            }
        )
    }
    
    // MARK: - Tasks Panel Setup
    private func setupTasksPanel() {
        tasksContainerView = UIView()
        tasksContainerView.translatesAutoresizingMaskIntoConstraints = false
        tasksContainerView.backgroundColor = UIColor.Sphinx.Body
        tasksContainerView.isHidden = true
        view.addSubview(tasksContainerView)

        // Progress bar
        taskProgressBarView = TaskProgressBarView()
        taskProgressBarView.isHidden = true
        tasksContainerView.addSubview(taskProgressBarView)

        tasksTableView = UITableView()
        tasksTableView.translatesAutoresizingMaskIntoConstraints = false
        tasksTableView.backgroundColor = UIColor.Sphinx.Body
        tasksTableView.separatorStyle = .none
        tasksTableView.rowHeight = 110
        tasksTableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
        tasksTableView.register(
            WorkspaceTaskTableViewCell.nib,
            forCellReuseIdentifier: WorkspaceTaskTableViewCell.reuseID
        )
        // Delegate/dataSource wired in extension below
        tasksTableView.delegate = self
        tasksTableView.dataSource = self
        tasksRefreshControl.addTarget(self, action: #selector(handleTasksRefresh), for: .valueChanged)
        tasksTableView.refreshControl = tasksRefreshControl
        tasksContainerView.addSubview(tasksTableView)

        // Empty state label
        tasksEmptyLabel = UILabel()
        tasksEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        tasksEmptyLabel.text = "No tasks found"
        tasksEmptyLabel.textColor = UIColor.Sphinx.SecondaryText
        tasksEmptyLabel.font = UIFont(name: "Roboto-Regular", size: 15)
        tasksEmptyLabel.textAlignment = .center
        tasksEmptyLabel.isHidden = true
        tasksContainerView.addSubview(tasksEmptyLabel)

        // Start Tasks button
        startTasksButton = UIButton()
        startTasksButton.translatesAutoresizingMaskIntoConstraints = false
        startTasksButton.setTitleColor(.white, for: .normal)
        startTasksButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 16)
        startTasksButton.backgroundColor = UIColor.Sphinx.PrimaryGreen
        startTasksButton.layer.cornerRadius = 25
        startTasksButton.isHidden = true
        startTasksButton.addTarget(self, action: #selector(startTasksButtonTouched), for: .touchUpInside)
        tasksContainerView.addSubview(startTasksButton)

        NSLayoutConstraint.activate([
            tasksContainerView.topAnchor.constraint(equalTo: topSegmentedControl.bottomAnchor),
            tasksContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tasksContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tasksContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Progress bar — pinned to top with 8pt horizontal padding
            taskProgressBarView.topAnchor.constraint(equalTo: tasksContainerView.topAnchor, constant: 16),
            taskProgressBarView.leadingAnchor.constraint(equalTo: tasksContainerView.leadingAnchor, constant: 16),
            taskProgressBarView.trailingAnchor.constraint(equalTo: tasksContainerView.trailingAnchor, constant: -16),
            taskProgressBarView.heightAnchor.constraint(equalToConstant: 36),

            // Table view below progress bar, above start tasks button
            tasksTableView.topAnchor.constraint(equalTo: taskProgressBarView.bottomAnchor),
            tasksTableView.leadingAnchor.constraint(equalTo: tasksContainerView.leadingAnchor),
            tasksTableView.trailingAnchor.constraint(equalTo: tasksContainerView.trailingAnchor),
            tasksTableView.bottomAnchor.constraint(equalTo: startTasksButton.topAnchor, constant: -8),

            // Start Tasks button pinned to bottom
            startTasksButton.leadingAnchor.constraint(equalTo: tasksContainerView.leadingAnchor, constant: 32),
            startTasksButton.trailingAnchor.constraint(equalTo: tasksContainerView.trailingAnchor, constant: -32),
            startTasksButton.bottomAnchor.constraint(equalTo: tasksContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            startTasksButton.heightAnchor.constraint(equalToConstant: 50),

            tasksEmptyLabel.centerXAnchor.constraint(equalTo: tasksContainerView.centerXAnchor),
            tasksEmptyLabel.centerYAnchor.constraint(equalTo: tasksContainerView.centerYAnchor)
        ])
    }

    private func updateTasksEmptyState() {
        tasksEmptyLabel.isHidden = !feature.allTasks.isEmpty
    }

    private func updateProgressBar() {
        let progress = TaskProgress(tasks: feature.allTasks)
        taskProgressBarView.configure(with: progress)
        taskProgressBarView.isHidden = feature.allTasks.isEmpty
    }

    private func updateStartTasksButton() {
        let startable = feature.allTasks.filter { $0.assigneeId == nil && $0.status == "TODO" }
        startTasksButton.isHidden = startable.isEmpty
        let n = startable.count
        startTasksButton.setTitle("Start \(n) task\(n == 1 ? "" : "s")", for: .normal)
    }

    private func updateTasksPanel() {
        tasksTableView.reloadData()
        updateProgressBar()
        updateStartTasksButton()
        updateTasksEmptyState()
    }

    @objc private func handleTasksRefresh() {
        fetchFeatureDetail()
    }

    @objc private func startTasksButtonTouched() {
        startTasksButton.isHidden = true
        API.sharedInstance.assignAllFeatureTasksWithAuth(
            featureId: feature.id,
            callback: { /* stay hidden — Pusher will refresh */ },
            errorCallback: { [weak self] in
                DispatchQueue.main.async { self?.startTasksButton.isHidden = false }
            }
        )
    }

    // MARK: - Panel Management
    private func showPanel(at index: Int) {
        view.endEditing(true) // dismiss keyboard whenever tab changes
        chatContainerView.isHidden  = (index != 0)
        planContainerView.isHidden  = (index != 1)
        tasksContainerView.isHidden = (index != 2)
        if index == 1 {
            topSegmentedControl.indicesOfTitlesWithBadge = []
            updatePlanText()
        }
        if index == 2 {
            topSegmentedControl.indicesOfTitlesWithBadge = []
            updateTasksPanel()
        }
    }

    private func updateGenerateTasksButton() {
        applyGenerationState()
    }

    private func applyGenerationState() {
        let hasTasks = feature.hasTasks

        planTextViewBottomToButton.isActive = false
        planTextViewBottomToRetry.isActive = false
        planTextViewBottomToContainer.isActive = false

        if hasTasks {
            generateTasksButton.isHidden = true
            retryButton.isHidden = true
            planTextViewBottomToContainer.isActive = true
        } else if isGeneratingTasks {
            generateTasksButton.isHidden = false
            generateTasksButton.isEnabled = false
            generateTasksButton.alpha = 0.5
            retryButton.isHidden = true
            planTextViewBottomToButton.isActive = true
        } else if lastGenerationFailed {
            generateTasksButton.isHidden = true
            retryButton.isHidden = false
            planTextViewBottomToRetry.isActive = true
        } else {
            let hasArchitecture = !(feature.architecture ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            generateTasksButton.isHidden = !hasArchitecture
            generateTasksButton.isEnabled = hasArchitecture
            generateTasksButton.alpha = 1.0
            retryButton.isHidden = true
            planTextViewBottomToButton.isActive = hasArchitecture
            planTextViewBottomToContainer.isActive = !hasArchitecture
        }
    }
    
    private func updatePlanText() {
        let selectedIndex = planSegmentedControl.selectedIndex
        let raw: String

        switch selectedIndex {
        case 0: // BRIEF
            raw = feature.brief ?? "*No brief available yet.*"
        case 1: // USER STORIES
            if let stories = feature.userStories, !stories.isEmpty {
                raw = stories.enumerated().map { "- [ ] \($0.element)" }.joined(separator: "\n")
            } else {
                raw = "*No user stories available yet.*"
            }
        case 2: // REQUIREMENTS
            raw = feature.requirements ?? "*No requirements available yet.*"
        case 3: // ARCHITECTURE
            raw = feature.architecture ?? "*No architecture available yet.*"
        default:
            raw = ""
        }

        planTextView.attributedText = markdownRenderer.render(raw)
    }
    
    private func updateAIWorkingState() {
        sendButton.isEnabled = !isAIWorking
        sendButton.alpha = isAIWorking ? 0.5 : 1.0
        chatInputTextView.isEditable = !isAIWorking
    }

    private func applyInitialWorkflowStatus() {
        guard let raw = feature.workflowStatus,
              let status = WorkflowStatus(rawValue: raw),
              status == .IN_PROGRESS || status == .PENDING || status == .HALTED else { return }
        applyWorkflowStatus(status)
    }

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
        isAIWorking = (status == .IN_PROGRESS)
    }
    
    // MARK: - API Methods
    private func fetchFeatureDetail() {
        API.sharedInstance.fetchFeatureDetailWithAuth(
            featureId: feature.id,
            callback: { [weak self] updatedFeature in
                guard let self = self, let updatedFeature = updatedFeature else { return }
                DispatchQueue.main.async {
                    self.feature = updatedFeature
                    self.cachedStakworkProjectId = updatedFeature.stakworkProjectId
                    HivePusherManager.shared.subscribeToFeatureTasks(updatedFeature.allTasks.map { $0.id })
                    // Apply workflow status from freshly fetched feature data
                    self.applyInitialWorkflowStatus()
                    // Refresh plan panel if currently visible
                    if !self.planContainerView.isHidden {
                        self.updatePlanText()
                    }
                    // Refresh tasks panel if currently visible
                    if !self.tasksContainerView.isHidden {
                        self.updateTasksPanel()
                    }
                    // Show/hide generate button based on whether tasks exist
                    self.updateGenerateTasksButton()
                    // If fetched as fallback for workflow step, update bubble text
                    if let projectId = updatedFeature.stakworkProjectId {
                        self.fetchStepText(projectId: projectId)
                    }
                    self.tasksRefreshControl.endRefreshing()
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.tasksRefreshControl.endRefreshing()
                }
                print("[FeaturePlanVC] Failed to fetch feature detail")
            }
        )
    }

    private func checkForActiveTaskGeneration() {
        API.sharedInstance.fetchTaskGenerationRunsWithAuth(
            workspaceId: workspace.id,
            featureId: feature.id,
            callback: { [weak self] runs in
                DispatchQueue.main.async {
                    let isActive = runs.contains {
                        $0.status == "PENDING" || $0.status == "IN_PROGRESS"
                    }
                    if isActive {
                        self?.isGeneratingTasks = true
                        self?.applyGenerationState()
                    }
                }
            },
            errorCallback: { /* silent — non-critical on load */ }
        )
    }

    private func fetchChatHistory() {
        API.sharedInstance.fetchFeatureChatWithAuth(
            featureId: feature.id,
            callback: { [weak self] messages in
                DispatchQueue.main.async {
                    self?.messages = messages.filter {
                        !$0.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.artifacts.isEmpty
                    }
                    self?.chatTableView.reloadData()
                    self?.scrollToBottom()
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.showChatHistoryError()
                }
            }
        )
    }
    
    private func sendChatMessage(_ message: String) {
        chatInputTextView.text = ""
        isAIWorking = true
        showProcessingBubble()

        API.sharedInstance.sendFeatureChatMessageWithAuth(
            featureId: feature.id,
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
                    self?.isAIWorking = false
                    self?.showSendMessageError()
                }
            }
        )
    }

    private func sendClarifyingAnswers(answers: [String], replyId: String) {
        showProcessingBubble()
        let joined = answers.joined(separator: "\n\n")
        API.sharedInstance.sendFeatureChatMessageWithAuth(
            featureId: feature.id,
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
    
    // MARK: - WebSocket
    private func connectWebSocket() {
        HivePusherManager.shared.delegate = self
        HivePusherManager.shared.connect(featureId: feature.id, workspaceId: workspace.id, workspaceSlug: workspace.slug ?? "")
    }
    
    // MARK: - Processing Bubble
    private func showProcessingBubble() {
        guard processingStepText == nil else { return }
        processingStepText = "Communicating with Workflow"
        let indexPath = IndexPath(row: messages.count, section: 0)
        chatTableView.insertRows(at: [indexPath], with: .automatic)
        scrollToBottom()
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

    // MARK: - Helper Methods
    private func scrollToBottom() {
        let totalRows = messages.count + (processingStepText != nil ? 1 : 0)
        guard totalRows > 0 else { return }
        let lastIndexPath = IndexPath(row: totalRows - 1, section: 0)
        chatTableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: true)
    }
    
    private func showChatHistoryError() {
        AlertHelper.showAlert(
            title: "generic.error.title".localized,
            message: "Failed to load chat history",
            on: self
        )
    }
    
    private func showSendMessageError() {
        AlertHelper.showAlert(
            title: "generic.error.title".localized,
            message: "Failed to send message",
            on: self
        )
    }
    
    private func showGenerateTasksSuccess() {
        AlertHelper.showAlert(
            title: "Success",
            message: "Tasks generated successfully",
            on: self
        )
    }
    
    private func showGenerateTasksError() {
        AlertHelper.showAlert(
            title: "generic.error.title".localized,
            message: "Failed to generate tasks",
            on: self
        )
    }
}

// MARK: - CustomSegmentedControlDelegate
extension FeaturePlanViewController: CustomSegmentedControlDelegate {
    func segmentedControlDidSwitch(_ control: CustomSegmentedControl, to index: Int) {
        if control === topSegmentedControl {
            showPanel(at: index)
        } else if control === planSegmentedControl {
            updatePlanText()
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension FeaturePlanViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === tasksTableView {
            return feature.allTasks.count
        }
        return messages.count + (processingStepText != nil ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === tasksTableView {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: WorkspaceTaskTableViewCell.reuseID,
                for: indexPath
            ) as? WorkspaceTaskTableViewCell else {
                return UITableViewCell()
            }
            let tasks = feature.allTasks
            let task = tasks[indexPath.row]
            let isLast = indexPath.row == tasks.count - 1
            cell.configure(with: task, isLastRow: isLast)
            cell.onPRBadgeTapped = { url in UIApplication.shared.open(url) }
            cell.onRetryWorkflowTapped = { [weak self] in
                guard let self else { return }
                let t = self.feature.allTasks[indexPath.row]
                API.sharedInstance.retryTaskWorkflowWithAuth(taskId: t.id, callback: {}, errorCallback: {})
            }
            return cell
        }

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
        ) as? FeatureChatMessageCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        cell.configure(with: message)
        cell.onClarifyingAnswerSubmit = { [weak self] answers, replyId in
            self?.sendClarifyingAnswers(answers: answers, replyId: replyId)
        }
        cell.onHeightChanged = { [weak tableView] in
            tableView?.beginUpdates()
            tableView?.endUpdates()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard tableView === tasksTableView else { return }
        let task = feature.allTasks[indexPath.row]
        let chatVC = TaskChatViewController.instantiate(task: task, workspaceSlug: workspace.slug ?? "")
        navigationController?.pushViewController(chatVC, animated: true)
    }
}

// MARK: - HivePusherDelegate
extension FeaturePlanViewController: HivePusherDelegate {
    func featureUpdateReceived(featureId: String) {
        fetchFeatureDetail()
        updateTasksPanel()
        
        if planContainerView.isHidden {
            topSegmentedControl.indicesOfTitlesWithBadge = [1]
        }
    }
    
    func newMessageReceived(_ message: HiveChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        hideProcessingBubble()
        messages.append(message)
        
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        chatTableView.insertRows(at: [indexPath], with: .automatic)
        scrollToBottom()
    }
    
    func workflowStatusChanged(status: WorkflowStatus) {
        DispatchQueue.main.async {
            self.applyWorkflowStatus(status)
            self.fetchFeatureDetail()
//            if status == .IN_PROGRESS || status == .PENDING {
//                self.showProcessingBubble()
//                self.fetchAndUpdateWorkflowStep()
//            }
        }
    }

    private func fetchAndUpdateWorkflowStep() {
        if let projectId = cachedStakworkProjectId {
            fetchStepText(projectId: projectId)
        } else {
            // fetchFeatureDetail callback sets cachedStakworkProjectId then calls fetchStepText
            fetchFeatureDetail()
        }
    }

    private func fetchStepText(projectId: Int) {
        API.sharedInstance.fetchStakworkWorkflowWithAuth(
            projectId: projectId,
            callback: { [weak self] workflowData in
                guard let self = self, let title = workflowData?.inProgressTitle else { return }
                DispatchQueue.main.async {
                    self.updateProcessingBubble(stepText: title)
                }
            },
            errorCallback: {
                print("[FeaturePlanVC] Failed to fetch stakwork workflow step")
            }
        )
    }

    func taskStatusUpdated(taskId: String, status: String, workflowStatus: String?, archived: Bool) {
        guard let flatIndex = feature.updateTask(taskId, apply: {
            $0.status = status
            $0.workflowStatus = workflowStatus
            $0.archived = archived
        }) else { return }
        tasksTableView.reloadRows(at: [IndexPath(row: flatIndex, section: 0)], with: .none)
        updateProgressBar()
        updateTasksEmptyState()
    }

    func prStatusChanged(taskId: String?, prNumber: Int, state: String, artifactStatus: String, prUrl: String?, problemDetails: String?) {
        // Update chat message artifact if matched
        if let idx = messages.firstIndex(where: {
            $0.artifacts.first(where: { $0.isPullRequest })?.prContent?.number == prNumber
        }), let artifactIdx = messages[idx].artifacts.firstIndex(where: { $0.isPullRequest }) {
            messages[idx].artifacts[artifactIdx].prContent?.state = state
            messages[idx].artifacts[artifactIdx].prContent?.status = artifactStatus
            if let url = prUrl { messages[idx].artifacts[artifactIdx].prContent?.url = url }
            chatTableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
        }

        // Update task row in tasks table
        let resolvedId: String?
        if let tid = taskId, feature.allTasks.contains(where: { $0.id == tid }) {
            resolvedId = tid
        } else {
            resolvedId = feature.allTasks.first(where: { $0.prNumber == prNumber })?.id
        }
        guard let id = resolvedId,
              let flatIndex = feature.updateTask(id, apply: {
                  $0.prStatus = artifactStatus
                  $0.prUrl = prUrl
              }) else { return }
        tasksTableView.reloadRows(at: [IndexPath(row: flatIndex, section: 0)], with: .none)
    }

    func featureTitleUpdated(featureId: String, newTitle: String) {
        guard featureId == feature.id else { return }
        feature.title = newTitle
        DispatchQueue.main.async { self.titleLabel.text = newTitle }
    }

    func taskTitleUpdated(taskId: String, newTitle: String) {
        guard let flatIndex = feature.updateTask(taskId, apply: { $0.title = newTitle }) else { return }
        tasksTableView.reloadRows(at: [IndexPath(row: flatIndex, section: 0)], with: .none)
    }

    func taskGenerationStatusChanged(status: String, featureId: String) {
        guard featureId == feature.id else { return }
        DispatchQueue.main.async {
            switch status {
            case "PENDING", "IN_PROGRESS":
                self.isGeneratingTasks = true
                self.lastGenerationFailed = false
                self.applyGenerationState()
            case "COMPLETED":
                self.isGeneratingTasks = false
                self.applyGenerationState()
                if self.topSegmentedControl.selectedIndex != 2 {
                    self.topSegmentedControl.indicesOfTitlesWithBadge = [2]
                }
                // feature-updated Pusher event will still call fetchFeatureDetail() to refresh task list
            case "FAILED", "HALTED", "ERROR":
                self.isGeneratingTasks = false
                self.lastGenerationFailed = true
                self.applyGenerationState()
            default:
                break
            }
        }
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
