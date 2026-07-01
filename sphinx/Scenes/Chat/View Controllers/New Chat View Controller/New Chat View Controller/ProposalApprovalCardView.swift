//
//  ProposalApprovalCardView.swift
//  sphinx
//
//  Created for Proposal Approval feature (UIKit port of macOS NSView card).
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

/// A self-contained UIKit card that surfaces a Jamie proposal (feature / initiative / milestone)
/// above the chat input area, with Approve / Reject actions and inline state feedback.
final class ProposalApprovalCardView: UIView {

    // MARK: - Subviews

    private let badgeLabel    = UILabel()
    private let titleLabel    = UILabel()
    private let descLabel     = UILabel()
    private let approveButton = UIButton(type: .system)
    private let rejectButton  = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    private let spinner       = UIActivityIndicatorView(style: .medium)
    /// Reused for inline error text AND approved/rejected confirmation stamp.
    private let errorLabel    = UILabel()

    // MARK: - State

    private(set) var isActioned: Bool = false
    private let proposal: AIAgentManager.PendingProposal

    // MARK: - Callbacks

    var onApprove: ((String) -> Void)?
    var onReject:  ((String) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Init

    init(proposal: AIAgentManager.PendingProposal) {
        self.proposal = proposal
        super.init(frame: .zero)
        setupView()
        populate(with: proposal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(proposal:)") }

    // MARK: - View Setup

    private func setupView() {
        backgroundColor = UIColor.Sphinx.ReceivedMsgBG
        layer.cornerRadius = 10
        layer.masksToBounds = false
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius  = 4
        layer.shadowOffset  = CGSize(width: 0, height: -1)

        // Badge
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font            = UIFont(name: "Roboto-Bold", size: 12) ?? .boldSystemFont(ofSize: 12)
        badgeLabel.textColor       = .white
        badgeLabel.textAlignment   = .center
        badgeLabel.layer.cornerRadius = 4
        badgeLabel.layer.masksToBounds = true
        badgeLabel.numberOfLines   = 1
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font         = UIFont(name: "Roboto-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        titleLabel.textColor    = UIColor.Sphinx.Text
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping

        // Description
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font          = UIFont(name: "Roboto-Regular", size: 11) ?? .systemFont(ofSize: 11)
        descLabel.textColor     = UIColor.Sphinx.SecondaryText
        descLabel.numberOfLines = 3
        descLabel.lineBreakMode = .byWordWrapping

        // Dismiss "✕"
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.setTitleColor(UIColor.Sphinx.SecondaryText, for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 14)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        // Approve button
        approveButton.translatesAutoresizingMaskIntoConstraints = false
        approveButton.setTitle("Approve", for: .normal)
        approveButton.setTitleColor(.white, for: .normal)
        approveButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        approveButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        approveButton.layer.cornerRadius = 8
        approveButton.layer.masksToBounds = true
        approveButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        approveButton.addTarget(self, action: #selector(approveTapped), for: .touchUpInside)

        // Reject button
        rejectButton.translatesAutoresizingMaskIntoConstraints = false
        rejectButton.setTitle("Reject", for: .normal)
        rejectButton.setTitleColor(UIColor.Sphinx.PrimaryBlue, for: .normal)
        rejectButton.backgroundColor = UIColor.Sphinx.PrimaryBlue.withAlphaComponent(0.15)
        rejectButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        rejectButton.layer.cornerRadius = 8
        rejectButton.layer.masksToBounds = true
        rejectButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        rejectButton.addTarget(self, action: #selector(rejectTapped), for: .touchUpInside)

        // Spinner
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.isHidden = true

        // Error / stamp label
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font          = UIFont(name: "Roboto-Regular", size: 11) ?? .systemFont(ofSize: 11)
        errorLabel.textColor     = .systemRed
        errorLabel.numberOfLines = 2
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.isHidden      = true

        // Add subviews
        addSubview(badgeLabel)
        addSubview(titleLabel)
        addSubview(descLabel)
        addSubview(dismissButton)
        addSubview(approveButton)
        addSubview(rejectButton)
        addSubview(spinner)
        addSubview(errorLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        // Badge padding helper: wrap in container for insets
        let badgePadding: CGFloat = 6
        badgeLabel.layoutMargins = UIEdgeInsets(top: 2, left: badgePadding, bottom: 2, right: badgePadding)

        NSLayoutConstraint.activate([
            // Dismiss button — top-right
            dismissButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dismissButton.widthAnchor.constraint(equalToConstant: 28),
            dismissButton.heightAnchor.constraint(equalToConstant: 28),

            // Badge — vertically centered with dismiss button row
            badgeLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            badgeLabel.trailingAnchor.constraint(lessThanOrEqualTo: dismissButton.leadingAnchor, constant: -8),
            badgeLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 55),

            // Title — below badge
            titleLabel.topAnchor.constraint(equalTo: badgeLabel.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Description — below title
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Error label — below description
            errorLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 6),
            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Approve button
            approveButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
            approveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            approveButton.heightAnchor.constraint(equalToConstant: 36),

            // Reject button — trailing approve, sized to its own content
            rejectButton.topAnchor.constraint(equalTo: approveButton.topAnchor),
            rejectButton.leadingAnchor.constraint(equalTo: approveButton.trailingAnchor, constant: 8),
            rejectButton.trailingAnchor.constraint(lessThanOrEqualTo: spinner.leadingAnchor, constant: -8),
            rejectButton.heightAnchor.constraint(equalToConstant: 36),

            // Spinner — trailing reject button
            spinner.centerYAnchor.constraint(equalTo: rejectButton.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // Bottom padding
            approveButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    private func populate(with proposal: AIAgentManager.PendingProposal) {
        // Badge
        let kind = proposal.kind.lowercased()
        let badgeText: String
        let badgeColor: UIColor
        switch kind {
        case "initiative":
            badgeText  = "Initiative"
            badgeColor = .systemPurple
        case "milestone":
            badgeText  = "Milestone"
            badgeColor = .systemOrange
        default:
            badgeText  = "Feature"
            badgeColor = UIColor.Sphinx.PrimaryBlue
        }
        badgeLabel.text            = "\(badgeText)"
        badgeLabel.backgroundColor = badgeColor

        // Title
        titleLabel.text = proposal.title

        // Description
        if let desc = proposal.description, !desc.isEmpty {
            descLabel.text    = desc
            descLabel.isHidden = false
        } else {
            descLabel.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func approveTapped() {
        onApprove?(proposal.proposalId)
    }

    @objc private func rejectTapped() {
        onReject?(proposal.proposalId)
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }

    // MARK: - State Machine

    func showLoading() {
        approveButton.isEnabled = false
        rejectButton.isEnabled  = false
        spinner.isHidden = false
        spinner.startAnimating()
        errorLabel.isHidden = true
    }

    func showError(_ message: String) {
        spinner.stopAnimating()
        spinner.isHidden = true
        approveButton.isEnabled = true
        rejectButton.isEnabled  = true
        errorLabel.textColor = .systemRed
        errorLabel.text      = message
        errorLabel.isHidden  = false
    }

    func showStamp(approved: Bool) {
        isActioned = true
        approveButton.isHidden = true
        rejectButton.isHidden  = true
        spinner.stopAnimating()
        spinner.isHidden = true
        dismissButton.isHidden = true

        errorLabel.textColor = approved ? .systemGreen : .systemRed
        errorLabel.text      = approved ? "✓ Approved" : "✗ Rejected"
        errorLabel.font      = UIFont(name: "Roboto-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        errorLabel.isHidden  = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.onDismiss?()
        }
    }

    func resetToActionable() {
        isActioned = false
        approveButton.isEnabled = true
        rejectButton.isEnabled  = true
        approveButton.isHidden  = false
        rejectButton.isHidden   = false
        dismissButton.isHidden  = false
        spinner.stopAnimating()
        spinner.isHidden  = true
        errorLabel.isHidden = true
        errorLabel.font   = UIFont(name: "Roboto-Regular", size: 11) ?? .systemFont(ofSize: 11)
    }
}
