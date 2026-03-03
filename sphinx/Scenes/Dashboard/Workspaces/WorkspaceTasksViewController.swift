//
//  WorkspaceTasksViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 03/03/2026.
//  Copyright © 2026 sphinx. All rights reserved.
//
import UIKit

class WorkspaceTasksViewController: UIViewController {
    
    @IBOutlet weak var segmentedControlContainer: UIView!
    @IBOutlet weak var segmentedControl: CustomSegmentedControl!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    
    @IBOutlet weak var emptyStateLabel: UILabel!
    
    private var workspace: Workspace!
    private var tasks: [WorkspaceTask] = []
    private var currentTab: Int = 0 // 0 = Active, 1 = Archived
    private var includeArchived = false
    
    static func instantiate(workspace: Workspace) -> WorkspaceTasksViewController {
        let vc = StoryboardScene.Dashboard.workspaceTasksViewController.instantiate()
        vc.workspace = workspace
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegmentedControls()
        setupTableView()
        loadTasks()
    }
    
    private func setupSegmentedControls() {
        // Configure ACTIVE/ARCHIVED tab (for tasks)
        segmentedControl.configureFromOutlet(
            buttonTitles: ["Active", "Archived"],
            initialIndex: 0,
            delegate: self
        )
        segmentedControl.tag = 200
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .Sphinx.HeaderBG
        tableView.separatorStyle = .none
        tableView.rowHeight = 110
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)

        tableView.register(
            WorkspaceTaskTableViewCell.nib,
            forCellReuseIdentifier: WorkspaceTaskTableViewCell.reuseID
        )
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
    func segmentedControlDidSwitch(_ control: CustomSegmentedControl, to index: Int) {
        includeArchived = (index == 1)
        loadTasks()
    }
}
