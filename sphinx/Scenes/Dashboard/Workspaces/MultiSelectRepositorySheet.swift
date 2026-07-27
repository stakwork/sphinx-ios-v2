//
//  MultiSelectRepositorySheet.swift
//  sphinx
//
//  Created on 2026-06-05.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

class MultiSelectRepositorySheet: UIViewController {

    // MARK: - Properties

    private let repositories: [WorkspaceRepository]
    private var selectedIds: Set<String>
    private let onDone: ([String]) -> Void

    private var tableView: UITableView!
    private var headerView: UIView!
    private var titleLabel: UILabel!
    private var doneButton: UIButton!

    // MARK: - Init

    init(repositories: [WorkspaceRepository], selectedIds: [String], onDone: @escaping ([String]) -> Void) {
        self.repositories = repositories
        self.selectedIds = Set(selectedIds)
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        view.backgroundColor = UIColor.Sphinx.Body

        // Header
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor.Sphinx.Body
        view.addSubview(headerView)

        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Select Repositories"
        titleLabel.font = UIFont(name: "Roboto-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17)
        titleLabel.textColor = UIColor.Sphinx.Text
        headerView.addSubview(titleLabel)

        doneButton = UIButton(type: .system)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(UIColor.Sphinx.PrimaryBlue, for: .normal)
        doneButton.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        headerView.addSubview(doneButton)

        // Separator
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.Sphinx.LightDivider
        headerView.addSubview(separator)

        // Table View
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = UIColor.Sphinx.Body
        tableView.separatorColor = UIColor.Sphinx.LightDivider
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RepoCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: -1),

            doneButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        let result = Array(selectedIds)
        onDone(result)
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension MultiSelectRepositorySheet: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return repositories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RepoCell", for: indexPath)
        let repo = repositories[indexPath.row]
        cell.backgroundColor = UIColor.Sphinx.Body
        cell.textLabel?.text = repo.name
        cell.textLabel?.font = UIFont(name: "Roboto-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)
        cell.textLabel?.textColor = UIColor.Sphinx.Text
        cell.accessoryType = selectedIds.contains(repo.id) ? .checkmark : .none
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let repo = repositories[indexPath.row]
        if selectedIds.contains(repo.id) {
            selectedIds.remove(repo.id)
        } else {
            selectedIds.insert(repo.id)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}
