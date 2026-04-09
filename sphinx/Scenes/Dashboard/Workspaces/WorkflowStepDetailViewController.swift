//
//  WorkflowStepDetailViewController.swift
//  sphinx
//
//  Bottom sheet showing workflow step details with Cancel / Select Step actions.
//

import UIKit

class WorkflowStepDetailViewController: UIViewController {

    // MARK: - Public API

    var onSelectStep: ((WorkflowStep) -> Void)?

    static func instantiate(step: WorkflowStep) -> WorkflowStepDetailViewController {
        let vc = WorkflowStepDetailViewController()
        vc.step = step
        return vc
    }

    // MARK: - Private

    private var step: WorkflowStep!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.Sphinx.HeaderBG
        setupUI()
    }

    // MARK: - UI

    private func setupUI() {
        // ---- Icon + display name row ----
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = nodeTypeColor(step.nodeType)
        let symbolName: String
        switch step.nodeType {
        case .human:     symbolName = "person.fill"
        case .automated: symbolName = "gear"
        case .api:       symbolName = "link"
        case .condition: symbolName = "arrow.triangle.branch"
        case .loop:      symbolName = "arrow.clockwise"
        }
        iconImageView.image = UIImage(systemName: symbolName,
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular))

        let displayNameLabel = UILabel()
        displayNameLabel.translatesAutoresizingMaskIntoConstraints = false
        displayNameLabel.text = step.displayName ?? step.name
        displayNameLabel.font = UIFont(name: "Roboto-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        displayNameLabel.textColor = UIColor.Sphinx.Text
        displayNameLabel.numberOfLines = 2

        let techNameLabel = UILabel()
        techNameLabel.translatesAutoresizingMaskIntoConstraints = false
        techNameLabel.text = step.name
        techNameLabel.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        techNameLabel.textColor = UIColor.Sphinx.SecondaryText
        techNameLabel.numberOfLines = 1

        let nameStack = UIStackView(arrangedSubviews: [displayNameLabel, techNameLabel])
        nameStack.axis = .vertical
        nameStack.spacing = 2
        nameStack.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [iconImageView, nameStack])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12
        topRow.translatesAutoresizingMaskIntoConstraints = false

        // ---- Display ID ----
        let displayIdLabel = UILabel()
        displayIdLabel.translatesAutoresizingMaskIntoConstraints = false
        if let did = step.displayId ?? step.uniqueId {
            displayIdLabel.text = did
        } else {
            displayIdLabel.text = step.id
        }
        displayIdLabel.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        displayIdLabel.textColor = UIColor.Sphinx.SecondaryText
        displayIdLabel.numberOfLines = 1

        // ---- Attributes text view ----
        let attrsTextView = UITextView()
        attrsTextView.translatesAutoresizingMaskIntoConstraints = false
        attrsTextView.isEditable = false
        attrsTextView.backgroundColor = .clear
        attrsTextView.textColor = UIColor.Sphinx.Text
        attrsTextView.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        attrsTextView.text = buildAttributesText()

        // ---- Divider ----
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.Sphinx.LightDivider

        // ---- Buttons ----
        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        cancelButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 16)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        cancelButton.layer.cornerRadius = 22

        let selectButton = UIButton(type: .system)
        selectButton.translatesAutoresizingMaskIntoConstraints = false
        selectButton.setTitle("Select Step", for: .normal)
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 16)
        selectButton.backgroundColor = UIColor.Sphinx.PrimaryGreen
        selectButton.layer.cornerRadius = 22
        selectButton.addTarget(self, action: #selector(selectTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, selectButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // ---- Add to view ----
        view.addSubview(topRow)
        view.addSubview(displayIdLabel)
        view.addSubview(attrsTextView)
        view.addSubview(divider)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),

            topRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            topRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            displayIdLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 6),
            displayIdLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            displayIdLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            attrsTextView.topAnchor.constraint(equalTo: displayIdLabel.bottomAnchor, constant: 12),
            attrsTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            attrsTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            divider.topAnchor.constraint(equalTo: attrsTextView.bottomAnchor, constant: 8),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            buttonStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 16),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),
            buttonStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func buildAttributesText() -> String {
        var lines: [String] = []

        func addSection(_ dict: [String: Any], _ heading: String) {
            guard !dict.isEmpty else { return }
            lines.append("── \(heading) ──")
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(key): \(value)")
            }
        }

        if let step = step.rawJSON["step"] as? [String: Any] {
            addSection(step, "Step")
        }
        if let attrs = step.rawJSON["attributes"] as? [String: Any] {
            addSection(attrs, "Attributes")
        }

        if lines.isEmpty {
            // fallback: show top-level keys (excluding noisy ones)
            let skip: Set<String> = ["connection_edges", "connections", "position",
                                      "status", "skill", "step", "attributes"]
            let topLevel = step.rawJSON.filter { !skip.contains($0.key) }
            if !topLevel.isEmpty {
                addSection(topLevel, "Details")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func nodeTypeColor(_ type: WorkflowNodeType) -> UIColor {
        switch type {
        case .automated: return UIColor.Sphinx.PrimaryGreen
        case .human:     return UIColor.Sphinx.PrimaryBlue
        case .api:       return .systemCyan
        case .condition: return .systemOrange
        case .loop:      return .systemPurple
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func selectTapped() {
        onSelectStep?(step)
        dismiss(animated: true)
    }
}
