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
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    @IBOutlet weak var seederCountLabel: UILabel!
    
    var isLoading : Bool = false{
        didSet{
            if(isLoading){
                loadingWheel.isHidden = false
                loadingWheel.startAnimating()
            }
            else{
                loadingWheel.isHidden = true
                loadingWheel.stopAnimating()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
                // Configure the view for the selected state
    }
    
    func configure(withTitle title: String, seeders: Int) {
        self.loadingWheel.isHidden = true
        torrentNameLabel.text = title
        seederCountLabel.text = "\(seeders) seeders"
    }
    
}
