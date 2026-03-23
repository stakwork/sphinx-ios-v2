//
//  WorkspaceViewController.swift
//  sphinx
//
//  Created on 2/23/26.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

class WorkspaceViewController: PopHandlerViewController {

    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var viewTitle: UILabel!

    @IBOutlet weak var searchBarContainerView: UIView!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchCancelButton: UIButton!

    @IBOutlet weak var topTabContainer: UIView!
    @IBOutlet weak var topTabSegmentedControl: CustomSegmentedControl!

    @IBOutlet weak var containerView: UIView!

    private var workspace: Workspace!
    private var currentTab: Int = 0 // 0 = Features, 1 = Tasks, 2 = Graph Chat

    private var activeFeaturesVC: WorkspaceFeaturesViewController!
    private var activeTasksVC: WorkspaceTasksViewController!
    private var activeGraphChatVC: WorkspaceGraphChatViewController?
    private var hasAppeared = false
    private var searchVC: WorkspaceSearchViewController?
    private let newBubbleHelper = NewMessageBubbleHelper()

    private lazy var createFeatureButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        btn.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        btn.tintColor = .Sphinx.PrimaryBlue
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    static func instantiate(workspace: Workspace) -> WorkspaceViewController {
        let vc = StoryboardScene.Dashboard.workspaceViewController.instantiate()
        vc.workspace = workspace
        vc.popOnSwipeEnabled = true
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupSearchBar()
        setupSegmentedControls()
        switchToTab(0)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasAppeared {
            reconnectAndRefresh()
        } else {
            hasAppeared = true
            HivePusherManager.shared.delegate = self
            if !HivePusherManager.shared.isConnectedToWorkspace(id: workspace.id) {
                HivePusherManager.shared.connect(workspaceId: workspace.id, workspaceSlug: workspace.slug)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        HivePusherManager.shared.disconnect()
    }

    @objc private func appWillEnterForeground() {
        reconnectAndRefresh()
    }

    private func reconnectAndRefresh() {
        HivePusherManager.shared.delegate = self
        if !HivePusherManager.shared.isConnectedToWorkspace(id: workspace.id) {
            HivePusherManager.shared.connect(workspaceId: workspace.id, workspaceSlug: workspace.slug)
        }
        // Only reload data; never touch visibility — the search overlay (if active)
        // already covers the tab/content stack, so its isHidden state must not change.
        if currentTab == 0 {
            activeFeaturesVC?.loadFeatures()
        } else if currentTab == 1 {
            activeTasksVC?.loadTasks()
        }
        // currentTab == 2 (Graph Chat): history is in-memory, stream self-manages — no reload needed
    }

    private func setupHeader() {
        headerView.backgroundColor = .Sphinx.Body
        viewTitle.font = UIFont(name: "Roboto-Medium", size: 14)
        viewTitle.textColor = .Sphinx.Text
        viewTitle.text = workspace.name.uppercased()

        headerView.addSubview(createFeatureButton)
        NSLayoutConstraint.activate([
            createFeatureButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            createFeatureButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            createFeatureButton.widthAnchor.constraint(equalToConstant: 32),
            createFeatureButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        createFeatureButton.addTarget(self, action: #selector(createFeatureButtonTapped), for: .touchUpInside)
    }

    // Width constraint on the cancel button — 0 when hidden, intrinsic when shown.
    // The text field's trailing is chained: tf.trailing + 8 = cb.leading (set programmatically),
    // and cb.trailing = container.trailing - 8 (storyboard). Animating cancelWidthConstraint
    // causes the text field to grow/shrink automatically.
    private var cancelWidthConstraint: NSLayoutConstraint?
    private var textFieldTrailingToCancelConstraint: NSLayoutConstraint?

    private func setupSearchBar() {
        searchBarContainerView.backgroundColor = .Sphinx.Body

        // Style the text field
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search…",
            attributes: [.foregroundColor: UIColor.Sphinx.SecondaryText]
        )
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.tintColor = .Sphinx.SecondaryText   // cursor + clear button
        searchTextField.backgroundColor = .Sphinx.ProfileBG
        searchTextField.layer.cornerRadius = 10
        searchTextField.clipsToBounds = true
        searchTextField.font = UIFont(name: "Roboto-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)
        searchTextField.textColor = .Sphinx.Text
        searchTextField.delegate = self

        // Left padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        searchTextField.leftView = paddingView
        searchTextField.leftViewMode = .always

        // Build the constraint chain: tf.trailing + 8 = cb.leading, cb.width = 0 initially.
        // The storyboard already sets tf.leading=8 and cb.trailing=container.trailing-8.
        let tfToCb = searchTextField.trailingAnchor.constraint(
            equalTo: searchCancelButton.leadingAnchor, constant: -8
        )
        tfToCb.isActive = true
        textFieldTrailingToCancelConstraint = tfToCb

        let cbWidth = searchCancelButton.widthAnchor.constraint(equalToConstant: 0)
        cbWidth.isActive = true
        cancelWidthConstraint = cbWidth

        // Cancel button styling — keep in layout tree, hidden via width=0
        searchCancelButton.setTitle("Cancel", for: .normal)
        searchCancelButton.setTitleColor(.Sphinx.PrimaryBlue, for: .normal)
        searchCancelButton.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)
        searchCancelButton.isHidden = false
        searchCancelButton.clipsToBounds = true   // clips title text when width=0
        searchCancelButton.addTarget(self, action: #selector(cancelSearchTapped), for: .touchUpInside)

        // Disable if no slug
        if workspace.slug == nil {
            searchTextField.isEnabled = false
            searchTextField.placeholder = "Search unavailable"
        }
    }

    /// Animates the cancel button sliding in and the text field shrinking.
    private func showCancelButton() {
        cancelWidthConstraint?.constant = 70   // wide enough for "Cancel"
        UIView.animate(withDuration: 0.25) {
            self.searchBarContainerView.layoutIfNeeded()
        }
    }

    /// Animates the cancel button sliding out and the text field expanding back.
    private func hideCancelButton() {
        cancelWidthConstraint?.constant = 0
        UIView.animate(withDuration: 0.25) {
            self.searchBarContainerView.layoutIfNeeded()
        }
    }

    @objc private func createFeatureButtonTapped() {
        if currentTab == 0 {
            activeFeaturesVC?.createButtonTapped()
        } else if currentTab == 1 {
            activeTasksVC?.createButtonTapped()
        }
    }

    @objc private func cancelSearchTapped() {
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        hideCancelButton()
        dismissSearchOverlay()
    }

    private func setupSegmentedControls() {
        topTabContainer.backgroundColor = .Sphinx.HeaderBG
        topTabSegmentedControl.buttonBackgroundColor = .Sphinx.HeaderBG
        topTabSegmentedControl.selectorViewColor = .Sphinx.PrimaryGreen
        topTabSegmentedControl.configureFromOutlet(
            buttonTitles: ["FEATURES", "TASKS", "GRAPH CHAT"],
            initialIndex: 0,
            delegate: self
        )
        topTabSegmentedControl.tag = 100
    }

    @IBAction func backButtonTouched() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Search Overlay

    private func showSearchOverlay() {
        guard searchVC == nil else { return }
        let vc = WorkspaceSearchViewController(workspace: workspace)
        vc.delegate = self
        searchVC = vc
        addChild(vc)
        // Cover the stack view that contains topTabContainer + containerView
        if let parentView = topTabContainer.superview {
            parentView.addSubview(vc.view)
            vc.view.frame = parentView.bounds
            vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        vc.didMove(toParent: self)
    }

    private func dismissSearchOverlay() {
        searchVC?.updateQuery("")
        searchVC?.willMove(toParent: nil)
        searchVC?.view.removeFromSuperview()
        searchVC?.removeFromParent()
        searchVC = nil

        // Re-show whichever tab child was active while search covered the screen
        if currentTab == 0 {
            activeFeaturesVC?.view.isHidden = false
        } else if currentTab == 1 {
            activeTasksVC?.view.isHidden = false
        } else {
            activeGraphChatVC?.view.isHidden = false
        }
    }
}

// MARK: - UITextFieldDelegate

extension WorkspaceViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard textField == searchTextField else { return }
        showSearchOverlay()
        showCancelButton()
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let current = (textField.text ?? "") as NSString
        let newQuery = current.replacingCharacters(in: range, with: string)
        searchVC?.updateQuery(newQuery)
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        searchTextField.resignFirstResponder()
        hideCancelButton()
        dismissSearchOverlay()
        return true
    }
}

// MARK: - WorkspaceSearchViewControllerDelegate

extension WorkspaceViewController: WorkspaceSearchViewControllerDelegate {

    func didSelectSearchResult(_ result: HiveSearchResultItem) {
        searchTextField.resignFirstResponder()
        newBubbleHelper.showLoadingWheel()

        if result.type == "feature" {
            API.sharedInstance.fetchFeatureDetailWithAuth(
                featureId: result.id,
                callback: { [weak self] feature in
                    guard let self = self, let feature = feature else { return }
                    DispatchQueue.main.async {
                        self.newBubbleHelper.hideLoadingWheel()
                        let planVC = FeaturePlanViewController.instantiate(feature: feature, workspace: self.workspace)
                        self.navigationController?.pushViewController(planVC, animated: true)
                    }
                },
                errorCallback: { [weak self] in
                    DispatchQueue.main.async {
                        self?.newBubbleHelper.hideLoadingWheel()
                    }
                }
            )
        } else if result.type == "task" {
            API.sharedInstance.fetchTaskDetailWithAuth(
                taskId: result.id,
                callback: { [weak self] task in
                    guard let self = self, let task = task else { return }
                    DispatchQueue.main.async {
                        self.newBubbleHelper.hideLoadingWheel()
                        let chatVC = TaskChatViewController.instantiate(task: task, workspaceSlug: self.workspace.slug ?? "", workspaceId: self.workspace.id)
                        self.navigationController?.pushViewController(chatVC, animated: true)
                    }
                },
                errorCallback: { [weak self] in
                    DispatchQueue.main.async {
                        self?.newBubbleHelper.hideLoadingWheel()
                    }
                }
            )
        }
    }
}

// MARK: - HivePusherDelegate

extension WorkspaceViewController: HivePusherDelegate {
    func featureTitleUpdated(featureId: String, newTitle: String) {
        activeFeaturesVC?.handleFeatureTitleUpdated(featureId: featureId, newTitle: newTitle)
    }
    func taskGenerationStatusChanged(status: String, featureId: String) {
        if status == "COMPLETED" {
            activeFeaturesVC?.handleFeatureListShouldRefresh()
        }
    }
    func taskStatusUpdated(taskId: String, status: String, workflowStatus: String?, archived: Bool) {
        activeTasksVC?.handleTaskStatusUpdated(taskId: taskId, status: status, workflowStatus: workflowStatus, archived: archived)
    }
    func prStatusChanged(taskId: String?, prNumber: Int, state: String, artifactStatus: String, prUrl: String?, problemDetails: String?) {
        activeTasksVC?.handlePRStatusChanged(taskId: taskId, prNumber: prNumber, state: state, artifactStatus: artifactStatus, prUrl: prUrl, problemDetails: problemDetails)
    }
    func featureUpdateReceived(featureId: String) {}
    func newMessageReceived(_ message: HiveChatMessage) {}
    func workflowStatusChanged(status: WorkflowStatus) {}
    func taskTitleUpdated(taskId: String, newTitle: String) {}
}

// MARK: - CustomSegmentedControlDelegate

extension WorkspaceViewController: CustomSegmentedControlDelegate {
    func segmentedControlDidSwitch(_ control: CustomSegmentedControl, to index: Int) {
        switchToTab(index)
    }

    private func switchToTab(_ index: Int) {
        currentTab = index
        createFeatureButton.isHidden = (index == 2)

        // Instantiate children lazily, but only make them visible when search is inactive
        let searchActive = searchVC != nil

        activeFeaturesVC?.view.isHidden = true
        activeTasksVC?.view.isHidden = true
        activeGraphChatVC?.view.isHidden = true

        if index == 0 {
            if activeFeaturesVC == nil {
                activeFeaturesVC = WorkspaceFeaturesViewController.instantiate(workspace: workspace)
                addChildVC(activeFeaturesVC)
            }
            // Only reveal if search overlay is not covering the stack
            if !searchActive {
                activeFeaturesVC.view.isHidden = false
            }
        } else if index == 1 {
            if activeTasksVC == nil {
                activeTasksVC = WorkspaceTasksViewController.instantiate(workspace: workspace)
                addChildVC(activeTasksVC)
            }
            if !searchActive {
                activeTasksVC.view.isHidden = false
            }
        } else {
            if activeGraphChatVC == nil {
                activeGraphChatVC = WorkspaceGraphChatViewController.instantiate(workspace: workspace)
                addChildVC(activeGraphChatVC!)
            }
            if !searchActive {
                activeGraphChatVC?.view.isHidden = false
            }
        }
    }

    private func addChildVC(_ child: UIViewController) {
        addChild(child)
        containerView.addSubview(child.view)
        child.view.frame = containerView.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        child.didMove(toParent: self)
    }
}
