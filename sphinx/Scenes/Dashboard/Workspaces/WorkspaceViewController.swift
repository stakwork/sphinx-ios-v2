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
    }

    private func setupHeader() {
        headerView.backgroundColor = .Sphinx.Body
        viewTitle.font = UIFont(name: "Roboto-Medium", size: 14)
        viewTitle.textColor = .Sphinx.Text
        viewTitle.text = workspace.name.uppercased()
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

extension WorkspaceViewController: CustomSegmentedControlDelegate {
    func segmentedControlDidSwitch(_ control: CustomSegmentedControl, to index: Int) {
        switchToTab(index)
    }
    
    private func switchToTab(_ index: Int) {
        currentTab = index

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
