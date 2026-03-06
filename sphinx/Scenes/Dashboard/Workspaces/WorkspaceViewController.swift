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
    
    @IBOutlet weak var topTabContainer: UIView!
    @IBOutlet weak var topTabSegmentedControl: CustomSegmentedControl!
    
    @IBOutlet weak var containerView: UIView!

    private var workspace: Workspace!
    private var currentTab: Int = 0 // 0 = Features, 1 = Tasks
    
    private var activeFeaturesVC: WorkspaceFeaturesViewController!
    private var activeTasksVC: WorkspaceTasksViewController!
    private var hasAppeared = false

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
        setupSegmentedControls()
        switchToTab(0)
        HivePusherManager.shared.delegate = self
        HivePusherManager.shared.connect(workspaceId: workspace.id, workspaceSlug: workspace.slug)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        HivePusherManager.shared.delegate = self
        HivePusherManager.shared.connect(workspaceId: workspace.id, workspaceSlug: workspace.slug)
        if hasAppeared {
            if currentTab == 0 {
                activeFeaturesVC?.loadFeatures()
            } else {
                activeTasksVC?.loadTasks()
            }
        } else {
            hasAppeared = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            HivePusherManager.shared.disconnect()
        }
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

    @objc private func createFeatureButtonTapped() {
        activeFeaturesVC?.createButtonTapped()
    }

    private func setupSegmentedControls() {
        topTabContainer.backgroundColor = .Sphinx.HeaderBG
        topTabSegmentedControl.buttonBackgroundColor = .Sphinx.HeaderBG
        topTabSegmentedControl.selectorViewColor = .Sphinx.PrimaryGreen
        topTabSegmentedControl.configureFromOutlet(
            buttonTitles: ["FEATURES", "TASKS"],
            initialIndex: 0,
            delegate: self
        )
        topTabSegmentedControl.tag = 100
    }

    @IBAction func backButtonTouched() {
        navigationController?.popViewController(animated: true)
    }
}

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

extension WorkspaceViewController: CustomSegmentedControlDelegate {
    func segmentedControlDidSwitch(_ control: CustomSegmentedControl, to index: Int) {
        switchToTab(index)
    }
    
    private func switchToTab(_ index: Int) {
        currentTab = index
        createFeatureButton.isHidden = (index != 0)

        // Hide all children instead of removing
        activeTasksVC?.view.isHidden = true
        activeFeaturesVC?.view.isHidden = true

        if index == 0 {
            if activeFeaturesVC == nil {
                activeFeaturesVC = WorkspaceFeaturesViewController.instantiate(workspace: workspace)
                addChildVC(activeFeaturesVC)
            }
            activeFeaturesVC.view.isHidden = false
        } else {
            if activeTasksVC == nil {
                activeTasksVC = WorkspaceTasksViewController.instantiate(workspace: workspace)
                addChildVC(activeTasksVC)
            }
            activeTasksVC.view.isHidden = false
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
