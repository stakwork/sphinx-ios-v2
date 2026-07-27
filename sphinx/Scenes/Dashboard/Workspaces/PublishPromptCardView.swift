//
//  PublishPromptCardView.swift
//  sphinx
//
//  Card view rendered inside a chat bubble for PUBLISH_PROMPT artifacts.
//
//  Layout (top → bottom):
//  ┌──────────────────────────────────────────┐
//  │  ⬆ Publish Prompt                        │  ← icon + header
//  │    <prompt name or fallback>             │  ← subtitle line 1
//  │    clversion000000000000007  ↗           │  ← subtitle line 2 (version id, truncates middle)
//  │  ─────────────────────────────────────   │  ← divider
//  │                          [ Publish / ✓ ] │  ← action (trailing)
//  └──────────────────────────────────────────┘

import UIKit

final class PublishPromptCardView: UIView {

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
        l.text = "Publish Prompt"
        return l
    }()

    /// Subtitle line 1 — prompt name or fallback "Prompt v{versionId}"
    private let promptNameLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = UIColor.Sphinx.SecondaryText
        l.numberOfLines = 2
        return l
    }()

    /// Subtitle line 2 — version id, full-width, truncates in the middle for long cuids.
    /// Implemented as a UIButton so the whole row is tappable for the external-link action.
    private let versionRowButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.contentHorizontalAlignment = .left
        b.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        b.titleLabel?.lineBreakMode = .byTruncatingMiddle
        b.setTitleColor(UIColor.Sphinx.PrimaryBlue, for: .normal)
        return b
    }()

    private let divider: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.Sphinx.LightDivider
        return v
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

    /// Spinner shown while the publish API call is in flight.
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = UIColor.Sphinx.PrimaryBlue
        return indicator
    }()

    // MARK: - State

    /// Persisted published flag so setLoading(false) can decide whether to re-show Publish button
    /// without relying on publishedLabel.isHidden view state.
    private var isPublished: Bool = false

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

        // Icon inside its container
        iconContainerView.addSubview(iconImageView)

        // Top row: icon + header label + flexible spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [iconContainerView, headerLabel, spacer])
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .center

        // Bottom row: spacer + spinner + publish button / published label (trailing)
        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bottomSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let bottomRow = UIStackView(arrangedSubviews: [bottomSpacer, loadingIndicator, publishButton, publishedLabel])
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.axis = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .center

        [topRow, promptNameLabel, versionRowButton, divider, bottomRow].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            // Icon container
            iconContainerView.widthAnchor.constraint(equalToConstant: 28),
            iconContainerView.heightAnchor.constraint(equalToConstant: 28),

            // Icon image centred inside container
            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            // Top row
            topRow.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            topRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            topRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Subtitle line 1 — prompt name
            promptNameLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 6),
            promptNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            promptNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Subtitle line 2 — version id row (full-width button, truncates middle)
            versionRowButton.topAnchor.constraint(equalTo: promptNameLabel.bottomAnchor, constant: 2),
            versionRowButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            versionRowButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Divider
            divider.topAnchor.constraint(equalTo: versionRowButton.bottomAnchor, constant: 10),
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
        versionRowButton.addTarget(self, action: #selector(openVersionTapped), for: .touchUpInside)
    }

    // MARK: - Configure

    func configure(with content: PublishPromptContent) {
        // Subtitle line 1
        let nameText = content.promptName ?? "Prompt v\(content.promptVersionId ?? "")"
        promptNameLabel.text = nameText

        // Subtitle line 2 — version id with external-link glyph
        if let versionId = content.promptVersionId, !versionId.isEmpty {
            versionRowButton.setTitle("\(versionId) ↗", for: .normal)
            versionRowButton.isHidden = false
        } else {
            versionRowButton.isHidden = true
        }

        setPublished(content.published)
        setLoading(content.loading)
    }

    // MARK: - Loading state

    /// Shows a spinner and disables the Publish button while `loading` is true.
    /// When `false`, hides the spinner and restores the Publish button (unless already published).
    func setLoading(_ loading: Bool) {
        if loading {
            loadingIndicator.startAnimating()
            publishButton.isHidden = true
            publishButton.isEnabled = false
        } else {
            loadingIndicator.stopAnimating()
            publishButton.isHidden = isPublished
            publishButton.isEnabled = true
        }
    }

    // MARK: - Published state

    /// Flips the card to the Published ✓ state locally without a full reconfigure.
    func setPublished(_ published: Bool) {
        isPublished = published
        publishButton.isHidden = published
        publishedLabel.isHidden = !published
        // Clear any in-flight loading state on success
        if published {
            loadingIndicator.stopAnimating()
            publishButton.isEnabled = true
        }
    }

    // MARK: - Actions

    @objc private func publishTapped() {
        onPublishTapped?()
    }

    @objc private func openVersionTapped() {
        onOpenVersionTapped?()
    }
}
