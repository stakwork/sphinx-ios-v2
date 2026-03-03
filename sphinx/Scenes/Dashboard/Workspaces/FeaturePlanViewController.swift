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
    private var messages: [HiveChatMessage] = []
    private var isAIWorking: Bool = false {
        didSet {
            updateAIWorkingState()
        }
    }
    
    // MARK: - UI Components
    private var headerView: UIView!
    private var backButton: UIButton!
    private var titleLabel: UILabel!
    
    private var topSegmentedControl: CustomSegmentedControl!
    private var chatContainerView: UIView!
    private var planContainerView: UIView!
    private var tasksContainerView: UIView!
    private var tasksTableView: UITableView!
    
    // Chat Panel Components
    private var chatTableView: UITableView!
    private var chatInputContainer: UIView!
    private var chatInputTextView: UITextView!
    private var sendButton: UIButton!
    private var chatInputContainerBottomConstraint: NSLayoutConstraint!
    
    // Plan Panel Components
    private var planSegmentedControl: CustomSegmentedControl!
    private var planTextView: UITextView!
    private var generateTasksButton: UIButton!
    private var generateLoadingWheel: UIActivityIndicatorView!
    private lazy var markdownRenderer: MarkdownRenderer = {
        var style = MarkdownStyle()
        style.baseFontSize = 15
        return MarkdownRenderer(style: style)
    }()
    
    // MARK: - Initialization
    static func instantiate(feature: HiveFeature) -> FeaturePlanViewController {
        return FeaturePlanViewController(feature: feature)
    }
    
    private init(feature: HiveFeature) {
        self.feature = feature
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardObservers()
        fetchFeatureDetail()
        fetchChatHistory()
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

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 50),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -58)
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
        chatTableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        chatContainerView.addSubview(chatTableView)
        
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
        
        chatInputContainerBottomConstraint = chatInputContainer.bottomAnchor.constraint(equalTo: chatContainerView.bottomAnchor)
        
        NSLayoutConstraint.activate([
            chatContainerView.topAnchor.constraint(equalTo: topSegmentedControl.bottomAnchor),
            chatContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            chatTableView.topAnchor.constraint(equalTo: chatContainerView.topAnchor),
            chatTableView.leadingAnchor.constraint(equalTo: chatContainerView.leadingAnchor),
            chatTableView.trailingAnchor.constraint(equalTo: chatContainerView.trailingAnchor),
            chatTableView.bottomAnchor.constraint(equalTo: chatInputContainer.topAnchor),
            
            chatInputContainer.leadingAnchor.constraint(equalTo: chatContainerView.leadingAnchor),
            chatInputContainer.trailingAnchor.constraint(equalTo: chatContainerView.trailingAnchor),
            chatInputContainerBottomConstraint,
            chatInputContainer.heightAnchor.constraint(equalToConstant: 80),
            
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
        generateTasksButton.setTitleColor(.white, for: .normal)
        generateTasksButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 16)
        generateTasksButton.backgroundColor = UIColor.Sphinx.PrimaryGreen
        generateTasksButton.layer.cornerRadius = 25
        generateTasksButton.addTarget(self, action: #selector(generateTasksButtonTouched), for: .touchUpInside)
        planContainerView.addSubview(generateTasksButton)
        
        // Loading Wheel
        generateLoadingWheel = UIActivityIndicatorView(style: .medium)
        generateLoadingWheel.translatesAutoresizingMaskIntoConstraints = false
        generateLoadingWheel.hidesWhenStopped = true
        generateLoadingWheel.color = UIColor.Sphinx.Text
        planContainerView.addSubview(generateLoadingWheel)
        
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
            planTextView.bottomAnchor.constraint(equalTo: generateTasksButton.topAnchor, constant: -16),
            
            generateTasksButton.leadingAnchor.constraint(equalTo: planContainerView.leadingAnchor, constant: 32),
            generateTasksButton.trailingAnchor.constraint(equalTo: planContainerView.trailingAnchor, constant: -32),
            generateTasksButton.bottomAnchor.constraint(equalTo: planContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            generateTasksButton.heightAnchor.constraint(equalToConstant: 50),
            
            generateLoadingWheel.centerYAnchor.constraint(equalTo: generateTasksButton.centerYAnchor),
            generateLoadingWheel.trailingAnchor.constraint(equalTo: generateTasksButton.leadingAnchor, constant: -20)
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
        chatInputContainerBottomConstraint.constant = -keyboardHeight
        
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
    @objc private func backButtonTouched() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func sendButtonTouched() {
        guard let message = chatInputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return
        }
        
        sendChatMessage(message)
    }
    
    @objc private func generateTasksButtonTouched() {
        generateTasksButton.isEnabled = false
        generateLoadingWheel.startAnimating()
        
        API.sharedInstance.generateFeatureTasksWithAuth(
            featureId: feature.id,
            callback: { [weak self] in
                DispatchQueue.main.async {
                    self?.generateLoadingWheel.stopAnimating()
                    self?.showGenerateTasksSuccess()
                    // Re-fetch feature so tasks list populates and button hides
                    self?.fetchFeatureDetail()
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.generateTasksButton.isEnabled = true
                    self?.generateLoadingWheel.stopAnimating()
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
        tasksContainerView.addSubview(tasksTableView)

        NSLayoutConstraint.activate([
            tasksContainerView.topAnchor.constraint(equalTo: topSegmentedControl.bottomAnchor),
            tasksContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tasksContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tasksContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tasksTableView.topAnchor.constraint(equalTo: tasksContainerView.topAnchor),
            tasksTableView.leadingAnchor.constraint(equalTo: tasksContainerView.leadingAnchor),
            tasksTableView.trailingAnchor.constraint(equalTo: tasksContainerView.trailingAnchor),
            tasksTableView.bottomAnchor.constraint(equalTo: tasksContainerView.bottomAnchor)
        ])
    }

    // MARK: - Panel Management
    private func showPanel(at index: Int) {
        chatContainerView.isHidden  = (index != 0)
        planContainerView.isHidden  = (index != 1)
        tasksContainerView.isHidden = (index != 2)
        if index == 1 { updatePlanText() }
        if index == 2 { tasksTableView.reloadData() }
    }

    private func updateGenerateTasksButton() {
        generateTasksButton.isHidden = feature.hasTasks
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
    
    // MARK: - API Methods
    private func fetchFeatureDetail() {
        API.sharedInstance.fetchFeatureDetailWithAuth(
            featureId: feature.id,
            callback: { [weak self] updatedFeature in
                guard let self = self, let updatedFeature = updatedFeature else { return }
                DispatchQueue.main.async {
                    self.feature = updatedFeature
                    // Refresh plan panel if currently visible
                    if !self.planContainerView.isHidden {
                        self.updatePlanText()
                    }
                    // Refresh tasks panel if currently visible
                    if !self.tasksContainerView.isHidden {
                        self.tasksTableView.reloadData()
                    }
                    // Show/hide generate button based on whether tasks exist
                    self.updateGenerateTasksButton()
                }
            },
            errorCallback: {
                print("[FeaturePlanVC] Failed to fetch feature detail")
            }
        )
    }

    private func fetchChatHistory() {
        API.sharedInstance.fetchFeatureChatWithAuth(
            featureId: feature.id,
            callback: { [weak self] messages in
                DispatchQueue.main.async {
                    self?.messages = messages
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
        
        API.sharedInstance.sendFeatureChatMessageWithAuth(
            featureId: feature.id,
            message: message,
            callback: { [weak self] in
                DispatchQueue.main.async {
                    // Message will be added via WebSocket
                    print("Message sent successfully")
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
    
    // MARK: - WebSocket
    private func connectWebSocket() {
        guard let token: String = UserDefaults.Keys.hiveToken.get() else {
            print("No Hive auth token found")
            return
        }
        
        HivePusherManager.shared.delegate = self
        HivePusherManager.shared.connect(featureId: feature.id, authToken: token)
    }
    
    // MARK: - Helper Methods
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        
        let lastIndexPath = IndexPath(row: messages.count - 1, section: 0)
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
        return messages.count
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
        return cell
    }
}

// MARK: - HivePusherDelegate
extension FeaturePlanViewController: HivePusherDelegate {
    func featureUpdated(_ updatedFeature: HiveFeature) {
        self.feature = updatedFeature
        updatePlanText()
    }
    
    func newMessageReceived(_ message: HiveChatMessage) {
        messages.append(message)
        
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        chatTableView.insertRows(at: [indexPath], with: .automatic)
        scrollToBottom()
    }
    
    func workflowStatusChanged(isWorking: Bool) {
        self.isAIWorking = isWorking
    }
}
