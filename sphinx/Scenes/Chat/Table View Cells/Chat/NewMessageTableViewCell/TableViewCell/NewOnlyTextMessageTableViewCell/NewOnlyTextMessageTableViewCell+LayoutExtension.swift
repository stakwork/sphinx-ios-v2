//
//  NewOnlyTextMessageTableViewCell+MessageTypesExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 15/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

extension NewOnlyTextMessageTableViewCell {
    
    func configureWith(
        statusHeader: BubbleMessageLayoutState.StatusHeader?
    ) {
        if let statusHeader = statusHeader {
            statusHeaderView.configureWith(statusHeader: statusHeader, uploadProgressData: nil)
        }
    }
    
    func configureWith(
        messageContent: BubbleMessageLayoutState.MessageContent?,
        searchingTerm: String?
    ) {
        urlRanges = []
        
        if let messageContent = messageContent {
            
            messageLabel.attributedText = nil
            messageLabel.text = nil
            
            if messageContent.hasNoMarkdown && searchingTerm == nil {
                messageLabel.text = messageContent.text
                messageLabel.font = UIFont.getMessageFont()
            } else {
                let messageC = messageContent.text ?? ""
                
                let attributedString = NSMutableAttributedString(string: messageC)
                attributedString.addAttributes(
                    [
                        NSAttributedString.Key.font: UIFont.getMessageFont()
                    ], range: messageC.nsRange
                )
                
                ///Highlighted text formatting
                let highlightedNsRanges = messageContent.highlightedMatches.map {
                    return $0.range
                }
                
                for nsRange in highlightedNsRanges {
                    
                    let adaptedRange = NSRange(
                        location: nsRange.location,
                        length: nsRange.length
                    )
                    
                    attributedString.addAttributes(
                        [
                            NSAttributedString.Key.foregroundColor: UIColor.Sphinx.HighlightedText,
                            NSAttributedString.Key.backgroundColor: UIColor.Sphinx.HighlightedTextBackground,
                            NSAttributedString.Key.font: UIFont.getHighlightedMessageFont()
                        ],
                        range: adaptedRange
                    )
                }
                
                ///Bold text formatting
                let boldNsRanges = messageContent.boldMatches.map {
                    return $0.range
                }
                
                for nsRange in boldNsRanges {
                    
                    let adaptedRange = NSRange(
                        location: nsRange.location,
                        length: nsRange.length
                    )
                    
                    attributedString.addAttributes(
                        [
                            NSAttributedString.Key.font: UIFont.getMessageBoldFont()
                        ],
                        range: adaptedRange
                    )
                }
                
                ///Links formatting
                for match in messageContent.linkMatches {
                    
                    attributedString.addAttributes(
                        [
                            NSAttributedString.Key.foregroundColor: UIColor.Sphinx.PrimaryBlue,
                            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
                            NSAttributedString.Key.font: UIFont.getMessageFont()
                        ],
                        range: match.range
                    )
                    
                    urlRanges.append(match.range)
                }
                
                ///Markdown Links formatting
                for (textCheckingResult, _, link, _) in messageContent.linkMarkdownMatches {
                    
                    let nsRange = textCheckingResult.range
                    
                    if let url = URL(string: link) {
                        attributedString.addAttributes(
                            [
                                NSAttributedString.Key.link: url,
                                NSAttributedString.Key.foregroundColor: UIColor.Sphinx.PrimaryBlue,
                                NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
                                NSAttributedString.Key.font: UIFont.getMessageFont()
                            ],
                            range: nsRange
                        )
                    }
                    
                    urlRanges.append(nsRange)
                }
                
                ///Search term formatting
                let term = searchingTerm ?? ""
                let searchingTermRange = (messageC.lowercased() as NSString).range(of: term.lowercased())
                attributedString.addAttributes(
                    [
                        NSAttributedString.Key.backgroundColor: UIColor.Sphinx.PrimaryGreen
                    ], range: searchingTermRange
                )
                
                messageLabel.attributedText = attributedString
                messageLabel.isUserInteractionEnabled = true
            }
        }
        
        if urlRanges.isEmpty {
            messageLabel.removeGestureRecognizer(tap)
        } else {
            messageLabel.addGestureRecognizer(tap)
        }
        
        urlRanges = ChatHelper.removeDuplicatedContainedFrom(urlRanges: urlRanges)
    }
    
    func configureWith(
        avatarImage: BubbleMessageLayoutState.AvatarImage?
    ) {
        if let avatarImage = avatarImage {
            chatAvatarView.configureForUserWith(
                color: avatarImage.color,
                alias: avatarImage.alias,
                picture: avatarImage.imageUrl,
                image: avatarImage.image,
                and: self
            )
        } else {
            chatAvatarView.resetView()
        }
    }
    
    func configureWith(
        bubble: BubbleMessageLayoutState.Bubble
    ) {
        configureWith(direction: bubble.direction)
        configureWith(bubbleState: bubble.grouping, direction: bubble.direction)
    }
    
    func configureWith(
        direction: MessageTableCellState.MessageDirection
    ) {
        let isOutgoing = direction.isOutgoing()
        
        sentMessageMargingView.isHidden = !isOutgoing
        receivedMessageMarginView.isHidden = isOutgoing
        
        receivedArrow.isHidden = isOutgoing
        sentArrow.isHidden = !isOutgoing
        
        messageLabelLeadingConstraint.priority = UILayoutPriority(isOutgoing ? 1 : 1000)
        messageLabelTrailingConstraint.priority = UILayoutPriority(isOutgoing ? 1000 : 1)
        
        let bubbleColor = isOutgoing ? UIColor.Sphinx.SentMsgBG : UIColor.Sphinx.ReceivedMsgBG
        bubbleOnlyText.backgroundColor = bubbleColor
        
        statusHeaderView.configureWith(direction: direction)
    }
    
    func configureWith(
        bubbleState: MessageTableCellState.BubbleState,
        direction: MessageTableCellState.MessageDirection
    ) {
        let outgoing = direction == .Outgoing
        
        switch (bubbleState) {
        case .Isolated:
            chatAvatarContainerView.alpha = outgoing ? 0.0 : 1.0
            statusHeaderViewContainer.isHidden = false
            
            receivedArrow.alpha = 1.0
            sentArrow.alpha = 1.0
            break
        case .First:
            chatAvatarContainerView.alpha = outgoing ? 0.0 : 1.0
            statusHeaderViewContainer.isHidden = false
            
            receivedArrow.alpha = 1.0
            sentArrow.alpha = 1.0
            break
        case .Middle:
            chatAvatarContainerView.alpha = 0.0
            statusHeaderViewContainer.isHidden = true
            
            receivedArrow.alpha = 0.0
            sentArrow.alpha = 0.0
            break
        case .Last:
            chatAvatarContainerView.alpha = 0.0
            statusHeaderViewContainer.isHidden = true
            
            receivedArrow.alpha = 0.0
            sentArrow.alpha = 0.0
            break
        case .Empty:
            break
        }
    }
    
    func configureWith(
        invoiceLines: BubbleMessageLayoutState.InvoiceLines
    ) {
        leftLineContainer.isHidden = true
        rightLineContainer.isHidden = true
        
//        switch (invoiceLines.linesState) {
//        case .None:
//            leftLineContainer.isHidden = true
//            rightLineContainer.isHidden = true
//            break
//        case .Left:
//            leftLineContainer.isHidden = false
//            rightLineContainer.isHidden = true
//            break
//        case .Right:
//            leftLineContainer.isHidden = true
//            rightLineContainer.isHidden = false
//            break
//        case .Both:
//            leftLineContainer.isHidden = false
//            rightLineContainer.isHidden = false
//            break
//        }
    }
}
