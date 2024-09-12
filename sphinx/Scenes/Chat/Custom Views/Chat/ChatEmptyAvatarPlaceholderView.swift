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
    @IBOutlet weak var dashedOutlinePlaceholderView: UIView!
    @IBOutlet weak var clockIconContainerView: UIView!
    @IBOutlet weak var clockIconImageView: UIImageView!
    @IBOutlet weak var lockIconImageView: UIImageView!
    @IBOutlet weak var initialsLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    
    var inviteDate : Date? = nil
    
    var isPending : Bool = false {
        didSet{
            DispatchQueue.main.async(execute: {
                let dateText = self.inviteDate?.getStringDate(format: "MMMM d yyyy") ?? ""
                let fullDateText = dateText == "" ? "invite.sent".localized : "\("invite.sent.on".localized) \(dateText)"
                let text = (self.isPending == false) ? "messages.encrypted.disclaimer".localized : fullDateText
                self.disclaimerLabel.text = text
                self.pendingChatDisclaimerSubtitle.isHidden = !self.isPending
                self.clockIconContainerView.isHidden = !self.isPending
                self.lockIconImageView.isHidden = self.isPending
                self.clockIconContainerView.makeCircular()
                
                if(self.isPending){
                    self.dashedOutlinePlaceholderView.isHidden = false
                    self.dashedOutlinePlaceholderView.addDottedCircularBorder(lineWidth: 1.0, dashPattern: [8,4], color: UIColor.Sphinx.PlaceholderText)
                    self.avatarImageViewWidthConstraint.constant = 96
                    self.layoutSubviews()
                }
            })
        }
    }
    
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
        avatarImageView.backgroundColor = UIColor.clear
        dashedOutlinePlaceholderView.backgroundColor = UIColor.clear
        setupAllViews()
    }
    
    func setupAllViews(){
        setupDisclaimerLabel()
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
                
        // Force layout update
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    func configureWith(contact:UserContact){
        inviteDate = contact.createdAt
        isPending = contact.isPending()
        let name = contact.nickname ?? "name.unknown".localized
        nameLabel.text = name
        
        if let avatarImage = contact.avatarUrl,
           avatarImage != ""
        {
            setupAvatarImageView(imageUrl: avatarImage)
        }
        else{
            avatarImageView.image = nil
            showInitialsFor(contact, in: initialsLabel)
        }
    }
    
    func configureWith(chat:Chat){
        inviteDate = chat.getContact()?.createdAt
        isPending = chat.isPending()
        
        let name = chat.getContact()?.nickname ?? "name.unknown".localized
        nameLabel.text = name
        
        if let avatarImage = chat.getContact()?.avatarUrl,
           avatarImage != ""
        {
            setupAvatarImageView(imageUrl: avatarImage)
        }
        else{
            guard let contact = chat.getContact() else{
                avatarImageView.image = #imageLiteral(resourceName: "profile_avatar")
                return
            }
            avatarImageView.image = nil
            showInitialsFor(contact, in: initialsLabel)
        }
        
    }
    
    func showInitialsFor(_ contact: UserContact, in label: UILabel) {
        let senderInitials = contact.nickname?.getInitialsFromName() ?? "name.unknown.initials".localized
        let senderColor = contact.getColor()
        
        label.makeCircular()
        label.font = UIFont(name: "Montserrat-Regular", size: 48.0)!
        label.isHidden = false
        label.backgroundColor = senderColor
        label.textColor = UIColor.white
        label.text = senderInitials
    }
}
