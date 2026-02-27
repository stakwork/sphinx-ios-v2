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
        
        // Initially show chat panel
        showChatPanel()
    }
    
    private func setupHeader() {
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor.Sphinx.Body
        view.addSubview(headerView)
        
        backButton = UIButton()
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTouched), for: .touchUpInside)
        headerView.addSubview(backButton)
        
        let backIconLabel = UILabel()
        backIconLabel.translatesAutoresizingMaskIntoConstraints = false
        backIconLabel.text = "arrow_back"
        backIconLabel.font = UIFont(name: "MaterialIcons-Regular", size: 24)
        backIconLabel.textColor = UIColor.Sphinx.Text
        backButton.addSubview(backIconLabel)
        
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = feature.name
        titleLabel.font = UIFont(name: "Roboto-Medium", size: 17)
        titleLabel.textColor = UIColor.Sphinx.Text
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            backButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            backButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 50),
            
            backIconLabel.centerXAnchor.constraint(equalTo: backButton.centerXAnchor),
            backIconLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -58)
        ])
    }
    
    private func setupTopSegmentedControl() {
        topSegmentedControl = CustomSegmentedControl(
            frame: .zero,
            buttonTitles: ["CHAT", "PLAN"],
            initialIndex: 0
        )
        topSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        topSegmentedControl.delegate = self
        topSegmentedControl.backgroundColor = UIColor.Sphinx.Body
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
        
        // Plan Segmented Control
        planSegmentedControl = CustomSegmentedControl(
            frame: .zero,
            buttonTitles: ["BRIEF", "USER STORIES", "REQUIREMENTS", "ARCHITECTURE"],
            initialIndex: 0
        )
        planSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        planSegmentedControl.delegate = self
        planSegmentedControl.backgroundColor = UIColor.Sphinx.Body
        planContainerView.addSubview(planSegmentedControl)
        
        // Plan Text View
        planTextView = UITextView()
        planTextView.translatesAutoresizingMaskIntoConstraints = false
        planTextView.backgroundColor = UIColor.Sphinx.Body
        planTextView.textColor = UIColor.Sphinx.Text
        planTextView.font = UIFont(name: "Roboto-Regular", size: 15)
        planTextView.isEditable = false
        planTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
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
                    self?.generateTasksButton.isEnabled = true
                    self?.generateLoadingWheel.stopAnimating()
                    self?.showGenerateTasksSuccess()
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
    
    // MARK: - Panel Management
    private func showChatPanel() {
        chatContainerView.isHidden = false
        planContainerView.isHidden = true
    }
    
    private func showPlanPanel() {
        chatContainerView.isHidden = true
        planContainerView.isHidden = false
        updatePlanText()
    }
    
    private func updatePlanText() {
        let selectedIndex = planSegmentedControl.selectedIndex
        
        switch selectedIndex {
        case 0: // BRIEF
            planTextView.text = feature.brief ?? "No brief available yet."
        case 1: // USER STORIES
            planTextView.text = feature.userStories ?? "No user stories available yet."
        case 2: // REQUIREMENTS
            planTextView.text = feature.requirements ?? "No requirements available yet."
        case 3: // ARCHITECTURE
            planTextView.text = feature.architecture ?? "No architecture available yet."
        default:
            planTextView.text = ""
        }
    }
    
    private func updateAIWorkingState() {
        sendButton.isEnabled = !isAIWorking
        sendButton.alpha = isAIWorking ? 0.5 : 1.0
        chatInputTextView.isEditable = !isAIWorking
    }
    
    // MARK: - API Methods
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
        guard let token = UserDefaults.Keys.hiveToken.get() as? String else {
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
    func segmentedControlDidSwitch(to index: Int) {
        // Legacy method - kept for compatibility
    }
    
    func segmentedControl(_ control: CustomSegmentedControl, didSwitchTo index: Int) {
        if control == topSegmentedControl {
            // Top level segmented control (CHAT / PLAN)
            if index == 0 {
                showChatPanel()
            } else {
                showPlanPanel()
            }
        } else if control == planSegmentedControl {
            // Plan sub-tabs
            updatePlanText()
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension FeaturePlanViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
