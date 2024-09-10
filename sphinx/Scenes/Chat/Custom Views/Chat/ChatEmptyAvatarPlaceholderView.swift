//
//  ChatEmptyAvatarPlaceholder.swift
//  sphinx
//
//  Created by James Carucci on 9/6/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit

class ChatEmptyAvatarPlaceholderView: UIView {

    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var avatarIconImageContainerView: UIView!
    @IBOutlet weak var avatarIconImageView: UIImageView!
    @IBOutlet weak var disclaimerLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        Bundle.main.loadNibNamed("ChatEmptyAvatarPlaceholderView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.backgroundColor = UIColor.clear
        setupAllViews()
    }
    
    func setupAllViews(){
        setupAvatarImageView()
        setupDisclaimerLabel()
    }
    
    func setupAvatarImageView(){
        avatarImageView.sd_setImage(with: URL(string:"https://thispersondoesnotexist.com/"))
        avatarImageView.makeCircular()
        avatarIconImageView.image = avatarIconImageView.image?.withRenderingMode(.alwaysTemplate)
        
        
        avatarIconImageContainerView.makeCircular()
        avatarIconImageView.tintColor = UIColor.Sphinx.Body
        avatarIconImageContainerView.layer.borderColor = UIColor.Sphinx.Body.cgColor
        avatarIconImageContainerView.layer.borderWidth = 3.5
        
    }
    
    func setupDisclaimerLabel() {
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.lineBreakMode = .byWordWrapping
        disclaimerLabel.adjustsFontForContentSizeCategory = true // For Dynamic Type support
        
        disclaimerLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        disclaimerLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
                
        // Force layout update
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
