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
        segmentedControlContainer.backgroundColor = .Sphinx.HeaderBG
        segmentedControl.buttonBackgroundColor = .Sphinx.HeaderBG
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
        tableView.backgroundColor = .Sphinx.Body
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
            callback: { [weak self] tasks, _ in
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
        cell.onPRBadgeTapped = { url in UIApplication.shared.open(url) }
        cell.onArchiveTapped = { [weak self] in
            guard let self else { return }
            let task = self.tasks[indexPath.row]
            AlertHelper.showTwoOptionsAlert(
                title: "Archive Task",
                message: "Archive \"\(task.title)\"?",
                confirmButtonTitle: "Archive",
                confirm: {
                    self.tasks.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    API.sharedInstance.archiveTaskWithAuth(taskId: task.id) {
                        DispatchQueue.main.async { self.loadTasks() }
                    } errorCallback: {
                        DispatchQueue.main.async { self.loadTasks() }
                    }
                }
            )
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let task = tasks[indexPath.row]
        let chatVC = TaskChatViewController.instantiate(task: task)
        navigationController?.pushViewController(chatVC, animated: true)
    }
}

extension WorkspaceTasksViewController: CustomSegmentedControlDelegate {
    func segmentedControlDidSwitch(_ control: CustomSegmentedControl, to index: Int) {
        includeArchived = (index == 1)
        loadTasks()
    }
}

extension WorkspaceTasksViewController {
    func handleTaskStatusUpdated(taskId: String, status: String, workflowStatus: String?, archived: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        tasks[index].status = status
        tasks[index].workflowStatus = workflowStatus

        let indexPath = IndexPath(row: index, section: 0)
        let shouldRemove = (!includeArchived && archived) || (includeArchived && !archived)

        if shouldRemove {
            tasks.remove(at: index)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        } else {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    func handlePRStatusChanged(taskId: String?, prNumber: Int, state: String, artifactStatus: String, prUrl: String?, problemDetails: String?) {
        let index: Int?
        if let tid = taskId {
            index = tasks.firstIndex(where: { $0.id == tid }) ?? tasks.firstIndex(where: { $0.prNumber == prNumber })
        } else {
            index = tasks.firstIndex(where: { $0.prNumber == prNumber })
        }
        guard let idx = index else { return }
        tasks[idx].prStatus = artifactStatus
        tasks[idx].prUrl = prUrl
        tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
    }
}
