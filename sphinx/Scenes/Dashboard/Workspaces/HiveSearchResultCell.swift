//
//  HiveSearchResultCell.swift
//  sphinx
//
//  Created on 2026-03-07.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import UIKit

class HiveSearchResultCell: UITableViewCell {

    static let reuseID = "HiveSearchResultCell"
    static var nib: UINib {
        return UINib(nibName: "HiveSearchResultCell", bundle: nil)
    }

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!

    // Keep a reference to the two constraints that change when subtitle is shown/hidden
    // so we can swap them without re-creating constraints every configure call.
    // sep-top normally anchors to subtitle bottom; when hidden it anchors to title bottom.
    private var sepTopToSubtitle: NSLayoutConstraint?
    private var sepTopToTitle: NSLayoutConstraint?

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .Sphinx.Body
        contentView.backgroundColor = .Sphinx.Body
        selectionStyle = .none

        titleLabel.font = UIFont(name: "Roboto-Medium", size: 15)
        titleLabel.textColor = .Sphinx.Text
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = UIFont(name: "Roboto-Regular", size: 13)
        subtitleLabel.textColor = .Sphinx.SecondaryText
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail

        separatorView.backgroundColor = .Sphinx.LightDivider

        // Build the two alternative top constraints for the separator
        sepTopToSubtitle = separatorView.topAnchor.constraint(
            equalTo: subtitleLabel.bottomAnchor, constant: 8
        )
        sepTopToTitle = separatorView.topAnchor.constraint(
            equalTo: titleLabel.bottomAnchor, constant: 8
        )
        // Default: subtitle visible → sep anchors to subtitle
        sepTopToSubtitle?.isActive = true
    }

    func configure(with item: HiveSearchResultItem) {
        titleLabel.text = item.title

        if let featureTitle = item.featureTitle, !featureTitle.isEmpty {
            subtitleLabel.text = featureTitle
            subtitleLabel.isHidden = false
            sepTopToTitle?.isActive = false
            sepTopToSubtitle?.isActive = true
        } else {
            subtitleLabel.text = nil
            subtitleLabel.isHidden = true
            sepTopToSubtitle?.isActive = false
            sepTopToTitle?.isActive = true
        }
    }
}
