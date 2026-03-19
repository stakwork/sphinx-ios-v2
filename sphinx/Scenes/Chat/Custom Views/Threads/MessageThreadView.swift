//
//  MessageThreadView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 24/07/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

class MessageThreadView: UIView {
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var originalMessageBubbleView: UIView!
    @IBOutlet weak var originalMessageContainer: UIView!
    @IBOutlet weak var originalMessageLabel: UILabel!
    
    @IBOutlet weak var originalMessageMediaViewContainer: UIView!
    @IBOutlet weak var originalMessageMediaView: MediaMessageView!
    @IBOutlet weak var originalMessageFileDetails: FileDetailsView!
    @IBOutlet weak var originalMessageAudioView: AudioMessageView!
    
    @IBOutlet weak var firstReplyContainer: UIView!
    @IBOutlet weak var firstReplyBubbleView: UIView!
    @IBOutlet weak var firstReplyAvatarView: ChatAvatarView!
    @IBOutlet weak var firstReplyAvatarOverlay: UIView!
    
    @IBOutlet weak var secondReplyContainer: UIView!
    @IBOutlet weak var secondReplyBubbleView: UIView!
    @IBOutlet weak var secondReplyAvatarView: ChatAvatarView!
    @IBOutlet weak var secondReplyAvatarOverlay: UIView!
    
    @IBOutlet weak var moreRepliesContainer: UIView!
    @IBOutlet weak var moreRepliesBubbleView: UIView!
    @IBOutlet weak var moreRepliesCountView: UIView!
    @IBOutlet weak var moreRepliesCountLabel: UILabel!
    @IBOutlet weak var moreRepliesLabel: UILabel!
    
    @IBOutlet weak var messageFakeBubbleView: UIView!
    
    var mentionsBadgeContainer: UIView?
    var mentionsBadgeLabel: UILabel?
    private var badgeLeadingAfterLabel: NSLayoutConstraint?
    private var badgeLeadingStandalone: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        Bundle.main.loadNibNamed("MessageThreadView", owner: self, options: nil)
        addSubview(contentView)
        
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        setupViews()
        setupMentionsBadge()
    }
    
    func setupMentionsBadge() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.Sphinx.PrimaryBlue
        container.layer.cornerRadius = 10
        container.clipsToBounds = true
        container.isHidden = true
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -3)
        ])
        
        // Add badge inside moreRepliesBubbleView.
        // Two mutually exclusive leading constraints:
        // - after moreRepliesLabel (when count+label are visible)
        // - from bubble leading edge (when only badge is shown, no count/label)
        moreRepliesBubbleView.addSubview(container)
        
        let afterLabel = container.leadingAnchor.constraint(equalTo: moreRepliesLabel.trailingAnchor, constant: 8)
        let standalone = container.leadingAnchor.constraint(equalTo: moreRepliesBubbleView.leadingAnchor, constant: 16)
        standalone.isActive = true
        
        NSLayoutConstraint.activate([
            container.centerYAnchor.constraint(equalTo: moreRepliesBubbleView.topAnchor, constant: 17),
            container.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        badgeLeadingAfterLabel = afterLabel
        badgeLeadingStandalone = standalone
        
        mentionsBadgeContainer = container
        mentionsBadgeLabel = label
    }
    
    func setupViews() {
        moreRepliesLabel.text = "more-replies".localized
        
        originalMessageLabel.numberOfLines = 2
        originalMessageBubbleView.layer.cornerRadius = 9
        originalMessageContainer.layer.cornerRadius = 9
        
        originalMessageMediaView.setMarginTo(0.5)
        
        firstReplyBubbleView.layer.cornerRadius = 9
        firstReplyBubbleView.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        firstReplyBubbleView.layer.borderWidth = 1
        
        firstReplyAvatarOverlay.layer.cornerRadius = firstReplyAvatarOverlay.frame.height / 2
        firstReplyAvatarOverlay.alpha = 0.5
        
        secondReplyBubbleView.layer.cornerRadius = 9
        secondReplyBubbleView.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        secondReplyBubbleView.layer.borderWidth = 1
        
        secondReplyAvatarOverlay.layer.cornerRadius = secondReplyAvatarOverlay.frame.height / 2
        secondReplyAvatarOverlay.alpha = 0.5
        
        moreRepliesBubbleView.layer.cornerRadius = 9
        moreRepliesBubbleView.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        moreRepliesBubbleView.layer.borderWidth = 1
        
        messageFakeBubbleView.layer.cornerRadius = 9
        
        moreRepliesCountView.layer.cornerRadius = moreRepliesCountView.frame.height / 2
        
        firstReplyAvatarView.setInitialLabelSize(size: 11)
        firstReplyAvatarView.resetView()
        
        secondReplyAvatarView.setInitialLabelSize(size: 11)
        secondReplyAvatarView.resetView()
    }
    
    func hideAllSubviews() {
        originalMessageMediaViewContainer.isHidden = true
        originalMessageFileDetails.isHidden = true
        originalMessageContainer.isHidden = true
        originalMessageAudioView.isHidden = true
    }
    
    func configureWith(
        threadMessages: BubbleMessageLayoutState.ThreadMessages,
        originalMessageMedia: BubbleMessageLayoutState.MessageMedia?,
        originalMessageGenericFile: BubbleMessageLayoutState.GenericFile?,
        originalMessageAudio: BubbleMessageLayoutState.Audio?,
        mediaData: MessageTableCellState.MediaData?,
        bubble: BubbleMessageLayoutState.Bubble,
        mediaDelegate: MediaMessageViewDelegate,
        audioDelegate: AudioMessageViewDelegate
    ) {
        hideAllSubviews()
        
        ///Colors configuration for direction
        originalMessageBubbleView.backgroundColor = bubble.direction.isIncoming() ? UIColor.Sphinx.ThreadOriginalMsg : UIColor.Sphinx.SentMsgBG
        originalMessageContainer.backgroundColor = bubble.direction.isIncoming() ? UIColor.Sphinx.ThreadOriginalMsg : UIColor.Sphinx.SentMsgBG
        messageFakeBubbleView.backgroundColor = bubble.direction.isIncoming() ? UIColor.Sphinx.ThreadLastReply : UIColor.Sphinx.ReceivedMsgBG
        
        originalMessageLabel.textColor = bubble.direction.isIncoming() ? UIColor.Sphinx.MainBottomIcons : UIColor.Sphinx.TextMessages
        originalMessageLabel.alpha = bubble.direction.isIncoming() ? 1.0 : 0.6
        
        ///Content configuration
        originalMessageLabel.text = threadMessages.originalMessage.text
        originalMessageLabel.font = UIFont.getMessageFont()
        originalMessageContainer.isHidden = threadMessages.originalMessage.text == nil || threadMessages.originalMessage.text?.isEmpty == true
        
        let firstReplySenderInfo = threadMessages.firstReplySenderIndo
        
        firstReplyAvatarView.configureForUserWith(
            color: firstReplySenderInfo.0,
            alias: firstReplySenderInfo.1,
            picture: firstReplySenderInfo.2
        )
        
        if let secondReplySenderInfo = threadMessages.secondReplySenderInfo {
            secondReplyAvatarView.configureForUserWith(
                color: secondReplySenderInfo.0,
                alias: secondReplySenderInfo.1,
                picture: secondReplySenderInfo.2
            )
            secondReplyContainer.isHidden = false
        } else {
            secondReplyContainer.isHidden = true
        }
        
        let mentionsCount = threadMessages.mentionsCount
        let hasMoreReplies = threadMessages.moreRepliesCount > 0
        
        if hasMoreReplies {
            moreRepliesCountLabel.text = "\(threadMessages.moreRepliesCount)"
            moreRepliesCountView.isHidden = false
            moreRepliesLabel.isHidden = false
        } else {
            moreRepliesCountView.isHidden = true
            moreRepliesLabel.isHidden = true
        }
        
        // Show moreRepliesContainer when there are extra replies OR mention badge to display
        moreRepliesContainer.isHidden = !hasMoreReplies && mentionsCount == 0
        
        if mentionsCount > 0 {
            mentionsBadgeLabel?.text = "@ \(mentionsCount)"
            mentionsBadgeContainer?.isHidden = false
            if hasMoreReplies {
                badgeLeadingStandalone?.isActive = false
                badgeLeadingAfterLabel?.isActive = true
            } else {
                badgeLeadingAfterLabel?.isActive = false
                badgeLeadingStandalone?.isActive = true
            }
        } else {
            mentionsBadgeContainer?.isHidden = true
        }
        
        configureMediaWith(
            originalMessageMedia: originalMessageMedia,
            mediaData: mediaData,
            bubble: bubble,
            and: mediaDelegate
        )
        
        configureFileWith(
            originalMessageGenericFile: originalMessageGenericFile,
            mediaData: mediaData,
            bubble: bubble,
            and: mediaDelegate
        )
        
        configureAudioWith(
            audio: originalMessageAudio,
            mediaData: mediaData,
            bubble: bubble,
            and: audioDelegate
        )
    }
    
    func configureMediaWith(
        originalMessageMedia: BubbleMessageLayoutState.MessageMedia?,
        mediaData: MessageTableCellState.MediaData?,
        bubble: BubbleMessageLayoutState.Bubble,
        and delegate: MediaMessageViewDelegate
    ) {
        if let originalMessageMedia = originalMessageMedia {
            originalMessageMediaViewContainer.isHidden = false
            
            originalMessageMediaView.configureWith(
                messageMedia: originalMessageMedia,
                mediaData: mediaData,
                isThreadOriginalMsg: true,
                bubble: bubble,
                and: delegate
            )
            
            if mediaData == nil {
                delegate.shouldLoadOriginalMessageMediaDataFrom(originalMessageMedia: originalMessageMedia)
            }
        }
    }
    
    func configureFileWith(
        originalMessageGenericFile: BubbleMessageLayoutState.GenericFile?,
        mediaData: MessageTableCellState.MediaData?,
        bubble: BubbleMessageLayoutState.Bubble,
        and delegate: MediaMessageViewDelegate
    ) {
        if let originalMessageGenericFile = originalMessageGenericFile {
            originalMessageFileDetails.isHidden = false
            
            originalMessageFileDetails.configureWith(
                mediaData: mediaData,
                and: nil
            )
            
            if mediaData == nil {
                delegate.shouldLoadOriginalMessageFileDataFrom(originalMessageFile: originalMessageGenericFile)
            }
        }
    }
    
    func configureAudioWith(
        audio: BubbleMessageLayoutState.Audio?,
        mediaData: MessageTableCellState.MediaData?,
        bubble: BubbleMessageLayoutState.Bubble,
        and delegate: AudioMessageViewDelegate
    ) {
        if let audio = audio {
            originalMessageAudioView.configureWith(
                audio: audio,
                mediaData: mediaData,
                isThreadOriginalMsg: true,
                bubble: bubble,
                and: delegate
            )
            originalMessageAudioView.isHidden = false
            
            if mediaData == nil {
                delegate.shouldLoadOriginalMessageAudioDataFrom(originalMessageAudio: audio)
            }
        }
    }
}
