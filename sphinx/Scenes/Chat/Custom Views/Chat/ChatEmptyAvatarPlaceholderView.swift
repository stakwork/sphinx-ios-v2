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
    @IBOutlet weak var avatarImageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var disclaimerLabel: UILabel!
    @IBOutlet weak var pendingChatDisclaimerSubtitle: UILabel!
    @IBOutlet weak var dashedOutlineView: UIView!
    @IBOutlet weak var clockIconContainerView: UIView!
    @IBOutlet weak var clockIconImageView: UIImageView!
    @IBOutlet weak var lockIconImageView: UIImageView!
    @IBOutlet weak var initialsLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    
    var inviteDate : Date? = nil
    
    var isPending : Bool = false {
        didSet {
            DispatchQueue.main.async {
                let dateText = self.inviteDate?.getStringDate(format: "MMMM d, yyyy") ?? ""
                let fullDateText = dateText == "" ? "Invited" : "Invited on \(dateText)"
                let text = !self.isPending ? "messages.encrypted.disclaimer".localized : fullDateText
                
                self.disclaimerLabel.text = text
                self.pendingChatDisclaimerSubtitle.isHidden = !self.isPending
                self.clockIconContainerView.isHidden = !self.isPending
                self.lockIconImageView.isHidden = self.isPending
                self.clockIconContainerView.makeCircular()
                
                if self.isPending {
                    self.avatarImageViewWidthConstraint.constant = 86
                    self.layoutIfNeeded()
                    
                    self.dashedOutlineView.addDottedCircularBorder(
                        lineWidth: 1.0,
                        dashPattern: [5, 5],
                        color: UIColor.Sphinx.PlaceholderText
                    )
                } else {
                    self.dashedOutlineView.removeDottedCircularBorder()
                }
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        Bundle.main.loadNibNamed("ChatEmptyAvatarPlaceholderView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        setupAllViews()
    }
    
    func setupAllViews() {
        setupDisclaimerLabel()
        
        contentView.backgroundColor = UIColor.clear
        avatarImageView.backgroundColor = UIColor.clear
        dashedOutlineView.backgroundColor = UIColor.clear
    }
    
    func setupAvatarImageView(imageUrl:String){
        avatarImageView.clipsToBounds = true
        avatarImageView.sd_setImage(with: URL(string:imageUrl))
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.makeCircular()
    }
    
    
    func setupDisclaimerLabel() {
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.lineBreakMode = .byWordWrapping
        disclaimerLabel.adjustsFontForContentSizeCategory = true // For Dynamic Type support
        
        disclaimerLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        disclaimerLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
                
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    func configureWith(contact: UserContact) {
        inviteDate = contact.createdAt
        isPending = contact.isPending()
        
        let name = contact.nickname ?? "name.unknown".localized
        nameLabel.text = name
        
        if let avatarImage = contact.avatarUrl, avatarImage != "" {
            setupAvatarImageView(imageUrl: avatarImage)
        } else {
            avatarImageView.image = nil
            showInitialsFor(contact)
        }
    }
    
    func configureWith(chat: Chat) {
        inviteDate = chat.getContact()?.createdAt
        isPending = chat.isPending()
        
        let name = chat.getContact()?.nickname ?? "name.unknown".localized
        nameLabel.text = name
        
        let contact = chat.getContact()
        
        if let avatarImage = contact?.avatarUrl, avatarImage != "" {
            setupAvatarImageView(imageUrl: avatarImage)
        } else {
            guard let contact = contact else {
                avatarImageView.image = #imageLiteral(resourceName: "profile_avatar")
                return
            }
            avatarImageView.image = nil
            showInitialsFor(contact)
        }
    }
    
    func showInitialsFor(_ contact: UserContact) {
        let senderInitials = contact.nickname?.getInitialsFromName() ?? "name.unknown.initials".localized
        let senderColor = contact.getColor()
        
        initialsLabel.makeCircular()
        initialsLabel.font = UIFont(name: "Montserrat-Regular", size: 48.0)!
        initialsLabel.isHidden = false
        initialsLabel.backgroundColor = senderColor
        initialsLabel.textColor = UIColor.white
        initialsLabel.text = senderInitials
    }
}
