//
//  HiveConfigurationViewController.swift
//  sphinx
//
//  Created on 2025-02-25.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class HiveNotificationPreferencesViewController: UIViewController {

    // MARK: - Notification type definitions
    static let notificationKeys: [(key: String, label: String)] = [
        ("TASK_ASSIGNED",               "Task Assigned"),
        ("FEATURE_ASSIGNED",            "Feature Assigned"),
        ("PLAN_AWAITING_CLARIFICATION", "Plan Awaiting Clarification"),
        ("PLAN_AWAITING_APPROVAL",      "Plan Awaiting Approval"),
        ("PLAN_TASKS_GENERATED",        "Plan Tasks Generated"),
        ("WORKFLOW_HALTED",             "Workflow Halted"),
        ("FEATURE_COMPLETED",           "Feature Completed"),
        ("FEATURE_DEPLOYED_PRODUCTION", "Feature Deployed to Production"),
        ("TASK_PR_MERGED",              "Task PR Merged"),
        ("GRAPH_CHAT_RESPONSE",         "Graph Chat Response"),
        ("WORKSPACE_ACCESS_REQUEST",    "Workspace Access Request"),
    ]

    static let defaultPreferences: [String: Bool] = [
        "TASK_ASSIGNED": true,
        "FEATURE_ASSIGNED": true,
        "PLAN_AWAITING_CLARIFICATION": true,
        "PLAN_AWAITING_APPROVAL": true,
        "PLAN_TASKS_GENERATED": true,
        "WORKFLOW_HALTED": true,
        "FEATURE_COMPLETED": true,
        "FEATURE_DEPLOYED_PRODUCTION": true,
        "TASK_PR_MERGED": true,
        "GRAPH_CHAT_RESPONSE": false,
        "WORKSPACE_ACCESS_REQUEST": true,
    ]

    // MARK: - UI
    private var viewTitle: UILabel!
    private var closeIconLabel: UILabel!
    private var closeButton: UIButton!
    private var loadingWheel: UIActivityIndicatorView!
    private var errorLabel: UILabel!
    private var tableView: UITableView!
    private var saveButton: UIButton!
    private var saveLoadingWheel: UIActivityIndicatorView!

    // MARK: - State
    private var preferences: [String: Bool] = [:]

    static func instantiate() -> HiveNotificationPreferencesViewController {
        return HiveNotificationPreferencesViewController()
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        loadPreferences()
    }

    // MARK: - Setup

    private func setupViews() {
        view.backgroundColor = UIColor.Sphinx.Body

        // Header View
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        view.addSubview(headerView)

        // Title Label
        viewTitle = UILabel()
        viewTitle.translatesAutoresizingMaskIntoConstraints = false
        viewTitle.text = "NOTIFICATION PREFERENCES"
        viewTitle.textAlignment = .center
        viewTitle.font = UIFont(name: "Montserrat-SemiBold", size: 14)
        viewTitle.textColor = UIColor.Sphinx.Text
        headerView.addSubview(viewTitle)

        // Close Icon Label (Material Icons)
        closeIconLabel = UILabel()
        closeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        closeIconLabel.text = ""
        closeIconLabel.font = UIFont(name: "MaterialIcons-Regular", size: 20)
        closeIconLabel.textColor = UIColor.Sphinx.PrimaryRed
        headerView.addSubview(closeIconLabel)

        // Close Button
        closeButton = UIButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTouched), for: .touchUpInside)
        headerView.addSubview(closeButton)

        // Loading Wheel (fetch)
        loadingWheel = UIActivityIndicatorView(style: .medium)
        loadingWheel.translatesAutoresizingMaskIntoConstraints = false
        loadingWheel.hidesWhenStopped = true
        view.addSubview(loadingWheel)

        // Error Label
        errorLabel = UILabel()
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Could not load preferences.\nPlease check your connection."
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont(name: "Roboto-Regular", size: 16)
        errorLabel.textColor = UIColor.Sphinx.SecondaryText
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        view.addSubview(errorLabel)

        // Table View
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.Sphinx.Body
        tableView.isHidden = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PreferenceCell")
        view.addSubview(tableView)

        // Save Button
        saveButton = UIButton()
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("SAVE", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = UIFont(name: "Montserrat-SemiBold", size: 14)
        saveButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        saveButton.layer.cornerRadius = 25
        saveButton.clipsToBounds = true
        saveButton.isHidden = true
        saveButton.addTarget(self, action: #selector(saveButtonTouched), for: .touchUpInside)
        view.addSubview(saveButton)

        // Save Loading Wheel (overlaid on save button)
        saveLoadingWheel = UIActivityIndicatorView(style: .medium)
        saveLoadingWheel.translatesAutoresizingMaskIntoConstraints = false
        saveLoadingWheel.hidesWhenStopped = true
        saveLoadingWheel.color = .white
        view.addSubview(saveLoadingWheel)

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Header View
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            // Title Label
            viewTitle.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            viewTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Close Button
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 50),

            // Close Icon
            closeIconLabel.centerXAnchor.constraint(equalTo: closeButton.centerXAnchor),
            closeIconLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            // Loading Wheel (fetch)
            loadingWheel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingWheel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 25),

            // Error Label
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 25),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            // Save Button
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),

            // Save Loading Wheel
            saveLoadingWheel.centerXAnchor.constraint(equalTo: saveButton.centerXAnchor),
            saveLoadingWheel.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),

            // Table View (above save button)
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -8),
        ])

        viewTitle.addTextSpacing(value: 2)
    }

    // MARK: - Data Loading

    private func loadPreferences() {
        loadingWheel.startAnimating()
        tableView.isHidden = true
        saveButton.isHidden = true
        errorLabel.isHidden = true

        API.sharedInstance.fetchNotificationPreferencesWithAuth(
            callback: { [weak self] prefs in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingWheel.stopAnimating()
                    var merged = Self.defaultPreferences
                    for (k, v) in prefs { merged[k] = v }
                    self.preferences = merged
                    self.tableView.isHidden = false
                    self.saveButton.isHidden = false
                    self.tableView.reloadData()
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingWheel.stopAnimating()
                    self.errorLabel.isHidden = false
                }
            }
        )
    }

    // MARK: - Actions

    @objc private func saveButtonTouched() {
        saveButton.setTitle("", for: .normal)
        saveButton.isEnabled = false
        saveLoadingWheel.startAnimating()

        API.sharedInstance.updateNotificationPreferencesWithAuth(
            preferences: preferences,
            callback: { [weak self] in
                DispatchQueue.main.async {
                    self?.dismiss(animated: true)
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.saveLoadingWheel.stopAnimating()
                    self.saveButton.setTitle("SAVE", for: .normal)
                    self.saveButton.isEnabled = true

                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to save preferences. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        )
    }

    @objc func closeButtonTouched() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension HiveNotificationPreferencesViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Self.notificationKeys.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCell", for: indexPath)
        let entry = Self.notificationKeys[indexPath.row]

        cell.backgroundColor = UIColor.Sphinx.Body
        cell.selectionStyle = .none

        cell.textLabel?.text = entry.label
        cell.textLabel?.font = UIFont(name: "Roboto-Regular", size: 16)
        cell.textLabel?.textColor = UIColor.Sphinx.Text

        let toggle = UISwitch()
        toggle.isOn = preferences[entry.key] ?? Self.defaultPreferences[entry.key] ?? true
        toggle.onTintColor = UIColor.Sphinx.PrimaryBlue
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }

    @objc private func switchValueChanged(_ sender: UISwitch) {
        let entry = Self.notificationKeys[sender.tag]
        preferences[entry.key] = sender.isOn
    }
}
