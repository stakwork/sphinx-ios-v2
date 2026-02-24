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

    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
    }

    private func setupCell() {
        backgroundColor = .Sphinx.DashboardHeader
        contentView.backgroundColor = .Sphinx.DashboardHeader
        selectionStyle = .none

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
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM dd, yyyy"
            return displayFormatter.string(from: date)
        }
        
        // Fallback: try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM dd, yyyy"
            return displayFormatter.string(from: date)
        }
        
        return dateString
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
