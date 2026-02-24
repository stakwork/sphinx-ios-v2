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

    private var workspace: Workspace!
    private var tasks: [WorkspaceTask] = []
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
        segmentedControl.configureFromOutlet(
            buttonTitles: ["ACTIVE", "ARCHIVED"],
            initialIndex: 0,
            delegate: self
        )
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
        includeArchived = (index == 1)
        loadTasks()
    }
}
