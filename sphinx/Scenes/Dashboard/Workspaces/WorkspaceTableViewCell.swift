//
//  WorkspaceTableViewCell.swift
//  sphinx
//
//  Created on 2025-02-18.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class WorkspaceTableViewCell: UITableViewCell {

    static let reuseID = "WorkspaceTableViewCell"

    static var nib: UINib {
        return UINib(nibName: "WorkspaceTableViewCell", bundle: nil)
    }

    @IBOutlet weak var workspaceNameLabel: UILabel!
    @IBOutlet weak var roleLabel: UILabel!
    @IBOutlet weak var membersLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
    }

    private func setupCell() {
        backgroundColor = .Sphinx.DashboardHeader
        contentView.backgroundColor = .Sphinx.DashboardHeader
        selectionStyle = .none

        workspaceNameLabel.textColor = .Sphinx.Text
        workspaceNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)

        roleLabel.textColor = .Sphinx.SecondaryText
        roleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)

        membersLabel.textColor = .Sphinx.SecondaryText
        membersLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)

        separatorView.backgroundColor = .Sphinx.Divider
    }

    func configure(with workspace: Workspace, isLastRow: Bool) {
        workspaceNameLabel.text = workspace.name
        roleLabel.text = workspace.formattedRole
        membersLabel.text = workspace.membersText
        separatorView.isHidden = isLastRow
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected {
            contentView.backgroundColor = .Sphinx.DashboardHeader.withAlphaComponent(0.8)
        } else {
            contentView.backgroundColor = .Sphinx.DashboardHeader
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        if highlighted {
            contentView.backgroundColor = .Sphinx.DashboardHeader.withAlphaComponent(0.8)
        } else {
            contentView.backgroundColor = .Sphinx.DashboardHeader
        }
    }
}
