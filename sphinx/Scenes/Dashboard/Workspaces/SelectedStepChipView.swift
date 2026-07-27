//
//  SelectedStepChipView.swift
//  sphinx
//
//  Dismissible chip showing the currently-selected workflow step context.
//

import UIKit

class SelectedStepChipView: UIView {

    // MARK: - Public API

    /// Called when the user taps the × button.
    var onDeselect: (() -> Void)?

    // MARK: - Subviews

    private let iconImageView = UIImageView()
    private let nameLabel     = UILabel()
    private let closeButton   = UIButton(type: .system)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor.Sphinx.HeaderBG

        // 1pt top divider
        let topDivider = UIView()
        topDivider.translatesAutoresizingMaskIntoConstraints = false
        topDivider.backgroundColor = UIColor.Sphinx.LightDivider
        addSubview(topDivider)

        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        addSubview(iconImageView)

        // Label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        nameLabel.textColor = UIColor.Sphinx.Text
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)

        // Close button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let xConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: xConfig), for: .normal)
        closeButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            topDivider.topAnchor.constraint(equalTo: topAnchor),
            topDivider.leadingAnchor.constraint(equalTo: leadingAnchor),
            topDivider.trailingAnchor.constraint(equalTo: trailingAnchor),
            topDivider.heightAnchor.constraint(equalToConstant: 1),

            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // MARK: - Public methods

    func configure(with step: WorkflowStep) {
        // Icon
        let symbolName: String
        let tintColor: UIColor
        switch step.nodeType {
        case .human:
            symbolName = "person.fill"
            tintColor  = UIColor.Sphinx.PrimaryBlue
        case .automated:
            symbolName = "gear"
            tintColor  = UIColor.Sphinx.PrimaryGreen
        case .api:
            symbolName = "link"
            tintColor  = .systemCyan
        case .condition:
            symbolName = "arrow.triangle.branch"
            tintColor  = .systemOrange
        case .loop:
            symbolName = "arrow.clockwise"
            tintColor  = .systemPurple
        }
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        iconImageView.image     = UIImage(systemName: symbolName, withConfiguration: cfg)
        iconImageView.tintColor = tintColor

        // Label: "DisplayName · displayId/uniqueId"
        let title = step.displayName ?? step.name
        let sub   = step.displayId ?? step.uniqueId
        nameLabel.text = sub.map { "\(title)  ·  \($0)" } ?? title
    }

    func clear() {
        nameLabel.text     = nil
        iconImageView.image = nil
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        onDeselect?()
    }
}
