//
//  WorkspaceSearchViewController.swift
//  sphinx
//
//  Created on 2026-03-07.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import UIKit
import SwiftyJSON

protocol WorkspaceSearchViewControllerDelegate: AnyObject {
    func didSelectSearchResult(_ result: HiveSearchResultItem)
}

class WorkspaceSearchViewController: UIViewController {

    // MARK: - Properties

    var workspace: Workspace
    weak var delegate: WorkspaceSearchViewControllerDelegate?

    private var searchTimer: Timer?
    private var results = HiveSearchResults(json: JSON([:]))
    private var isLoading = false

    // MARK: - Views

    private lazy var promptLabel: UILabel = {
        let label = UILabel()
        label.text = "Search over features and tasks in the workspace"
        label.font = UIFont(name: "Roboto-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        label.textColor = .Sphinx.SecondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var resultsTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .Sphinx.Body
        tv.separatorStyle = .none
        tv.keyboardDismissMode = .onDrag
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isHidden = true
        return tv
    }()

    private lazy var noResultsLabel: UILabel = {
        let label = UILabel()
        label.text = "No results found"
        label.font = UIFont(name: "Roboto-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        label.textColor = .Sphinx.SecondaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .Sphinx.SecondaryText
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Init

    init(workspace: Workspace) {
        self.workspace = workspace
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupTableView()
    }

    // MARK: - Setup

    private func setupViews() {
        view.backgroundColor = .Sphinx.Body

        view.addSubview(promptLabel)
        view.addSubview(resultsTableView)
        view.addSubview(noResultsLabel)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            // Prompt label — near the top so it clears the keyboard
            promptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            promptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            promptLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),

            // Results table — full coverage
            resultsTableView.topAnchor.constraint(equalTo: view.topAnchor),
            resultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            resultsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // No-results label — centred
            noResultsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            noResultsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            noResultsLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            // Loading indicator — centred
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupTableView() {
        resultsTableView.dataSource = self
        resultsTableView.delegate = self
        resultsTableView.register(HiveSearchResultCell.nib, forCellReuseIdentifier: HiveSearchResultCell.reuseID)
    }

    // MARK: - Public API

    func updateQuery(_ query: String) {
        searchTimer?.invalidate()
        searchTimer = nil

        if query.isEmpty {
            results = HiveSearchResults(json: JSON([:]))
            resultsTableView.reloadData()
            resultsTableView.isHidden = true
            noResultsLabel.isHidden = true
            loadingIndicator.stopAnimating()
            promptLabel.isHidden = false
            return
        }

        promptLabel.isHidden = true
        loadingIndicator.startAnimating()

        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.performSearch(query: query)
        }
    }

    // MARK: - Private

    private func performSearch(query: String) {
        let slug = workspace.slug ?? ""
        guard !slug.isEmpty else {
            loadingIndicator.stopAnimating()
            return
        }

        API.sharedInstance.searchWorkspaceWithAuth(
            slug: slug,
            query: query,
            callback: { [weak self] searchResults in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingIndicator.stopAnimating()
                    self.results = searchResults
                    self.resultsTableView.reloadData()

                    if searchResults.total == 0 {
                        self.resultsTableView.isHidden = true
                        self.noResultsLabel.isHidden = false
                    } else {
                        self.noResultsLabel.isHidden = true
                        self.resultsTableView.isHidden = false
                    }
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.loadingIndicator.stopAnimating()
                }
            }
        )
    }
}

// MARK: - UITableViewDataSource

extension WorkspaceSearchViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? results.features.count : results.tasks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: HiveSearchResultCell.reuseID,
            for: indexPath
        ) as? HiveSearchResultCell else {
            return UITableViewCell()
        }

        let item = indexPath.section == 0
            ? results.features[indexPath.row]
            : results.tasks[indexPath.row]

        cell.configure(with: item)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension WorkspaceSearchViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let count = section == 0 ? results.features.count : results.tasks.count
        guard count > 0 else { return nil }

        let container = UIView()
        container.backgroundColor = .Sphinx.HeaderBG

        let label = UILabel()
        label.text = section == 0 ? "FEATURES" : "TASKS"
        label.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .Sphinx.SecondaryText
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let count = section == 0 ? results.features.count : results.tasks.count
        return count > 0 ? 32 : 0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = indexPath.section == 0
            ? results.features[indexPath.row]
            : results.tasks[indexPath.row]
        delegate?.didSelectSearchResult(item)
    }
}
