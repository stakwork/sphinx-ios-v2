//
//  CommonNewMessageTableViewCell.swift
//  sphinx
//
//  Created by Tomas Timinskas on 15/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

class CommonNewMessageTableViewCell : SwipableReplyCell {
    
    weak var delegate: NewMessageTableViewCellDelegate!
    
    var rowIndex: Int!
    var messageId: Int?
    var originalMessageId: Int?
    
    var urlRanges = [NSRange]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        addLongPressRescognizer()
    }
    
    @objc func labelTapped(
        gesture: UITapGestureRecognizer
    ) {
        if let label = gesture.view as? UILabel, let attributedText = label.attributedText {
            for range in urlRanges {
                if gesture.didTapAttributedTextInLabel(
                    label,
                    inRange: range
                ) {
                    if let link = (attributedText.attribute(.link, at: range.location, effectiveRange: nil) as? URL)?.absoluteString {
                        delegate?.didTapOnLink(link)
                    } else {
                        let link = (attributedText.string as NSString).substring(with: range)
                        delegate?.didTapOnLink(link)
                    }
                }
            }
        }
    }
    
    
    func addLongPressRescognizer() {
        let lpgr = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        lpgr.minimumPressDuration = 0.5
        lpgr.delaysTouchesBegan = true
        
        contentView.addGestureRecognizer(lpgr)
    }
    
    @objc func handleLongPress(gestureReconizer: UILongPressGestureRecognizer) {
        if (gestureReconizer.state == .began) {
            if shouldPreventOtherGestures {
                return
            }
            didLongPressOnCell()
        }
    }
    
    func getBubbleView() -> UIView? {
        return nil
    }
    
    func didLongPressOnCell() {
        if let messageId = messageId, let bubbleView = getBubbleView() {
            delegate?.didLongPressOn(
                cell: self,
                with: messageId,
                bubbleViewRect: bubbleView.frame
            )
        }
    }
    
    override func didSwipeToReplay() {
        if let messageId = messageId {
            SoundsPlayer.playHaptic()
            
            delegate?.shouldReplyToMessageWith(messageId: messageId, and: rowIndex)
        }
    }
}
