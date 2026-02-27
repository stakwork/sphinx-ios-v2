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
    @IBOutlet weak var segmentedControlContainer: UIView!
    @IBOutlet weak var segmentedControl: CustomSegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    // Programmatically created views
    private lazy var topTabContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .Sphinx.Body
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private lazy var topTabSegmentedControl: CustomSegmentedControl = {
        let control = CustomSegmentedControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private lazy var featuresContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .Sphinx.Body
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

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
        setupTopTabUI()
        setupSegmentedControl()
        setupTableView()
        setupLoadingAndEmpty()
        loadTasks()
    }
    
    private func setupTopTabUI() {
        // Add topTabContainer below the header
        view.addSubview(topTabContainer)
        topTabContainer.addSubview(topTabSegmentedControl)
        view.addSubview(featuresContainerView)
        
        NSLayoutConstraint.activate([
            // Top tab container - below header
            topTabContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            topTabContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topTabContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topTabContainer.heightAnchor.constraint(equalToConstant: 50),
            
            // Segmented control inside container
            topTabSegmentedControl.topAnchor.constraint(equalTo: topTabContainer.topAnchor),
            topTabSegmentedControl.leadingAnchor.constraint(equalTo: topTabContainer.leadingAnchor),
            topTabSegmentedControl.trailingAnchor.constraint(equalTo: topTabContainer.trailingAnchor),
            topTabSegmentedControl.bottomAnchor.constraint(equalTo: topTabContainer.bottomAnchor),
            
            // Features container - same position as tableView
            featuresContainerView.topAnchor.constraint(equalTo: segmentedControlContainer.bottomAnchor),
            featuresContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            featuresContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            featuresContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Update segmentedControlContainer constraint to be below topTabContainer
        // (This assumes the storyboard constraint exists - we're replacing its reference)
        segmentedControlContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedControlContainer.topAnchor.constraint(equalTo: topTabContainer.bottomAnchor),
            segmentedControlContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentedControlContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            segmentedControlContainer.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func setupHeader() {
        headerView.backgroundColor = .Sphinx.Body
        viewTitle.font = UIFont(name: "Roboto-Medium", size: 14)
        viewTitle.textColor = .Sphinx.Text
        viewTitle.text = workspace.name.uppercased()
    }

    private func setupSegmentedControl() {
        // Configure top-level TASKS/FEATURES tab
        topTabSegmentedControl.configureFromOutlet(
            buttonTitles: ["TASKS", "FEATURES"],
            initialIndex: 0,
            delegate: self
        )
        topTabSegmentedControl.tag = 100
        
        // Configure ACTIVE/ARCHIVED tab (for tasks)
        segmentedControl.configureFromOutlet(
            buttonTitles: ["ACTIVE", "ARCHIVED"],
            initialIndex: 0,
            delegate: self
        )
        segmentedControl.tag = 200
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
        // Legacy method - kept for compatibility
        // Will be called by other segmented controls that don't use the new method
    }
    
    func segmentedControl(_ control: CustomSegmentedControl, didSwitchTo index: Int) {
        if control == topTabSegmentedControl {
            // Top-level TASKS/FEATURES switch
            switchToTab(index)
        } else if control == segmentedControl {
            // ACTIVE/ARCHIVED switch for tasks
            includeArchived = (index == 1)
            loadTasks()
        }
    }
    
    private func switchToTab(_ index: Int) {
        currentTab = index
        
        if index == 0 {
            // Show Tasks
            tableView.isHidden = false
            segmentedControlContainer.isHidden = false
            featuresContainerView.isHidden = true
            loadTasks()
        } else {
            // Show Features
            tableView.isHidden = true
            segmentedControlContainer.isHidden = true
            
                featuresContainerView.isHidden = false
                
                // Lazy-load features VC
                if activeFeaturesVC == nil {
                    let featuresVC = WorkspaceFeaturesViewController.instantiate(workspace: workspace)
                    addChild(featuresVC)
                    featuresContainerView.addSubview(featuresVC.view)
                    featuresVC.view.frame = featuresContainerView.bounds
                    featuresVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    featuresVC.didMove(toParent: self)
                    activeFeaturesVC = featuresVC
                }
        }
    }
}
