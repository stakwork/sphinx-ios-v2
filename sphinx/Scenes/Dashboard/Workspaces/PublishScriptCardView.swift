//
//  PublishScriptCardView.swift
//  sphinx
//
//  Card view rendered inside a chat bubble for PUBLISH_SCRIPT artifacts.
//
//  Layout (top → bottom):
//  ┌──────────────────────────────────────────┐
//  │  ⬆ Publish Script                        │  ← icon + header
//  │    harvey-lab-guard-completeness         │  ← script name subtitle
//  │  ─────────────────────────────────────   │  ← divider
//  │  [v926 ↗]              [ Publish / ✓ ]  │  ← version badge + action
//  └──────────────────────────────────────────┘

import UIKit

class PublishScriptCardView: UIView {

    // MARK: - Subviews

    private let iconContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.Sphinx.PrimaryBlue.withAlphaComponent(0.15)
        v.layer.cornerRadius = 14
        v.clipsToBounds = true
        return v
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor.Sphinx.PrimaryBlue
        iv.image = UIImage(systemName: "arrow.up.circle.fill")
        return iv
    }()

    private let headerLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        l.textColor = UIColor.Sphinx.Text
        l.text = "Publish Script"
        return l
    }()

    private let scriptNameLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = UIColor.Sphinx.SecondaryText
        l.numberOfLines = 2
        return l
    }()

    private let divider: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.Sphinx.LightDivider
        return v
    }()

    private let versionBadgeButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.boldSystemFont(ofSize: 12)
        b.setTitleColor(UIColor.Sphinx.PrimaryBlue, for: .normal)
        b.backgroundColor = UIColor.Sphinx.PrimaryBlue.withAlphaComponent(0.1)
        b.layer.cornerRadius = 8
        b.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        return b
    }()

    private let publishButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Publish", for: .normal)
        b.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.boldSystemFont(ofSize: 12)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor.Sphinx.PrimaryBlue
        b.layer.cornerRadius = 12
        b.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        return b
    }()

    private let publishedLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.boldSystemFont(ofSize: 12)
        l.textColor = UIColor.Sphinx.PrimaryGreen
        l.text = "Published ✓"
        l.isHidden = true
        return l
    }()

    // MARK: - Closures

    var onPublishTapped: (() -> Void)?
    var onOpenVersionTapped: (() -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.Sphinx.Body
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        clipsToBounds = true

        // Icon container with icon inside
        iconContainerView.addSubview(iconImageView)

        // Top row: icon + header
        let topRow = UIStackView(arrangedSubviews: [iconContainerView, headerLabel, UIView()])
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .center

        // Bottom row: version badge + spacer + publish/published
        let bottomRow = UIStackView(arrangedSubviews: [versionBadgeButton, UIView(), publishButton, publishedLabel])
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.axis = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .center

        [topRow, scriptNameLabel, divider, bottomRow].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            // Icon container
            iconContainerView.widthAnchor.constraint(equalToConstant: 28),
            iconContainerView.heightAnchor.constraint(equalToConstant: 28),

            // Icon image inside container
            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            // Top row
            topRow.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            topRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            topRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Script name
            scriptNameLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 6),
            scriptNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scriptNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Divider
            divider.topAnchor.constraint(equalTo: scriptNameLabel.bottomAnchor, constant: 10),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            divider.heightAnchor.constraint(equalToConstant: 1),

            // Bottom row
            bottomRow.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            bottomRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bottomRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bottomRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])

        publishButton.addTarget(self, action: #selector(publishTapped), for: .touchUpInside)
        versionBadgeButton.addTarget(self, action: #selector(openVersionTapped), for: .touchUpInside)
    }

    // MARK: - Configure

    func configure(with content: PublishScriptContent) {
        scriptNameLabel.text = content.scriptName ?? "Unknown script"
        scriptNameLabel.isHidden = content.scriptName == nil

        if let versionId = content.scriptVersionId {
            versionBadgeButton.setTitle("v\(versionId) ↗", for: .normal)
            versionBadgeButton.isHidden = false
        } else {
            versionBadgeButton.isHidden = true
        }

        setPublished(content.published)
    }

    /// Flips the card to the Published ✓ state locally without re-configuring the whole card.
    func setPublished(_ published: Bool) {
        publishButton.isHidden = published
        publishedLabel.isHidden = !published
    }

    // MARK: - Actions

    @objc private func publishTapped() {
        onPublishTapped?()
    }

    @objc private func openVersionTapped() {
        onOpenVersionTapped?()
    }
}
