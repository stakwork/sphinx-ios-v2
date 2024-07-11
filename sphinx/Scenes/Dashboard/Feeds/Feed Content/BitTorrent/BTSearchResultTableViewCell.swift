//
//  BTSearchResultTableViewCell.swift
//  sphinx
//
//  Created by James Carucci on 7/11/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit

class BTSearchResultTableViewCell: UITableViewCell {

    @IBOutlet weak var torrentNameLabel: UILabel!
    @IBOutlet weak var seederCountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func configure(withTitle title: String, seeders: Int) {
        torrentNameLabel.text = title
        seederCountLabel.text = "\(seeders) seeders"
        //disclosureIndicator.image = UIImage(systemName: "chevron.right")
    }
    
}
