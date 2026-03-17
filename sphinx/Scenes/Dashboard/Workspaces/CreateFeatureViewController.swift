//
//  CreateFeatureViewController.swift
//  sphinx
//
//  Created on 2026-03-05.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

// MARK: - Delegate Protocol

protocol CreateFeatureViewControllerDelegate: AnyObject {
    func didCreateFeature(_ feature: HiveFeature)
    func didCreateTask(_ task: WorkspaceTask)
}

extension CreateFeatureViewControllerDelegate {
    func didCreateTask(_ task: WorkspaceTask) {}
}

// MARK: - CreationMode

enum CreationMode { case feature, task }

// MARK: - CreateFeatureViewController

class CreateFeatureViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: CreateFeatureViewControllerDelegate?

    var mode: CreationMode = .feature
    var workspaceSlug: String = ""
    var repositories: [WorkspaceRepository] = []
    var selectedRepository: WorkspaceRepository? = nil
    var selectedBranch: WorkspaceBranch? = nil
    var branches: [WorkspaceBranch] = []

    private var workspaceId: String = ""

    private var promptLabel: UILabel!
    private var closeIconLabel: UILabel!
    private var closeButton: UIButton!
    private var promptFieldView: UIView!
    private var messageTextView: UITextView!
    private var sendButton: UIButton!
    private var loadingWheel: UIActivityIndicatorView!

    // Combo UI (task mode only)
    private var repositoryComboButton: UIButton!
    private var branchComboButton: UIButton!
    private var comboStackView: UIStackView!

    // MARK: - Instantiation

    static func instantiate(workspaceId: String) -> CreateFeatureViewController {
        let vc = StoryboardScene.Dashboard.createFeatureViewController.instantiate()
        vc.workspaceId = workspaceId
        vc.modalPresentationStyle = .automatic
        return vc
    }

    static func instantiateForTask(workspaceId: String, workspaceSlug: String) -> CreateFeatureViewController {
        let vc = StoryboardScene.Dashboard.createFeatureViewController.instantiate()
        vc.workspaceId = workspaceId
        vc.workspaceSlug = workspaceSlug
        vc.mode = .task
        vc.modalPresentationStyle = .automatic
        return vc
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        configureView()

        if mode == .task {
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

        // comboStackView holds the two pickers; hidden = collapses to zero height in outer stack
        comboStackView = UIStackView(arrangedSubviews: [repositoryComboButton, branchComboButton])
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
        sendButton.isEnabled = hasMessage && (mode == .feature || hasRepo)
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
}

// MARK: - UITextViewDelegate

extension CreateFeatureViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateSendButtonState()
    }
}
