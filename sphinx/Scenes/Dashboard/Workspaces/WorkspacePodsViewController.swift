//
//  WorkspacePodsViewController.swift
//  sphinx
//
//  Created on 2025-03-25.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class WorkspacePodsViewController: UIViewController {

    // MARK: - Properties

    private var workspace: Workspace
    private var pods: [WorkspacePod] = []
    private var isLoading = false
    private var hasError = false

    // MARK: - UI

    private lazy var poolStatusLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        l.textColor = .Sphinx.SecondaryText
        l.textAlignment = .center
        l.numberOfLines = 1
        l.isHidden = true
        return l
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .Sphinx.Body
        tv.separatorStyle = .singleLine
        tv.separatorColor = .Sphinx.DividerColor
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 120
        tv.register(WorkspacePodTableViewCell.self, forCellReuseIdentifier: WorkspacePodTableViewCell.reuseID)
        tv.dataSource = self
        tv.delegate = self
        return tv
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.translatesAutoresizingMaskIntoConstraints = false
        ai.hidesWhenStopped = true
        ai.color = .Sphinx.SecondaryText
        return ai
    }()

    private lazy var loadingLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Loading pods capacity"
        l.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        l.textColor = .Sphinx.SecondaryText
        l.textAlignment = .center
        l.isHidden = true
        return l
    }()

    private lazy var emptyStateLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "No pods found"
        l.font = UIFont(name: "Roboto-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)
        l.textColor = .Sphinx.SecondaryText
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    // MARK: - Init

    static func instantiate(workspace: Workspace) -> WorkspacePodsViewController {
        return WorkspacePodsViewController(workspace: workspace)
    }

    private init(workspace: Workspace) {
        self.workspace = workspace
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Sphinx.Body
        setupUI()
        loadPods()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.addSubview(poolStatusLabel)
        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        view.addSubview(loadingLabel)
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            poolStatusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            poolStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            poolStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: poolStatusLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -12),

            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            loadingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            loadingLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Data Loading

    func loadPods() {
        guard let slug = workspace.slug else {
            handlePodsError()
            return
        }

        isLoading = true
        hasError = false
        tableView.isHidden = true
        emptyStateLabel.isHidden = true
        activityIndicator.startAnimating()
        loadingLabel.isHidden = false

        API.sharedInstance.fetchPoolWorkspacesWithAuth(
            workspaceSlug: slug,
            callback: { [weak self] pods, hasWarning in
                DispatchQueue.main.async {
                    self?.handlePodsLoaded(pods, hasWarning)
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.handlePodsError()
                }
            }
        )

        fetchPoolStatus(slug: slug)
    }

    private func fetchPoolStatus(slug: String) {
        API.sharedInstance.fetchPoolStatusWithAuth(
            workspaceSlug: slug,
            callback: { [weak self] queuedCount, unusedVms in
                DispatchQueue.main.async {
                    self?.poolStatusLabel.text = "\(queuedCount) tasks in workspace queue · \(unusedVms) pods available"
                    self?.poolStatusLabel.isHidden = false
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.poolStatusLabel.isHidden = true
                }
            }
        )
    }

    private func handlePodsLoaded(_ pods: [WorkspacePod], _ hasWarning: Bool) {
        isLoading = false
        activityIndicator.stopAnimating()
        loadingLabel.isHidden = true

        self.pods = pods

        if pods.isEmpty {
            tableView.isHidden = true
            emptyStateLabel.text = "No pods found"
            emptyStateLabel.isHidden = false
        } else {
            emptyStateLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }

    private func handlePodsError() {
        isLoading = false
        activityIndicator.stopAnimating()
        loadingLabel.isHidden = true
        tableView.isHidden = true
        emptyStateLabel.text = "Failed to load pods"
        emptyStateLabel.isHidden = false
    }
}

// MARK: - UITableViewDataSource

extension WorkspacePodsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pods.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: WorkspacePodTableViewCell.reuseID,
            for: indexPath
        ) as? WorkspacePodTableViewCell else {
            return UITableViewCell()
        }
        cell.configure(with: pods[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension WorkspacePodsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
