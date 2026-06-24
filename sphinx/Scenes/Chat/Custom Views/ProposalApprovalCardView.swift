//
//  ProposalApprovalCardView.swift
//  sphinx
//
//  Created for AI Agent Proposal Approval feature.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

final class ProposalApprovalCardView: UIView {

    // MARK: - Public interface

    var onApprove: ((String) -> Void)?
    var onReject:  ((String) -> Void)?

    private let proposal: AIAgentManager.PendingProposal
    private var isActioned: Bool = false

    // MARK: - Subviews

    private let badgeLabel      = UILabel()
    private let titleLabel      = UILabel()
    private let descriptionLabel = UILabel()
    private let approveButton   = UIButton(type: .system)
    private let rejectButton    = UIButton(type: .system)
    private let stampLabel      = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Init

    init(proposal: AIAgentManager.PendingProposal) {
        self.proposal = proposal
        super.init(frame: .zero)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = UIColor.Sphinx.Body
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.Sphinx.Divider.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        clipsToBounds = false

        // Badge
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.layer.cornerRadius = 6
        badgeLabel.layer.masksToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.text = " \(proposal.kind.capitalized) "
        badgeLabel.backgroundColor = badgeColor(for: proposal.kind)
        addSubview(badgeLabel)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = UIColor.Sphinx.Text
        titleLabel.numberOfLines = 2
        titleLabel.text = proposal.title
        addSubview(titleLabel)

        // Description
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        descriptionLabel.textColor = UIColor.Sphinx.SecondaryText
        descriptionLabel.numberOfLines = 3
        descriptionLabel.text = proposal.description
        descriptionLabel.isHidden = (proposal.description?.isEmpty ?? true)
        addSubview(descriptionLabel)

        // Approve button
        approveButton.translatesAutoresizingMaskIntoConstraints = false
        approveButton.setTitle("Approve", for: .normal)
        approveButton.setTitleColor(.white, for: .normal)
        approveButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        approveButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        approveButton.layer.cornerRadius = 8
        approveButton.addTarget(self, action: #selector(handleApprove), for: .touchUpInside)
        addSubview(approveButton)

        // Reject button
        rejectButton.translatesAutoresizingMaskIntoConstraints = false
        rejectButton.setTitle("Reject", for: .normal)
        rejectButton.setTitleColor(UIColor.Sphinx.BadgeRed, for: .normal)
        rejectButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        rejectButton.backgroundColor = .clear
        rejectButton.layer.cornerRadius = 8
        rejectButton.layer.borderWidth = 1
        rejectButton.layer.borderColor = UIColor.Sphinx.BadgeRed.cgColor
        rejectButton.addTarget(self, action: #selector(handleReject), for: .touchUpInside)
        addSubview(rejectButton)

        // Stamp label (hidden initially)
        stampLabel.translatesAutoresizingMaskIntoConstraints = false
        stampLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        stampLabel.textAlignment = .center
        stampLabel.isHidden = true
        addSubview(stampLabel)

        // Activity indicator (hidden initially)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        addSubview(activityIndicator)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Badge
            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),

            // Title
            titleLabel.topAnchor.constraint(equalTo: badgeLabel.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            // Buttons
            approveButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            approveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            approveButton.heightAnchor.constraint(equalToConstant: 38),
            approveButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.44),

            rejectButton.topAnchor.constraint(equalTo: approveButton.topAnchor),
            rejectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rejectButton.heightAnchor.constraint(equalToConstant: 38),
            rejectButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.44),

            approveButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            // Stamp (centered over button area)
            stampLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            stampLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            stampLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: approveButton.centerYAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func handleApprove() {
        guard !isActioned else { return }
        setLoading(true)
        onApprove?(proposal.proposalId)
    }

    @objc private func handleReject() {
        guard !isActioned else { return }
        setLoading(true)
        onReject?(proposal.proposalId)
    }

    // MARK: - State

    func showStamp(approved: Bool) {
        isActioned = true
        approveButton.isHidden = true
        rejectButton.isHidden = true
        activityIndicator.stopAnimating()

        if approved {
            stampLabel.text = "Approved ✓"
            stampLabel.textColor = UIColor.Sphinx.PrimaryGreen
        } else {
            stampLabel.text = "Rejected ✗"
            stampLabel.textColor = UIColor.Sphinx.BadgeRed
        }
        stampLabel.isHidden = false

        // Auto-dismiss after 2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            UIView.animate(withDuration: 0.3, animations: {
                self?.alpha = 0
            }, completion: { _ in
                self?.removeFromSuperview()
            })
        }
    }

    func resetToActionable() {
        isActioned = false
        setLoading(false)
        approveButton.isHidden = false
        rejectButton.isHidden = false
        stampLabel.isHidden = true
    }

    private func setLoading(_ loading: Bool) {
        approveButton.isEnabled = !loading
        rejectButton.isEnabled = !loading
        if loading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    // MARK: - Helpers

    private func badgeColor(for kind: String) -> UIColor {
        switch kind.lowercased() {
        case "initiative":  return UIColor.Sphinx.PrimaryBlue
        case "feature":     return UIColor(red: 0.18, green: 0.66, blue: 0.40, alpha: 1) // green
        case "milestone":   return UIColor(red: 0.60, green: 0.35, blue: 0.80, alpha: 1) // purple
        default:            return UIColor.Sphinx.SecondaryText
        }
    }
}
