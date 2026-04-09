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
        // ---- Icon (from StepIcons assets) ----
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        let iconName: String
        switch step.nodeType {
        case .human: iconName = "human"
        case .api:   iconName = "api"
        default:     iconName = "automated"
        }
        iconImageView.image = UIImage(named: iconName)?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = nodeTypeColor(step.nodeType)

        // ---- Display name ----
        let displayNameLabel = UILabel()
        displayNameLabel.translatesAutoresizingMaskIntoConstraints = false
        displayNameLabel.text = step.displayName ?? step.name
        displayNameLabel.font = UIFont(name: "Roboto-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        displayNameLabel.textColor = UIColor.Sphinx.Text
        displayNameLabel.numberOfLines = 2

        // ---- Tech name ----
        let techNameLabel = UILabel()
        techNameLabel.translatesAutoresizingMaskIntoConstraints = false
        techNameLabel.text = step.name
        techNameLabel.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        techNameLabel.textColor = UIColor.Sphinx.SecondaryText
        techNameLabel.numberOfLines = 1

        // ---- Type badge ----
        let typeString: String
        switch step.nodeType {
        case .automated: typeString = "Automated"
        case .human:     typeString = "Human"
        case .api:       typeString = "API"
        case .condition: typeString = "Condition"
        case .loop:      typeString = "Loop"
        }
        let badgeLabel = PaddedLabel()
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = typeString
        badgeLabel.font = UIFont(name: "Roboto-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        badgeLabel.textColor = nodeTypeColor(step.nodeType)
        badgeLabel.backgroundColor = nodeTypeColor(step.nodeType).withAlphaComponent(0.15)
        badgeLabel.layer.cornerRadius = 4
        badgeLabel.clipsToBounds = true
        badgeLabel.textInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

        let nameStack = UIStackView(arrangedSubviews: [displayNameLabel, techNameLabel, badgeLabel])
        nameStack.axis = .vertical
        nameStack.spacing = 4
        nameStack.alignment = .leading
        nameStack.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [iconImageView, nameStack])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12
        topRow.translatesAutoresizingMaskIntoConstraints = false

        // ---- Step Alias section ----
        let aliasHeaderLabel = UILabel()
        aliasHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        aliasHeaderLabel.text = "STEP ALIAS"
        aliasHeaderLabel.font = UIFont(name: "Roboto-Medium", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .medium)
        aliasHeaderLabel.textColor = UIColor.Sphinx.SecondaryText

        let aliasValueLabel = UILabel()
        aliasValueLabel.translatesAutoresizingMaskIntoConstraints = false
        aliasValueLabel.text = step.id
        aliasValueLabel.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        aliasValueLabel.textColor = UIColor.Sphinx.Text
        aliasValueLabel.numberOfLines = 1
        aliasValueLabel.lineBreakMode = .byTruncatingTail

        let aliasSection = UIStackView(arrangedSubviews: [aliasHeaderLabel, aliasValueLabel])
        aliasSection.axis = .vertical
        aliasSection.spacing = 4
        aliasSection.translatesAutoresizingMaskIntoConstraints = false

        // ---- Scrollable content area ----
        let contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.showsVerticalScrollIndicator = true
        contentScrollView.backgroundColor = .clear

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStack)

        // Variables section
        if let attrs = step.rawJSON["attributes"] as? [String: Any],
           let vars = attrs["vars"] as? [String: Any],
           !vars.isEmpty {
            let rows = vars.sorted(by: { $0.key < $1.key }).map { [$0.key, formatValue($0.value)] }
            contentStack.addArrangedSubview(makeSectionTable(title: "Variables", rows: rows))
        }

        // Attributes section (all keys except "vars")
        if let attrs = step.rawJSON["attributes"] as? [String: Any] {
            let filtered = attrs.filter { $0.key != "vars" }
            if !filtered.isEmpty {
                let rows = filtered.sorted(by: { $0.key < $1.key }).map { [$0.key, formatValue($0.value)] }
                contentStack.addArrangedSubview(makeSectionTable(title: "Attributes", rows: rows))
            }
        }

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
        view.addSubview(aliasSection)
        view.addSubview(contentScrollView)
        view.addSubview(divider)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),

            // Top: icon + name row
            topRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            topRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Step Alias below top row
            aliasSection.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 16),
            aliasSection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            aliasSection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Buttons pinned to bottom of safe area
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),

            // Divider above button stack
            divider.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -16),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            // Scroll view fills the space between alias and divider
            contentScrollView.topAnchor.constraint(equalTo: aliasSection.bottomAnchor, constant: 16),
            contentScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: divider.topAnchor, constant: -8),

            // Content stack inside scroll view
            contentStack.topAnchor.constraint(equalTo: contentScrollView.topAnchor, constant: 0),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.bottomAnchor, constant: 0),
            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor, constant: -40),
        ])
    }

    // MARK: - Section Builder

    private func makeSectionTable(title: String, rows: [[String]]) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        // Section title
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = UIFont(name: "Roboto-Medium", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = UIColor.Sphinx.SecondaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(titleLabel)

        // MarkdownTableView with Name / Value header row
        let tableView = MarkdownTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.configure(headers: ["Name", "Value"], rows: rows)

        let rowCount = rows.count
        let tableHeight = tableView.intrinsicContentHeight
        tableView.heightAnchor.constraint(equalToConstant: tableHeight).isActive = true

        container.addArrangedSubview(tableView)

        return container
    }

    // MARK: - Helpers

    private func formatValue(_ value: Any) -> String {
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return num.stringValue }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "\(value)"
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

// MARK: - PaddedLabel

private class PaddedLabel: UILabel {
    var textInsets: UIEdgeInsets = .zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width:  size.width  + textInsets.left + textInsets.right,
            height: size.height + textInsets.top  + textInsets.bottom
        )
    }
}
