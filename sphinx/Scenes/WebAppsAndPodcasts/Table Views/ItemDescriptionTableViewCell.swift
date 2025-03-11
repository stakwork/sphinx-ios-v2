//
//  ItemDescriptionTableViewCell.swift
//  sphinx
//
//  Created by James Carucci on 4/4/23.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

protocol ItemDescriptionTableViewCellDelegate{
    func didExpandCell()
}

class ItemDescriptionTableViewCell: UITableViewCell {
    
    @IBOutlet weak var showMoreLabel: UILabel!
    @IBOutlet weak var podcastDescriptionLabel: UILabel!
    @IBOutlet weak var chaptersContainer: UIStackView!
    @IBOutlet weak var chaptersContainerHeightConstraint: NSLayoutConstraint!
    
    static let reuseID = "ItemDescriptionTableViewCell"
    
    let kChapterHeight: CGFloat = 40
    let kChapterTitleHeight: CGFloat = 30
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configureView(
        descriptionText: String,
        isExpanded: Bool,
        chapters: [Chapter]
    ){
        //Description
        if isExpanded {
            podcastDescriptionLabel.text = descriptionText
            podcastDescriptionLabel.numberOfLines = 0
            showMoreLabel.isHidden = true
        } else {
            podcastDescriptionLabel.text = descriptionText
            podcastDescriptionLabel.numberOfLines = 5
            podcastDescriptionLabel.lineBreakMode = .byTruncatingTail
            showMoreLabel.isHidden = false
        }
        
        //Chapters list
        chaptersContainerHeightConstraint.constant = CGFloat(chapters.count) * kChapterHeight + kChapterTitleHeight
        chaptersContainer.layoutSubviews()
        
        for view in chaptersContainer.subviews {
            if view.isKind(of: EpisodeChapterView.self) {
                view.removeFromSuperview()
            }
        }
        
        for (index, chapter) in chapters.enumerated() {
            let newChapterView = EpisodeChapterView(
                frame: CGRect(
                    x: 0,
                    y: (index * Int(kChapterHeight)) + Int(kChapterTitleHeight),
                    width: Int(UIScreen.main.bounds.size.width),
                    height: Int(kChapterHeight)
                )
            )
            newChapterView.heightAnchor.constraint(equalToConstant: 40).isActive = true
            newChapterView.translatesAutoresizingMaskIntoConstraints = false
            chaptersContainer.addArrangedSubview(newChapterView)
            
            newChapterView.configureWith(
                chapter: chapter,
                delegate: nil,
                index: index,
                episodeRow: false
            )
        }
    }
}
