//
//  WorkspaceTasksViewController.swift
//  sphinx
//
//  Created on 2/23/26.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

class WorkspaceTasksViewController: PopHandlerViewController {

    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var viewTitle: UILabel!
    @IBOutlet weak var topTabContainer: UIView!
    @IBOutlet weak var topTabSegmentedControl: CustomSegmentedControl!
    @IBOutlet weak var segmentedControlContainer: UIView!
    @IBOutlet weak var segmentedControl: CustomSegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var featuresContainerView: UIView!

    private var workspace: Workspace!
    private var tasks: [WorkspaceTask] = []
    private var activeFeaturesVC: WorkspaceFeaturesViewController?
    private var currentTab: Int = 0 // 0 = Tasks, 1 = Features
    private var includeArchived = false

    private lazy var loadingWheel: UIActivityIndicatorView = {
        let iv = UIActivityIndicatorView(style: .medium)
        iv.hidesWhenStopped = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var emptyStateLabel: UILabel = {
        let l = UILabel()
        l.text = "NO RESULTS FOUND"
        l.textColor = .Sphinx.SecondaryText
        l.font = UIFont(name: "Roboto-Regular", size: 16)
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    static func instantiate(workspace: Workspace) -> WorkspaceTasksViewController {
        let vc = StoryboardScene.Dashboard.workspaceTasksViewController.instantiate()
        vc.workspace = workspace
        vc.popOnSwipeEnabled = true
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupSegmentedControl()
        setupTableView()
        setupLoadingAndEmpty()
        loadTasks()
    }

    private func setupHeader() {
        headerView.backgroundColor = .Sphinx.Body
        viewTitle.font = UIFont(name: "Roboto-Medium", size: 14)
        viewTitle.textColor = .Sphinx.Text
        viewTitle.text = workspace.name.uppercased()
    }

    private func setupSegmentedControl() {
        // Configure top-level TASKS/FEATURES tab
        if topTabSegmentedControl != nil {
            topTabSegmentedControl.buttonTitles = ["TASKS", "FEATURES"]
            topTabSegmentedControl.delegate = self
            topTabSegmentedControl.tag = 100 // Tag to identify which control sent event
        }
        
        // Configure ACTIVE/ARCHIVED tab (for tasks)
        segmentedControl.configureFromOutlet(
            buttonTitles: ["ACTIVE", "ARCHIVED"],
            initialIndex: 0,
            delegate: self
        )
        segmentedControl.tag = 200 // Tag to identify which control sent event
        
        // Initially hide features container
        if featuresContainerView != nil {
            featuresContainerView.isHidden = true
        }
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .Sphinx.Body
        tableView.separatorStyle = .none
        tableView.rowHeight = 110
        
        tableView.register(
            WorkspaceTaskTableViewCell.nib,
            forCellReuseIdentifier: WorkspaceTaskTableViewCell.reuseID
        )
    }

    private func setupLoadingAndEmpty() {
        view.addSubview(loadingWheel)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            loadingWheel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingWheel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    @IBAction func backButtonTouched() {
        navigationController?.popViewController(animated: true)
    }

    private var isLoading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(
                loading: isLoading,
                loadingWheel: loadingWheel,
                loadingWheelColor: .Sphinx.Text
            )
            tableView.isHidden = isLoading
            emptyStateLabel.isHidden = !tasks.isEmpty || isLoading
        }
    }

    func loadTasks() {
        guard !isLoading else { return }
        isLoading = true
        API.sharedInstance.fetchTasksWithAuth(
            workspaceId: workspace.id,
            includeArchived: includeArchived,
            callback: { [weak self] tasks in
                DispatchQueue.main.async {
                    self?.tasks = tasks
                    self?.tableView.reloadData()
                    self?.isLoading = false
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.tasks = []
                    self?.tableView.reloadData()
                    self?.isLoading = false
                }
            }
        )
    }
}

extension WorkspaceTasksViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { tasks.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: WorkspaceTaskTableViewCell.reuseID, for: indexPath
        ) as? WorkspaceTaskTableViewCell else { return UITableViewCell() }
        cell.configure(with: tasks[indexPath.row], isLastRow: indexPath.row == tasks.count - 1)
        return cell
    }
}

extension WorkspaceTasksViewController: CustomSegmentedControlDelegate {
    func segmentedControlDidSwitch(to index: Int) {
        // We have two segmented controls - need to handle both
        // Since we can't identify sender, use currentTab state
        
        // Check if we have the top tab control (TASKS/FEATURES)
        if topTabSegmentedControl != nil && featuresContainerView != nil {
            // First check if this is switching the top-level tab
            // If index matches our current displayed state, it's the sub-tab
            if (index == 0 || index == 1) && (tableView.isHidden == (index == 0)) {
                // This is the top-level TASKS/FEATURES switch
                switchToTab(index)
                return
            }
        }
        
        // Otherwise it's the ACTIVE/ARCHIVED switch for tasks
        includeArchived = (index == 1)
        loadTasks()
    }
    
    private func switchToTab(_ index: Int) {
        currentTab = index
        
        if index == 0 {
            // Show Tasks
            tableView.isHidden = false
            segmentedControlContainer.isHidden = false
            if featuresContainerView != nil {
                featuresContainerView.isHidden = true
            }
            loadTasks()
        } else {
            // Show Features
            tableView.isHidden = true
            segmentedControlContainer.isHidden = true
            
            if let containerView = featuresContainerView {
                containerView.isHidden = false
                
                // Lazy-load features VC
                if activeFeaturesVC == nil {
                    let featuresVC = WorkspaceFeaturesViewController.instantiate(
                        workspace: workspace,
                        navigationController: navigationController
                    )
                    addChild(featuresVC)
                    containerView.addSubview(featuresVC.view)
                    featuresVC.view.frame = containerView.bounds
                    featuresVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    featuresVC.didMove(toParent: self)
                    activeFeaturesVC = featuresVC
                }
            }
        }
    }
}
