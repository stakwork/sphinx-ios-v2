//
//  WorkspaceTaskTableViewCell.swift
//  sphinx
//
//  Created on 2025-02-23.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class WorkspaceTaskTableViewCell: UITableViewCell {

    static let reuseID = "WorkspaceTaskTableViewCell"

    static var nib: UINib {
        return UINib(nibName: "WorkspaceTaskTableViewCell", bundle: nil)
    }

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var repositoryLabel: UILabel!
    @IBOutlet weak var statusBadge: UILabel!
    @IBOutlet weak var priorityBadge: UILabel!
    @IBOutlet weak var separatorView: UIView!

    // Programmatic — no longer an @IBOutlet (removed from XIB)
    var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var onPRBadgeTapped: ((URL) -> Void)?
    var onRetryWorkflowTapped: (() -> Void)?
    private(set) var prBadgeButton: UIButton!
    private(set) var haltedWorkflowBadge: UILabel!
    private(set) var retryWorkflowButton: UIButton!
    private(set) var rightPillStack: UIStackView!
    private var prBadgeURL: URL?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
    }

    private func setupCell() {
        backgroundColor = .Sphinx.Body
        contentView.backgroundColor = .Sphinx.Body

        titleLabel.textColor = .Sphinx.Text
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.numberOfLines = 2

        repositoryLabel.textColor = .Sphinx.SecondaryText
        repositoryLabel.font = UIFont(name: "Roboto-Regular", size: 13)

        updatedAtLabel.textColor = .Sphinx.SecondaryText
        updatedAtLabel.font = UIFont(name: "Roboto-Regular", size: 13)

        [statusBadge, priorityBadge].forEach {
            $0?.layer.cornerRadius = 10
            $0?.clipsToBounds = true
            $0?.textColor = .white
            $0?.font = UIFont(name: "Roboto-Medium", size: 11)
            $0?.textAlignment = .center
        }

        separatorView.backgroundColor = .Sphinx.LightDivider

        setupPRBadgeButton()
        setupHaltedWorkflowBadge()
        setupRetryWorkflowButton()
        setupRightPillStack()
    }

    private func setupPRBadgeButton() {
        prBadgeButton = UIButton(type: .system)
        prBadgeButton.layer.cornerRadius = 10
        prBadgeButton.clipsToBounds = true
        prBadgeButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 11)
        prBadgeButton.setTitleColor(.white, for: .normal)
        prBadgeButton.isHidden = true
        prBadgeButton.translatesAutoresizingMaskIntoConstraints = false
        prBadgeButton.addTarget(self, action: #selector(prBadgeTapped), for: .touchUpInside)
        // Height constraint only — stack handles trailing/bottom positioning
        prBadgeButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
    }

    private func setupHaltedWorkflowBadge() {
        haltedWorkflowBadge = UILabel()
        haltedWorkflowBadge.layer.cornerRadius = 10
        haltedWorkflowBadge.clipsToBounds = true
        haltedWorkflowBadge.textColor = .white
        haltedWorkflowBadge.font = UIFont(name: "Roboto-Medium", size: 11)
        haltedWorkflowBadge.textAlignment = .center
        haltedWorkflowBadge.backgroundColor = .Sphinx.SphinxOrange
        haltedWorkflowBadge.text = "HALTED"
        haltedWorkflowBadge.translatesAutoresizingMaskIntoConstraints = false
        haltedWorkflowBadge.isHidden = true
        // Height + equal-width to prBadgeButton so .center alignment has a defined frame
        haltedWorkflowBadge.heightAnchor.constraint(equalToConstant: 22).isActive = true
        haltedWorkflowBadge.widthAnchor.constraint(equalToConstant: 55).isActive = true
    }

    private func setupRetryWorkflowButton() {
        retryWorkflowButton = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        retryWorkflowButton.setImage(UIImage(systemName: "arrow.counterclockwise", withConfiguration: config), for: .normal)
        retryWorkflowButton.tintColor = .Sphinx.SphinxOrange
        retryWorkflowButton.translatesAutoresizingMaskIntoConstraints = false
        retryWorkflowButton.isHidden = true
        contentView.addSubview(retryWorkflowButton)

        NSLayoutConstraint.activate([
            retryWorkflowButton.leadingAnchor.constraint(equalTo: repositoryLabel.trailingAnchor, constant: 8),
            retryWorkflowButton.centerYAnchor.constraint(equalTo: repositoryLabel.centerYAnchor),
            retryWorkflowButton.widthAnchor.constraint(equalToConstant: 20),
            retryWorkflowButton.heightAnchor.constraint(equalToConstant: 20)
        ])

        retryWorkflowButton.addTarget(self, action: #selector(retryWorkflowButtonTapped), for: .touchUpInside)
    }

    private func setupRightPillStack() {
        rightPillStack = UIStackView(arrangedSubviews: [updatedAtLabel, prBadgeButton, haltedWorkflowBadge])
        rightPillStack.axis = .horizontal
        rightPillStack.alignment = .center
        rightPillStack.distribution = .fill
        rightPillStack.spacing = 8
        rightPillStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rightPillStack)

        NSLayoutConstraint.activate([
            rightPillStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rightPillStack.bottomAnchor.constraint(equalTo: separatorView.topAnchor, constant: -12),
            rightPillStack.leadingAnchor.constraint(greaterThanOrEqualTo: repositoryLabel.trailingAnchor, constant: 8)
        ])
    }

    @objc private func retryWorkflowButtonTapped() {
        onRetryWorkflowTapped?()
    }

    @objc private func prBadgeTapped() {
        guard let url = prBadgeURL else { return }
        onPRBadgeTapped?(url)
    }

    func configure(with task: WorkspaceTask, isLastRow: Bool) {
        let isMerged = task.prStatus == "MERGED" || task.prStatus == "DONE"

        if isMerged {
            let attrs: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor.Sphinx.SecondaryText,
                .font: UIFont.systemFont(ofSize: 16, weight: .medium)
            ]
            titleLabel.attributedText = NSAttributedString(string: task.title ?? "", attributes: attrs)
        } else {
            titleLabel.attributedText = nil
            titleLabel.text = task.title
            titleLabel.textColor = .Sphinx.Text
        }

        repositoryLabel.text = task.repositoryName
        updatedAtLabel.text = formatDate(task.updatedAt)
        separatorView.isHidden = isLastRow

        let hasOpenPR = task.prUrl != nil && !(task.prStatus == "MERGED" || task.prStatus == "DONE")
        if hasOpenPR {
            statusBadge.text = "  READY  "
            statusBadge.backgroundColor = .Sphinx.PrimaryGreen
        } else {
            let displayStatus = task.status
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            statusBadge.text = "  \(displayStatus)  "
            statusBadge.backgroundColor = statusColor(for: task.status)
        }

        priorityBadge.text = "  \(task.priority)  "
        priorityBadge.backgroundColor = priorityColor(for: task.priority)

        // ── Baseline reset (prevents cell-reuse bleed) ──────────────────
        prBadgeButton.isHidden = true
        haltedWorkflowBadge.isHidden = true
        retryWorkflowButton.isHidden = true
        prBadgeURL = nil

        // ── Exclusive pill logic: PR wins, then HALTED, then neither ─────
        let prIsMerged = task.prStatus == "MERGED" || task.prStatus == "DONE"
        let isHalted = task.workflowStatus == "HALTED"

        if let urlStr = task.prUrl, let url = URL(string: urlStr) {
            prBadgeURL = url
            prBadgeButton.isHidden = false
            prBadgeButton.setTitle(prIsMerged ? "  MERGED  " : "  OPEN PR  ", for: .normal)
            prBadgeButton.backgroundColor = prIsMerged ? UIColor(hex: "#8B5CF6") : UIColor.Sphinx.PrimaryBlue
        } else if isHalted {
            haltedWorkflowBadge.isHidden = false
            retryWorkflowButton.isHidden = false
        }
        // UIStackView collapses hidden arranged subviews — no constraint toggling needed
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: dateString)
        
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateString)
        }
        
        guard let date = date else { return dateString }
        
        let now = Date()
        let seconds = now.timeIntervalSince(date)
        let minutes = seconds / 60
        let hours = seconds / 3600
        let days = seconds / 86400
        
        if seconds < 60 {
            return "Just now"
        } else if minutes < 60 {
            let m = Int(minutes)
            return "\(m) \(m == 1 ? "min" : "mins") ago"
        } else if hours < 24 {
            let h = Int(hours)
            return "\(h) \(h == 1 ? "hr" : "hrs") ago"
        } else if days < 2 {
            return "Yesterday"
        } else {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
    }

    private func statusColor(for status: String) -> UIColor {
        switch status {
        case "DONE":
            return .Sphinx.GreenBorder
        case "IN_PROGRESS":
            return .Sphinx.PrimaryBlue
        case "BLOCKED":
            return .Sphinx.PrimaryRed
        default:
            return .systemGray
        }
    }

    private func priorityColor(for priority: String) -> UIColor {
        switch priority {
        case "CRITICAL":
            return .Sphinx.PrimaryRed
        case "HIGH":
            return .Sphinx.SphinxOrange
        case "MEDIUM":
            return .Sphinx.PrimaryBlue
        default:
            return .systemGray
        }
    }
}
