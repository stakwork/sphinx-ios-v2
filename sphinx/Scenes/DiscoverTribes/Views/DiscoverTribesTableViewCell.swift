//
//  DiscoverTribesTableViewCell.swift
//  sphinx
//
//  Created by James Carucci on 1/4/23.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

protocol DiscoverTribesCellDelegate: class {
    func handleJoin(url:URL)
}

class DiscoverTribesTableViewCell: UITableViewCell {
    
    
    @IBOutlet weak var tribeImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var joinButton: UIButton!
    
    var tribeData: DiscoverTribeData? = nil
    weak var delegate : DiscoverTribesCellDelegate? = nil
    
    static let reuseID = "DiscoverTribesTableViewCell"
    
    static let nib: UINib = {
        UINib(nibName: "DiscoverTribesTableViewCell", bundle: nil)
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func configureCell(tribeData:DiscoverTribeData,wasJoined:Bool){
        if let urlString = tribeData.imgURL,
           let url = URL(string: urlString) {
            
            tribeImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "tribePlaceholder"))
            tribeImageView.layer.cornerRadius = 24
            tribeImageView.clipsToBounds = true
        }
        else if tribeData.imgURL == nil{
            tribeImageView.sd_setImage(with: URL(string: ""), placeholderImage: UIImage(named: "tribePlaceholder"))
        }
        
        titleLabel.text = tribeData.name
        descriptionLabel.text = tribeData.description
        
        configureJoinButton(tribeData: tribeData,wasJoined:wasJoined)
        styleCell()
    }
    
    func styleCell(){
        self.tribeImageView.layer.cornerRadius = 6.0
        self.backgroundColor = UIColor.Sphinx.Body
        self.contentView.backgroundColor = UIColor.Sphinx.Body
        self.titleLabel.textColor = UIColor.Sphinx.PrimaryText
        self.descriptionLabel.textColor = UIColor.Sphinx.SecondaryText
    }
    
    func configureJoinButton(
        tribeData: DiscoverTribeData,
        wasJoined: Bool
    ){
        self.tribeData = tribeData
        
        joinButton.layer.cornerRadius = 15.0
        joinButton.isEnabled = tribeData.pubkey != nil
        
        if wasJoined {
            joinButton.backgroundColor = UIColor.Sphinx.ReceivedMsgBG
            joinButton.setTitle("open".localized, for: .normal)
            joinButton.setTitleColor(UIColor.Sphinx.BodyInverted, for: .normal)
        } else {
            joinButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
            joinButton.setTitle("join".localized, for: .normal)
            joinButton.setTitleColor(UIColor.white, for: .normal)
        }
    }
    
    @IBAction func joinButtonTapped(_ sender: Any) {
        if let tribeData = tribeData, let pubkey = tribeData.pubkey {
            let host = tribeData.host ?? SphinxOnionManager.sharedInstance.tribesServerIP
            
            guard let joinLinkUrl = URL(string: "sphinx.chat://?action=tribeV2&pubkey=\(pubkey)&host=\(host)") else {
                return
            }
            self.delegate?.handleJoin(url: joinLinkUrl)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()

        tribeImageView.image = nil
        descriptionLabel.text = ""
        titleLabel.text = ""
    }
    
}
