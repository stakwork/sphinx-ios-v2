//
//  WorkflowStepDetailViewController.swift
//  sphinx
//
//  Bottom sheet showing workflow step details with structured sections.
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

        // ---- Icon (StepIcons assets) ----
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
        let typeColor = nodeTypeColor(step.nodeType)
        let badgeLabel = PaddedLabel()
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = typeString(for: step.nodeType)
        badgeLabel.font = UIFont(name: "Roboto-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        badgeLabel.textColor = typeColor
        badgeLabel.backgroundColor = typeColor.withAlphaComponent(0.15)
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
        aliasHeaderLabel.text = "STEP ALIAS"
        aliasHeaderLabel.font = UIFont(name: "Roboto-Medium", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .medium)
        aliasHeaderLabel.textColor = UIColor.Sphinx.SecondaryText

        let aliasValueLabel = UILabel()
        aliasValueLabel.text = step.displayId ?? step.uniqueId ?? step.id
        aliasValueLabel.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        aliasValueLabel.textColor = UIColor.Sphinx.Text
        aliasValueLabel.numberOfLines = 1
        aliasValueLabel.lineBreakMode = .byTruncatingTail

        let aliasStack = UIStackView(arrangedSubviews: [aliasHeaderLabel, aliasValueLabel])
        aliasStack.axis = .vertical
        aliasStack.spacing = 2
        aliasStack.translatesAutoresizingMaskIntoConstraints = false

        // ---- Scrollable content sections ----
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        // Variables section
        if let attrs = step.rawJSON["attributes"] as? [String: Any],
           let vars = attrs["vars"] as? [String: Any],
           !vars.isEmpty {
            let rows = vars.sorted(by: { $0.key < $1.key }).map { ($0.key, formatValue($0.value)) }
            contentStack.addArrangedSubview(makeSectionView(title: "Variables", rows: rows))
        }

        // Attributes section (all except vars)
        if let attrs = step.rawJSON["attributes"] as? [String: Any] {
            let filtered = attrs.filter { $0.key != "vars" }
            if !filtered.isEmpty {
                let rows = filtered.sorted(by: { $0.key < $1.key }).map { ($0.key, formatValue($0.value)) }
                contentStack.addArrangedSubview(makeSectionView(title: "Attributes", rows: rows))
            }
        }

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

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
        view.addSubview(aliasStack)
        view.addSubview(scrollView)
        view.addSubview(divider)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),

            topRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            topRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            aliasStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 16),
            aliasStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            aliasStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: aliasStack.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            divider.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
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

    // MARK: - Helpers

    private func typeString(for nodeType: WorkflowNodeType) -> String {
        switch nodeType {
        case .automated: return "Automated"
        case .human:     return "Human"
        case .api:       return "API"
        case .condition: return "Condition"
        case .loop:      return "Loop"
        }
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

    private func formatValue(_ value: Any) -> String {
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return num.stringValue }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 120 ? String(trimmed.prefix(120)) + "…" : trimmed
        }
        return "\(value)"
    }

    private func makeSectionView(title: String, rows: [(String, String)]) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 0

        // Section header
        let headerLabel = UILabel()
        headerLabel.text = title.uppercased()
        headerLabel.font = UIFont(name: "Roboto-Medium", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .medium)
        headerLabel.textColor = UIColor.Sphinx.SecondaryText
        container.addArrangedSubview(headerLabel)

        let headerSpacer = UIView()
        headerSpacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        container.addArrangedSubview(headerSpacer)

        for (key, value) in rows {
            let keyLabel = UILabel()
            keyLabel.text = key
            keyLabel.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
            keyLabel.textColor = UIColor.Sphinx.SecondaryText
            keyLabel.numberOfLines = 1
            keyLabel.lineBreakMode = .byTruncatingTail
            keyLabel.widthAnchor.constraint(equalToConstant: 120).isActive = true
            keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            keyLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
            valueLabel.textColor = UIColor.Sphinx.Text
            valueLabel.numberOfLines = 4
            valueLabel.lineBreakMode = .byTruncatingTail
            valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let rowStack = UIStackView(arrangedSubviews: [keyLabel, valueLabel])
            rowStack.axis = .horizontal
            rowStack.alignment = .top
            rowStack.spacing = 8

            container.addArrangedSubview(rowStack)

            // Separator
            let sep = UIView()
            sep.backgroundColor = UIColor.Sphinx.LightDivider
            sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
            container.addArrangedSubview(sep)
        }

        return container
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
    var textInsets = UIEdgeInsets.zero

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

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s = super.sizeThatFits(size)
        return CGSize(
            width:  s.width  + textInsets.left + textInsets.right,
            height: s.height + textInsets.top  + textInsets.bottom
        )
    }
}
