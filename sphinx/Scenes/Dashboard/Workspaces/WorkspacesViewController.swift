//
//  WorkspacesViewController.swift
//  sphinx
//
//  Created on 2025-02-18.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

protocol WorkspacesViewControllerDelegate: AnyObject {
    func viewControllerContentScrolled(scrollView: UIScrollView)
}

class WorkspacesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    weak var delegate: WorkspacesViewControllerDelegate?

    private var workspaces: [Workspace] = []

    private let refreshControl = UIRefreshControl()

    private var isLoading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(
                loading: isLoading,
                loadingWheel: loadingWheel,
                loadingWheelColor: UIColor.Sphinx.Text
            )
            tableView.isHidden = isLoading
            updateEmptyState()
        }
    }

    private lazy var loadingWheel: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No workspaces found"
        label.textColor = .Sphinx.SecondaryText
        label.font = UIFont(name: "Roboto-Regular", size: 16)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    // MARK: - Instantiation

    static func instantiate(
        delegate: WorkspacesViewControllerDelegate? = nil
    ) -> WorkspacesViewController {
        let viewController = StoryboardScene.Dashboard.workspacesViewController.instantiate()
        viewController.delegate = delegate
        return viewController
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLoadingWheel()
        setupEmptyStateLabel()
        loadWorkspaces()
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .Sphinx.DashboardHeader
        tableView.separatorStyle = .none
        tableView.rowHeight = 75
        tableView.estimatedRowHeight = 75

        tableView.register(
            WorkspaceTableViewCell.nib,
            forCellReuseIdentifier: WorkspaceTableViewCell.reuseID
        )

        refreshControl.addTarget(
            self,
            action: #selector(handleRefresh),
            for: .valueChanged
        )
        tableView.refreshControl = refreshControl

        addTableBottomInset()
    }

    private func addTableBottomInset() {
        let windowInsets = getWindowInsets()
        let bottomBarHeight: CGFloat = 64

        tableView.contentInset.bottom = bottomBarHeight + windowInsets.bottom
        tableView.verticalScrollIndicatorInsets.bottom = bottomBarHeight + windowInsets.bottom
    }

    private func setupLoadingWheel() {
        view.addSubview(loadingWheel)

        let bottomBarOffset: CGFloat = 60

        NSLayoutConstraint.activate([
            loadingWheel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingWheel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -bottomBarOffset)
        ])
    }

    private func setupEmptyStateLabel() {
        view.addSubview(emptyStateLabel)

        let bottomBarOffset: CGFloat = 60

        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -bottomBarOffset)
        ])
    }

    private func updateEmptyState() {
        emptyStateLabel.isHidden = !workspaces.isEmpty || isLoading
    }

    // MARK: - Data Loading

    private func loadWorkspaces() {
        guard !isLoading else { return }

        isLoading = true

        API.sharedInstance.fetchWorkspacesWithAuth(
            callback: { [weak self] workspaces in
                DispatchQueue.main.async {
                    self?.workspaces = workspaces
                    self?.tableView.reloadData()
                    self?.refreshControl.endRefreshing()
                    self?.isLoading = false
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.workspaces = []
                    self?.tableView.reloadData()
                    self?.refreshControl.endRefreshing()
                    self?.isLoading = false
                }
            }
        )
    }

    @objc private func handleRefresh() {
        loadWorkspaces()
    }

    // MARK: - Public Methods

    func updateWorkspaces(_ newWorkspaces: [Workspace]) {
        workspaces = newWorkspaces
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension WorkspacesViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return workspaces.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: WorkspaceTableViewCell.reuseID,
            for: indexPath
        ) as? WorkspaceTableViewCell else {
            return UITableViewCell()
        }

        let workspace = workspaces[indexPath.row]
        let isLastRow = indexPath.row == workspaces.count - 1
        cell.configure(with: workspace, isLastRow: isLastRow)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension WorkspacesViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let workspace = workspaces[indexPath.row]
        // TODO: Handle workspace selection - navigate to workspace detail
        print("Selected workspace: \(workspace.name)")
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.viewControllerContentScrolled(scrollView: scrollView)
    }
}
