//
//  CreateFeatureViewController.swift
//  sphinx
//
//  Created on 2026-03-05.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

// MARK: - Delegate Protocol

@MainActor protocol CreateFeatureViewControllerDelegate: AnyObject {
    func didCreateFeature(_ feature: HiveFeature)
    func didCreateTask(_ task: WorkspaceTask)
}

extension CreateFeatureViewControllerDelegate {
    func didCreateTask(_ task: WorkspaceTask) {}
}

// MARK: - CreationMode

enum CreationMode { case feature, task, debugRun, loadWorkflow }

// MARK: - CreateFeatureViewController

class CreateFeatureViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: CreateFeatureViewControllerDelegate?

    var mode: CreationMode = .feature
    var isStakworkMode: Bool = false
    var workspaceSlug: String = ""
    var repositories: [WorkspaceRepository] = []
    var selectedRepository: WorkspaceRepository? = nil
    var selectedBranch: WorkspaceBranch? = nil
    var branches: [WorkspaceBranch] = []

    private var workspaceId: String = ""

    private var workflowVersions: [WorkflowVersion] = []
    private var selectedVersion: WorkflowVersion? = nil
    private var debounceTimer: Timer? = nil

    private var promptLabel: UILabel!
    private var closeIconLabel: UILabel!
    private var closeButton: UIButton!
    private var promptFieldView: UIView!
    private var messageTextView: UITextView!
    private var sendButton: UIButton!
    private var loadingWheel: UIActivityIndicatorView!

    // Combo UI (task mode only)
    private var modeSelectorButton: UIButton!
    private var repositoryComboButton: UIButton!
    private var branchComboButton: UIButton!
    private var versionComboButton: UIButton!
    private var comboStackView: UIStackView!

    // MARK: - Instantiation

    static func instantiate(workspaceId: String) -> CreateFeatureViewController {
        let vc = StoryboardScene.Dashboard.createFeatureViewController.instantiate()
        vc.workspaceId = workspaceId
        vc.modalPresentationStyle = .automatic
        return vc
    }

    static func instantiateForTask(workspaceId: String, workspaceSlug: String, isStakwork: Bool = false) -> CreateFeatureViewController {
        let vc = StoryboardScene.Dashboard.createFeatureViewController.instantiate()
        vc.workspaceId = workspaceId
        vc.workspaceSlug = workspaceSlug
        vc.mode = .task
        vc.isStakworkMode = isStakwork
        vc.modalPresentationStyle = .automatic
        return vc
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        configureView()

        if mode == .task {
            applyMode(.task)
            API.sharedInstance.fetchWorkspaceDetailWithAuth(
                slug: workspaceSlug,
                callback: { [weak self] repos in
                    DispatchQueue.main.async {
                        self?.repositories = repos
                        self?.repositoryComboButton.setTitle("Select Repository", for: .normal)
                    }
                },
                errorCallback: { /* silently fail, button stays disabled */ }
            )
        }
    }

    // MARK: - View Setup

    private func setupViews() {
        view.backgroundColor = UIColor.Sphinx.Body

        // Header View
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        view.addSubview(headerView)

        // Close Icon Label (Material Icons)
        closeIconLabel = UILabel()
        closeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        closeIconLabel.text = "\u{E5CD}"
        closeIconLabel.font = UIFont(name: "MaterialIcons-Regular", size: 20)
        closeIconLabel.textColor = UIColor.Sphinx.WashedOutReceivedText
        headerView.addSubview(closeIconLabel)

        // Close Button
        closeButton = UIButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTouched), for: .touchUpInside)
        headerView.addSubview(closeButton)

        // Prompt Label
        promptLabel = UILabel()
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.text = (mode == .task) ? "Describe a task" : "What job are you trying to solve?"
        promptLabel.textAlignment = .center
        promptLabel.font = UIFont(name: "Roboto-Regular", size: 16)
        promptLabel.textColor = UIColor.Sphinx.Text
        promptLabel.numberOfLines = 0
        view.addSubview(promptLabel)

        // Prompt Field View (bordered container)
        promptFieldView = UIView()
        promptFieldView.translatesAutoresizingMaskIntoConstraints = false
        promptFieldView.backgroundColor = UIColor.Sphinx.ProfileBG
        view.addSubview(promptFieldView)

        // Message Text View
        messageTextView = UITextView()
        messageTextView.translatesAutoresizingMaskIntoConstraints = false
        messageTextView.backgroundColor = .clear
        messageTextView.textColor = UIColor.Sphinx.Text
        messageTextView.font = UIFont(name: "Roboto-Regular", size: 17)
        messageTextView.isScrollEnabled = true
        messageTextView.delegate = self
        promptFieldView.addSubview(messageTextView)

        // MARK: Combo Stack (task mode only — collapses when hidden)

        // Mode Selector Button (stakwork only)
        modeSelectorButton = makeComboButton(title: "Create Task")
        modeSelectorButton.addTarget(self, action: #selector(modeSelectorTapped), for: .touchUpInside)
        modeSelectorButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        modeSelectorButton.isHidden = !isStakworkMode

        // Repository Button
        repositoryComboButton = makeComboButton(title: "Select Repository")
        repositoryComboButton.addTarget(self, action: #selector(repositoryComboTapped), for: .touchUpInside)
        repositoryComboButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        // Branch Button
        branchComboButton = makeComboButton(title: "Select Branch")
        branchComboButton.isEnabled = false
        branchComboButton.alpha = 0.5
        branchComboButton.addTarget(self, action: #selector(branchComboTapped), for: .touchUpInside)
        branchComboButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        // Version Combo Button (loadWorkflow mode only)
        versionComboButton = makeComboButton(title: "Select Version")
        versionComboButton.isEnabled = false
        versionComboButton.alpha = 0.5
        versionComboButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        versionComboButton.isHidden = true
        versionComboButton.addTarget(self, action: #selector(versionComboTapped), for: .touchUpInside)

        // comboStackView holds the pickers; hidden = collapses to zero height in outer stack
        comboStackView = UIStackView(arrangedSubviews: [modeSelectorButton, repositoryComboButton, branchComboButton, versionComboButton])
        comboStackView.axis = .vertical
        comboStackView.spacing = 8
        comboStackView.isHidden = (mode == .feature)

        // Bottom Container (send button row)
        let bottomContainer = UIView()
        bottomContainer.backgroundColor = .clear
        bottomContainer.heightAnchor.constraint(equalToConstant: 100).isActive = true

        // Send Button
        sendButton = UIButton()
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("SEND", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 17)
        sendButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        sendButton.addTarget(self, action: #selector(sendButtonTouched), for: .touchUpInside)
        bottomContainer.addSubview(sendButton)

        // Loading Wheel
        loadingWheel = UIActivityIndicatorView(style: .medium)
        loadingWheel.translatesAutoresizingMaskIntoConstraints = false
        loadingWheel.hidesWhenStopped = true
        bottomContainer.addSubview(loadingWheel)

        NSLayoutConstraint.activate([
            sendButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
            sendButton.centerYAnchor.constraint(equalTo: bottomContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 175),
            sendButton.heightAnchor.constraint(equalToConstant: 50),
            loadingWheel.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            loadingWheel.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -20),
        ])

        // Outer vertical stack: combo pickers + send row.
        // UIStackView collapses hidden arranged subviews → no phantom gap in feature mode.
        let outerStack = UIStackView(arrangedSubviews: [comboStackView, bottomContainer])
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.axis = .vertical
        outerStack.spacing = 0
        view.addSubview(outerStack)

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Header View
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            // Close Button (50×50 tap target, top-right)
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 50),

            // Close Icon centred in close button
            closeIconLabel.centerXAnchor.constraint(equalTo: closeButton.centerXAnchor),
            closeIconLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            // Prompt Label
            promptLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            promptLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            promptLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Prompt Field View
            promptFieldView.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 16),
            promptFieldView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            promptFieldView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            promptFieldView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.5),

            // Message Text View inside Prompt Field View
            messageTextView.topAnchor.constraint(equalTo: promptFieldView.topAnchor, constant: 8),
            messageTextView.leadingAnchor.constraint(equalTo: promptFieldView.leadingAnchor, constant: 16),
            messageTextView.trailingAnchor.constraint(equalTo: promptFieldView.trailingAnchor, constant: -16),
            messageTextView.bottomAnchor.constraint(equalTo: promptFieldView.bottomAnchor, constant: -8),
            messageTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Outer stack anchored below promptFieldView, full width (with 16pt inset)
            outerStack.topAnchor.constraint(equalTo: promptFieldView.bottomAnchor, constant: 12),
            outerStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            outerStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
    }

    /// Creates a styled combo-select button (chevron on right, left-aligned title).
    private func makeComboButton(title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.backgroundColor = UIColor.Sphinx.ProfileBG
        btn.layer.cornerRadius = 5
        btn.clipsToBounds = true
        btn.contentHorizontalAlignment = .left
        btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)

        btn.setTitle(title, for: .normal)
        btn.setTitleColor(UIColor.Sphinx.Text, for: .normal)
        btn.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)

        // Chevron on the right
        let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = UIColor.Sphinx.SecondaryText
        chevron.contentMode = .scaleAspectFit
        btn.addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 16),
            chevron.heightAnchor.constraint(equalToConstant: 16),
        ])
        return btn
    }

    private func configureView() {
        promptFieldView.layer.cornerRadius = 5

        sendButton.layer.cornerRadius = 25
        sendButton.clipsToBounds = true
        sendButton.addShadow(
            location: VerticalLocation.bottom,
            color: UIColor.Sphinx.PrimaryBlueBorder,
            opacity: 1,
            radius: 0.5,
            bottomhHeight: 1.5
        )

        updateSendButtonState()
    }

    // MARK: - Send Button State

    private func updateSendButtonState() {
        let hasMessage = !(messageTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasRepo = selectedRepository != nil
        let isLoadWorkflowReady = mode == .loadWorkflow
            && Int(messageTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") != nil
            && selectedVersion != nil
        sendButton.isEnabled = hasMessage && (mode == .feature || (mode == .task && hasRepo) || mode == .debugRun || isLoadWorkflowReady)
    }

    // MARK: - Mode Management

    private func applyMode(_ newMode: CreationMode) {
        mode = newMode
        switch newMode {
        case .task:         promptLabel.text = "Describe a task"
        case .debugRun:     promptLabel.text = "Paste Run ID"
        case .loadWorkflow: promptLabel.text = "Paste Workflow ID"
        default: break
        }
        repositoryComboButton.isHidden = (newMode != .task)
        branchComboButton.isHidden     = (newMode != .task)
        versionComboButton.isHidden    = (newMode != .loadWorkflow)
        switch newMode {
        case .task:         sendButton.setTitle("SEND", for: .normal)
        case .debugRun:     sendButton.setTitle("Debug this run", for: .normal)
        case .loadWorkflow: sendButton.setTitle("Load Workflow", for: .normal)
        default: break
        }
        switch newMode {
        case .debugRun, .loadWorkflow:
            messageTextView.keyboardType = .numberPad
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
            toolbar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done]
            messageTextView.inputAccessoryView = toolbar
        case .feature, .task:
            messageTextView.keyboardType = .default
            messageTextView.inputAccessoryView = nil
        }
        messageTextView.reloadInputViews()
        updateSendButtonState()
    }

    @objc private func modeSelectorTapped() {
        let sheet = UIAlertController(title: "Select Mode", message: nil, preferredStyle: .actionSheet)
        let options: [(String, CreationMode)] = [
            ("Create Task", .task),
            ("Debug Run", .debugRun),
            ("Load Workflow", .loadWorkflow)
        ]
        for (title, modeCase) in options {
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self else { return }
                self.modeSelectorButton.setTitle(title, for: .normal)
                self.applyMode(modeCase)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = modeSelectorButton
            popover.sourceRect = modeSelectorButton.bounds
        }
        present(sheet, animated: true)
    }

    // MARK: - Combo Actions

    @objc private func repositoryComboTapped() {
        guard !repositories.isEmpty else { return }

        let sheet = UIAlertController(title: "Select Repository", message: nil, preferredStyle: .actionSheet)
        for repo in repositories {
            sheet.addAction(UIAlertAction(title: repo.name, style: .default) { [weak self] _ in
                guard let self else { return }
                self.selectedRepository = repo
                self.repositoryComboButton.setTitle(repo.name, for: .normal)
                self.fetchBranches(for: repo)
                self.updateSendButtonState()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = repositoryComboButton
            popover.sourceRect = repositoryComboButton.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func branchComboTapped() {
        guard !branches.isEmpty else { return }

        let sheet = UIAlertController(title: "Select Branch", message: nil, preferredStyle: .actionSheet)
        for branch in branches {
            sheet.addAction(UIAlertAction(title: branch.name, style: .default) { [weak self] _ in
                guard let self else { return }
                self.selectedBranch = branch
                self.branchComboButton.setTitle(branch.name, for: .normal)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = branchComboButton
            popover.sourceRect = branchComboButton.bounds
        }
        present(sheet, animated: true)
    }

    private func fetchBranches(for repo: WorkspaceRepository) {
        branchComboButton.isEnabled = false
        branchComboButton.alpha = 0.5
        branchComboButton.setTitle("Loading branches…", for: .normal)

        API.sharedInstance.fetchBranchesWithAuth(
            repoUrl: repo.repositoryUrl,
            workspaceSlug: workspaceSlug,
            callback: { [weak self] fetchedBranches in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.branchComboButton.isEnabled = true
                    self.branchComboButton.alpha = 1.0
                    self.branches = fetchedBranches
                    // Pre-select master/main, otherwise first branch
                    let preferred = fetchedBranches.first(where: { $0.name == "master" || $0.name == "main" })
                        ?? fetchedBranches.first
                    self.selectedBranch = preferred
                    self.branchComboButton.setTitle(preferred?.name ?? "Select Branch", for: .normal)
                    self.updateSendButtonState()
                }
            },
            errorCallback: { [weak self] in
                // API failed — fall back to just "master"
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.branchComboButton.isEnabled = true
                    self.branchComboButton.alpha = 1.0
                    let master = WorkspaceBranch(json: ["name": "master"])
                    self.branches = [master]
                    self.selectedBranch = master
                    self.branchComboButton.setTitle("master", for: .normal)
                    self.updateSendButtonState()
                }
            }
        )
    }

    // MARK: - Actions

    @objc private func closeButtonTouched() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func sendButtonTouched() {
        view.endEditing(true)

        let message = messageTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !message.isEmpty else {
            AlertHelper.showAlert(
                title: "Error",
                message: "Please enter a message before sending."
            )
            return
        }

        // MARK: Debug Run mode
        if mode == .debugRun {
            let runId = message
            sendButton.isEnabled = false
            loadingWheel.startAnimating()

            // Step 1: Verify project exists and get workflow_id
            API.sharedInstance.fetchStakworkProjectWithAuth(
                projectId: runId,
                callback: { [weak self] projectData in
                    guard let self else { return }
                    guard let workflowId = projectData["workflow_id"] as? Int else {
                        DispatchQueue.main.async {
                            self.resetSendButton()
                            AlertHelper.showAlert(title: "Error", message: "Project has no workflow_id.")
                        }
                        return
                    }

                    // Step 2: Fetch latest workflow version
                    API.sharedInstance.fetchWorkflowVersionsWithAuth(
                        workspaceSlug: self.workspaceSlug,
                        workflowId: workflowId,
                        callback: { [weak self] versions in
                            guard let self, let latestVersion = versions.first else {
                                DispatchQueue.main.async {
                                    self?.resetSendButton()
                                    AlertHelper.showAlert(title: "Error", message: "No workflow versions found.")
                                }
                                return
                            }
                            let workflowName = latestVersion.workflowName ?? "Workflow \(workflowId)"
                            let workflowRefId = latestVersion.refId ?? ""
                            let workflowVersionId = latestVersion.versionId
                            let taskTitle = "Debug run \(runId)"

                            // Step 3: Create workflow_editor task
                            API.sharedInstance.createWorkflowTaskWithAuth(
                                title: taskTitle,
                                description: taskTitle,
                                workspaceSlug: self.workspaceSlug,
                                callback: { [weak self] task in
                                    guard let self, let task else {
                                        DispatchQueue.main.async {
                                            self?.resetSendButton()
                                            AlertHelper.showAlert(title: "Error", message: "Failed to create task.")
                                        }
                                        return
                                    }

                                    // Step 4: Save ASSISTANT WORKFLOW artifact
                                    var artifactContent: [String: AnyObject] = [
                                        "workflowId": workflowId as AnyObject,
                                        "workflowName": workflowName as AnyObject,
                                        "workflowRefId": workflowRefId as AnyObject,
                                        "workflowVersionId": workflowVersionId as AnyObject
                                    ]
                                    if let workflowJson = latestVersion.workflowJson {
                                        artifactContent["workflowJson"] = workflowJson as AnyObject
                                    }
                                    let workflowArtifact: [String: AnyObject] = [
                                        "type": "WORKFLOW" as AnyObject,
                                        "content": artifactContent as AnyObject
                                    ]
                                    let artifactMessage = "Loaded: \(workflowName)\nSelect a step on the right as a starting point."
                                    API.sharedInstance.saveTaskMessageWithAuth(
                                        taskId: task.id,
                                        message: artifactMessage,
                                        role: "ASSISTANT",
                                        artifacts: [workflowArtifact],
                                        callback: { [weak self] _ in
                                            guard let self else { return }

                                            // Step 5: Auto-send debug message
                                            API.sharedInstance.sendWorkflowEditorDebugMessageWithAuth(
                                                taskId: task.id,
                                                message: "Debug this run \(runId)",
                                                workflowId: workflowId,
                                                workflowName: workflowName,
                                                workflowRefId: workflowRefId,
                                                workflowVersionId: workflowVersionId,
                                                callback: { [weak self] _ in
                                                    // Step 6: Navigate to new task
                                                    DispatchQueue.main.async {
                                                        self?.finishDebugRunCreation(task: task)
                                                    }
                                                },
                                                errorCallback: { [weak self] in
                                                    DispatchQueue.main.async {
                                                        self?.resetSendButton()
                                                        AlertHelper.showAlert(title: "Error", message: "Failed to send debug message.")
                                                    }
                                                }
                                            )
                                        },
                                        errorCallback: { [weak self] in
                                            DispatchQueue.main.async {
                                                self?.resetSendButton()
                                                AlertHelper.showAlert(title: "Error", message: "Failed to save workflow artifact.")
                                            }
                                        }
                                    )
                                },
                                errorCallback: { [weak self] in
                                    DispatchQueue.main.async {
                                        self?.resetSendButton()
                                        AlertHelper.showAlert(title: "Error", message: "Failed to create task.")
                                    }
                                }
                            )
                        },
                        errorCallback: { [weak self] in
                            DispatchQueue.main.async {
                                self?.resetSendButton()
                                AlertHelper.showAlert(title: "Error", message: "Failed to fetch workflow versions.")
                            }
                        }
                    )
                },
                errorCallback: { [weak self] errorMessage in
                    DispatchQueue.main.async {
                        self?.resetSendButton()
                        AlertHelper.showAlert(title: "Error", message: "Run not found: \(errorMessage)")
                    }
                }
            )
            return
        }

        // MARK: Load Workflow mode
        if mode == .loadWorkflow {
            guard let workflowId = Int(message), let version = selectedVersion else { return }
            let workflowName = version.workflowName ?? "Workflow \(workflowId)"
            let versionShort = String(version.versionId.prefix(8))
            let taskTitle = "\(workflowName) v\(versionShort)"
            let taskDescription = "Editing workflow \(workflowId) version \(versionShort)"

            sendButton.isEnabled = false
            loadingWheel.startAnimating()

            API.sharedInstance.createWorkflowTaskWithAuth(
                title: taskTitle,
                description: taskDescription,
                workspaceSlug: workspaceSlug,
                callback: { [weak self] task in
                    guard let self, let task else {
                        DispatchQueue.main.async {
                            self?.resetSendButton()
                            AlertHelper.showAlert(title: "Error", message: "Failed to create task.")
                        }
                        return
                    }
                    var artifactContent: [String: AnyObject] = [
                        "workflowId": workflowId as AnyObject,
                        "workflowName": workflowName as AnyObject,
                        "workflowRefId": (version.refId ?? "") as AnyObject,
                        "workflowVersionId": version.versionId as AnyObject
                    ]
                    if let wfJson = version.workflowJson {
                        artifactContent["workflowJson"] = wfJson as AnyObject
                    }
                    let artifact: [String: AnyObject] = [
                        "type": "WORKFLOW" as AnyObject,
                        "content": artifactContent as AnyObject
                    ]
                    API.sharedInstance.saveTaskMessageWithAuth(
                        taskId: task.id,
                        message: "Loaded: \(taskTitle)\nSelect a step on the right as a starting point.",
                        role: "ASSISTANT",
                        artifacts: [artifact],
                        callback: { [weak self] _ in
                            DispatchQueue.main.async { self?.finishLoadWorkflowCreation(task: task) }
                        },
                        errorCallback: { [weak self] in
                            DispatchQueue.main.async {
                                self?.resetSendButton()
                                AlertHelper.showAlert(title: "Error", message: "Failed to save workflow artifact.")
                            }
                        }
                    )
                },
                errorCallback: { [weak self] in
                    DispatchQueue.main.async {
                        self?.resetSendButton()
                        AlertHelper.showAlert(title: "Error", message: "Failed to create task.")
                    }
                }
            )
            return
        }

        // MARK: Task mode
        if mode == .task {
            guard let repo = selectedRepository else { return }
            let branch = selectedBranch?.name ?? repo.branch ?? "main"
            sendButton.isEnabled = false
            loadingWheel.startAnimating()

            API.sharedInstance.createTaskWithAuth(
                title: String(message.prefix(100)),
                workspaceSlug: workspaceSlug,
                repositoryId: repo.id,
                branch: branch,
                callback: { [weak self] task in
                    guard let self else { return }
                    guard let task = task else {
                        DispatchQueue.main.async {
                            self.resetSendButton()
                            AlertHelper.showAlert(title: "Error", message: "Failed to create task.")
                        }
                        return
                    }
                    // Step 2: Send initial message (fire-and-forget)
                    API.sharedInstance.sendTaskChatMessageWithAuth(
                        taskId: task.id,
                        message: message,
                        callback: { [weak self] _ in
                            DispatchQueue.main.async { self?.finishTaskCreation(task: task) }
                        },
                        errorCallback: { [weak self] in
                            DispatchQueue.main.async { self?.finishTaskCreation(task: task) }
                        }
                    )
                },
                errorCallback: { [weak self] in
                    DispatchQueue.main.async {
                        self?.resetSendButton()
                        AlertHelper.showAlert(title: "Error", message: "Failed to create task. Please try again.")
                    }
                }
            )
            return
        }

        // MARK: Feature mode (existing path)

        // Disable button and start loading
        sendButton.isEnabled = false
        loadingWheel.startAnimating()

        let title = String(message.prefix(100))

        // Step 1: Create the feature
        API.sharedInstance.createFeatureWithAuth(
            workspaceId: workspaceId,
            title: title,
            callback: { [weak self] feature in
                guard let self = self else { return }

                guard let feature = feature else {
                    DispatchQueue.main.async {
                        self.sendButton.isEnabled = true
                        self.loadingWheel.stopAnimating()
                        AlertHelper.showAlert(
                            title: "Error",
                            message: "Failed to create feature. Please try again."
                        )
                    }
                    return
                }

                // Step 2: Send the first chat message (fire-and-forget)
                API.sharedInstance.sendFeatureChatMessageWithAuth(
                    featureId: feature.id,
                    message: message,
                    callback: { [weak self] _ in
                        DispatchQueue.main.async {
                            self?.finishCreation(feature: feature)
                        }
                    },
                    errorCallback: { [weak self] in
                        // Step 2 failed — proceed anyway (match web behaviour)
                        DispatchQueue.main.async {
                            self?.finishCreation(feature: feature)
                        }
                    }
                )
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.sendButton.isEnabled = true
                    self?.loadingWheel.stopAnimating()
                    AlertHelper.showAlert(
                        title: "Error",
                        message: "Failed to create feature. Please try again."
                    )
                }
            }
        )
    }

    // MARK: - Helpers

    private func resetSendButton() {
        sendButton.isEnabled = true
        loadingWheel.stopAnimating()
    }

    private func finishCreation(feature: HiveFeature) {
        delegate?.didCreateFeature(feature)
        dismiss(animated: true, completion: nil)
    }

    private func finishTaskCreation(task: WorkspaceTask) {
        delegate?.didCreateTask(task)
        dismiss(animated: true)
    }

    private func finishDebugRunCreation(task: WorkspaceTask) {
        delegate?.didCreateTask(task)
        dismiss(animated: true)
    }

    private func finishLoadWorkflowCreation(task: WorkspaceTask) {
        delegate?.didCreateTask(task)
        dismiss(animated: true)
    }

    // MARK: - Version Combo Actions

    @objc private func versionComboTapped() {
        guard !workflowVersions.isEmpty else { return }
        let sheet = UIAlertController(title: "Select a version", message: nil, preferredStyle: .actionSheet)
        for (i, version) in workflowVersions.enumerated() {
            sheet.addAction(UIAlertAction(title: displayTitle(for: version, index: i), style: .default) { [weak self] _ in
                guard let self else { return }
                self.selectedVersion = version
                self.versionComboButton.setTitle(self.displayTitle(for: version, index: i), for: .normal)
                self.updateSendButtonState()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = versionComboButton
            popover.sourceRect = versionComboButton.bounds
        }
        present(sheet, animated: true)
    }

    private func fetchVersions(for workflowId: Int) {
        API.sharedInstance.fetchWorkflowVersionsWithAuth(
            workspaceSlug: workspaceSlug,
            workflowId: workflowId,
            callback: { [weak self] versions in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.workflowVersions = versions
                    self.selectedVersion = versions.first
                    if let first = versions.first {
                        self.versionComboButton.setTitle(self.displayTitle(for: first, index: 0), for: .normal)
                        self.versionComboButton.isEnabled = true
                        self.versionComboButton.alpha = 1.0
                    } else {
                        self.versionComboButton.setTitle("No versions found", for: .normal)
                        self.versionComboButton.isEnabled = false
                        self.versionComboButton.alpha = 0.5
                    }
                    self.updateSendButtonState()
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.versionComboButton.setTitle("Failed to load versions", for: .normal)
                    self.versionComboButton.isEnabled = false
                    self.versionComboButton.alpha = 0.5
                    self.updateSendButtonState()
                }
            }
        )
    }

    private func displayTitle(for version: WorkflowVersion, index: Int) -> String {
        let short = String(version.versionId.prefix(8))
        let dateStr: String = {
            guard let date = version.dateAddedToGraph else { return "" }
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return "  \(f.string(from: date))"
        }()
        let latest = index == 0 ? "  [Latest]" : ""
        let published = version.published ? "  [Published]" : ""
        return "\(short)\(dateStr)\(latest)\(published)"
    }
}

// MARK: - UITextViewDelegate

extension CreateFeatureViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateSendButtonState()
        guard mode == .loadWorkflow else { return }

        // Reset state on every keystroke
        debounceTimer?.invalidate()
        debounceTimer = nil
        workflowVersions = []
        selectedVersion = nil
        versionComboButton.setTitle("Select Version", for: .normal)
        versionComboButton.isEnabled = false
        versionComboButton.alpha = 0.5
        updateSendButtonState()

        let text = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty, let workflowId = Int(text) else { return }

        versionComboButton.setTitle("Loading versions…", for: .normal)
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.fetchVersions(for: workflowId)
        }
    }
}
