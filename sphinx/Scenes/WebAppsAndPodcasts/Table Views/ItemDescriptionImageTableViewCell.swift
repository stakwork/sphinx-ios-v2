//
//  ItemDescriptionImageTableViewCell.swift
//  sphinx
//
//  Created by James Carucci on 4/4/23.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

class ItemDescriptionImageTableViewCell: UITableViewCell {

    static let reuseID = "ItemDescriptionImageTableViewCell"
    
    @IBOutlet weak var itemImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()

        Task { @MainActor in
            self.itemImageView.layer.cornerRadius = 10.0
            self.itemImageView.clipsToBounds = true
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configureView(
        imageURL: String?,
        placeHolderImage: String
    ) {
        if let imageURL = imageURL, let url = URL(string: imageURL) {
            itemImageView.sd_setImage(
                with: url,
                placeholderImage: UIImage(named: placeHolderImage),
                options: [.highPriority],
                progress: nil
            )
        } else {
            itemImageView.image = UIImage(named: placeHolderImage)
        }
    }
    
}
