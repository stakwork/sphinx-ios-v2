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
    @IBOutlet weak var updatedAtLabel: UILabel!
    @IBOutlet weak var statusBadge: UILabel!
    @IBOutlet weak var priorityBadge: UILabel!
    @IBOutlet weak var separatorView: UIView!

    var onPRBadgeTapped: ((URL) -> Void)?
    private(set) var prBadgeButton: UIButton!
    private var prBadgeURL: URL?

    private var updatedAtLabelTrailingToPR: NSLayoutConstraint!
    private var updatedAtLabelTrailingToEdge: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
    }

    private func setupCell() {
        selectionStyle = .none
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

        separatorView.backgroundColor = .Sphinx.Divider

        setupPRBadgeButton()
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
        contentView.addSubview(prBadgeButton)

        NSLayoutConstraint.activate([
            prBadgeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            prBadgeButton.bottomAnchor.constraint(equalTo: separatorView.topAnchor, constant: -12),
            prBadgeButton.heightAnchor.constraint(equalToConstant: 22)
        ])

        updatedAtLabelTrailingToPR = updatedAtLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: prBadgeButton.leadingAnchor, constant: -8
        )
        updatedAtLabelTrailingToEdge = updatedAtLabel.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor, constant: -16
        )
        updatedAtLabelTrailingToEdge.isActive = true
    }

    @objc private func prBadgeTapped() {
        guard let url = prBadgeURL else { return }
        onPRBadgeTapped?(url)
    }

    func configure(with task: WorkspaceTask, isLastRow: Bool) {
        titleLabel.text = task.title
        repositoryLabel.text = task.repositoryName
        updatedAtLabel.text = formatDate(task.updatedAt)
        separatorView.isHidden = isLastRow

        statusBadge.text = "  \(task.status)  "
        statusBadge.backgroundColor = statusColor(for: task.status)

        priorityBadge.text = "  \(task.priority)  "
        priorityBadge.backgroundColor = priorityColor(for: task.priority)

        if let urlStr = task.prUrl, let url = URL(string: urlStr) {
            prBadgeURL = url
            prBadgeButton.isHidden = false
            let isMerged = task.prStatus == "MERGED" || task.prStatus == "DONE"
            prBadgeButton.setTitle(isMerged ? "  MERGED  " : "  OPEN  ", for: .normal)
            prBadgeButton.backgroundColor = isMerged ? UIColor(hex: "#8B5CF6") : UIColor.Sphinx.PrimaryBlue
            updatedAtLabelTrailingToEdge.isActive = false
            updatedAtLabelTrailingToPR.isActive = true
        } else {
            prBadgeURL = nil
            prBadgeButton.isHidden = true
            updatedAtLabelTrailingToPR.isActive = false
            updatedAtLabelTrailingToEdge.isActive = true
        }
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
            return .Sphinx.PrimaryGreen
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
