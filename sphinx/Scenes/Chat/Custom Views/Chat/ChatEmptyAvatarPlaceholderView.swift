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
    @IBOutlet weak var pendingChatDisclaimerTitle: UILabel!
    @IBOutlet weak var pendingChatDisclaimerSubtitle: UILabel!
    @IBOutlet weak var dashedOutlinePlaceholderView: UIView!
    
    
    var inviteDate : Date? = nil
    
    var isPending : Bool = false {
        didSet{
            DispatchQueue.main.async(execute: {
                let dateText = self.inviteDate?.getStringDate(format: "MMMM d yyyy") ?? ""
                let fullDateText = dateText == "" ? "Invited you" : "Invited you on \(dateText)"
                let text = (self.isPending == false) ? "messages.encrypted.disclaimer".localized : fullDateText
                self.disclaimerLabel.text = text
                self.pendingChatDisclaimerTitle.isHidden = !self.isPending
                self.pendingChatDisclaimerSubtitle.isHidden = !self.isPending
                
                if(self.isPending){
                    self.avatarIconImageView.image = #imageLiteral(resourceName: "clock_icon")
                    self.dashedOutlinePlaceholderView.isHidden = false
                    self.dashedOutlinePlaceholderView.addDottedCircularBorder(lineWidth: 1.0, dashPattern: [8,4], color: UIColor.Sphinx.PlaceholderText)
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
        //setupAvatarImageView()
        setupDisclaimerLabel()
    }
    
    func setupAvatarImageView(imageUrl:String){
        avatarImageView.sd_setImage(with: URL(string:imageUrl))
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
    
    func configureWith(contact:UserContact){
        inviteDate = contact.createdAt
        isPending = contact.isPending()
        
        
        if let avatarImage = contact.avatarUrl,
           avatarImage != ""
        {
            setupAvatarImageView(imageUrl: avatarImage)
        }
        else{
            avatarImageView.image = nil
            setupAvatarImageView(imageUrl: "https://thispersondoesnotexist.com/")
            //TODO: @emptyChat: need to set up initials container
//            showInitialsFor(contact, in: avatarImageView, and: initialsLabelContainer)
        }
    }
    
    func configureWith(chat:Chat){
        inviteDate = chat.getContact()?.createdAt
        isPending = chat.isPending()
        
        if let avatarImage = chat.getContact()?.avatarUrl,
           avatarImage != ""
        {
//            setupAvatarImageView(imageUrl: avatarImage)
        }
        else{
            avatarImageView.image = nil
            //showInitialsFor(chat.getContact(), in: avatarImageView, and: initialsLabelContainer)
        }
        
    }
    
    func showInitialsFor(_ contact: UserContact, in label: UILabel) {
        let senderInitials = contact.nickname?.getInitialsFromName() ?? "name.unknown.initials".localized
        let senderColor = contact.getColor()
        
        label.isHidden = false
        label.backgroundColor = senderColor
        label.textColor = UIColor.white
        label.text = senderInitials
    }
}
