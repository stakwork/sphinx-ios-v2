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

    private var currentPage = 1
    private var totalPages = 1
    private weak var paginationView: PaginationControlView?
    private var paginationHasBeenBuilt = false
    
    static func instantiate(workspace: Workspace) -> WorkspaceTasksViewController {
        let vc = StoryboardScene.Dashboard.workspaceTasksViewController.instantiate()
        vc.workspace = workspace
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSegmentedControls()
        setupTableView()
        setupPaginationView()
        loadTasks()
    }

    private func setupPaginationView() {
        let pagination = PaginationControlView()
        pagination.delegate = self
        pagination.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pagination)

        NSLayoutConstraint.activate([
            pagination.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pagination.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            pagination.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            pagination.heightAnchor.constraint(equalToConstant: 56)
        ])

        // Re-pin tableView bottom to pagination view top (storyboard bottom-to-safeArea removed)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        // Remove any existing bottom constraint from storyboard
        if let existing = tableView.constraints.first(where: {
            $0.firstAttribute == .bottom || $0.secondAttribute == .bottom
        }) {
            tableView.removeConstraint(existing)
        }
        // Also check superview constraints
        view.constraints
            .filter { c in
                (c.firstItem === tableView && c.firstAttribute == .bottom) ||
                (c.secondItem === tableView && c.secondAttribute == .bottom)
            }
            .forEach { view.removeConstraint($0) }

        tableView.bottomAnchor.constraint(equalTo: pagination.topAnchor, constant: -8).isActive = true

        paginationView = pagination
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
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 8))

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
            if !paginationHasBeenBuilt {
                paginationView?.isHidden = isLoading
            }
            emptyStateLabel.isHidden = !tasks.isEmpty || isLoading
        }
    }

    func loadTasks(showLoading: Bool = true) {
        guard !isLoading else { return }
        if showLoading { isLoading = true }
        
        API.sharedInstance.fetchTasksWithAuth(
            workspaceId: workspace.id,
            includeArchived: includeArchived,
            page: currentPage,
            callback: { [weak self] tasks, info in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.tasks = tasks
                    self.totalPages = info.totalPages
                    self.tableView.reloadData()
                    self.paginationView?.configure(currentPage: self.currentPage, totalPages: info.totalPages)
                    self.paginationHasBeenBuilt = true
                    self.isLoading = false
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
                        DispatchQueue.main.async { self.loadTasks(showLoading: false) }
                    } errorCallback: {
                        DispatchQueue.main.async { self.loadTasks(showLoading: false) }
                    }
                }
            )
        }
        cell.onRetryWorkflowTapped = { [weak self] in
            guard let self else { return }
            let task = self.tasks[indexPath.row]
            API.sharedInstance.retryTaskWorkflowWithAuth(taskId: task.id, callback: {}, errorCallback: {})
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let task = tasks[indexPath.row]
        let chatVC = TaskChatViewController.instantiate(task: task, workspaceSlug: workspace.slug ?? "")
        navigationController?.pushViewController(chatVC, animated: true)
    }
}

extension WorkspaceTasksViewController: CustomSegmentedControlDelegate {
    func segmentedControlDidSwitch(_ control: CustomSegmentedControl, to index: Int) {
        includeArchived = (index == 1)
        currentPage = 1
        paginationHasBeenBuilt = false
        loadTasks()
    }
}

extension WorkspaceTasksViewController: PaginationControlViewDelegate {
    func paginationControlView(_ view: PaginationControlView, didSelectPage page: Int) {
        currentPage = page
        loadTasks()
        tableView.setContentOffset(.zero, animated: false)
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
