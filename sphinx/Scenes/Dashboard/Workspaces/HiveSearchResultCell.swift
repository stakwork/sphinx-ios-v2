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

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .Sphinx.Body
        contentView.backgroundColor = .Sphinx.Body
        selectionStyle = .none

        titleLabel.font = UIFont(name: "Roboto-Medium", size: 15)
        titleLabel.textColor = .Sphinx.Text
        titleLabel.numberOfLines = 2

        subtitleLabel.font = UIFont(name: "Roboto-Regular", size: 13)
        subtitleLabel.textColor = .Sphinx.SecondaryText
        subtitleLabel.numberOfLines = 1

        separatorView.backgroundColor = .Sphinx.LightDivider
    }

    func configure(with item: HiveSearchResultItem) {
        titleLabel.text = item.title

        if let featureTitle = item.featureTitle, !featureTitle.isEmpty {
            subtitleLabel.text = featureTitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.text = nil
            subtitleLabel.isHidden = true
        }
    }
}
