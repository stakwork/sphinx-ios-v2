//
//  PinMessageViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 22/05/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

protocol PinMessageDelegate: class {
    func didTapUnpinButton(message: TransactionMessage)
    func willDismissPresentedVC()
    func shouldNavigateTo(messageId: Int)
}

class PinMessageViewController: UIViewController {
    
    @IBOutlet weak var bottomViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var bottomView: UIStackView!
    @IBOutlet weak var bottomBackgroundView: UIView!
    @IBOutlet weak var avatarView: ChatAvatarView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var messageBubbleView: UIView!
    @IBOutlet weak var messageBubbleArrowView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var unpinButtonView: UIView!
    @IBOutlet weak var unpinButtonContainer: UIStackView!
    
    @IBOutlet weak var popupView: UIView!
    @IBOutlet weak var pinIconView: UIView!
    @IBOutlet weak var popupLabel: UILabel!
    
    weak var delegate: PinMessageDelegate?
    
    var message: TransactionMessage! = nil
    
    var urlRanges = [NSRange]()
    
    var mode = ViewMode.PinnedMessageInfo
    
    public enum ViewMode {
        case MessagePinned
        case MessageUnpinned
        case PinnedMessageInfo
    }
    
    static func instantiate(
        messageId: Int,
        delegate: PinMessageDelegate,
        mode: ViewMode
    ) -> PinMessageViewController {
        let viewController = StoryboardScene.Chat.pinMessageViewController.instantiate()
        
        viewController.message = TransactionMessage.getMessageWith(id: messageId)
        viewController.delegate = delegate
        viewController.mode = mode
        
        return viewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLayout()
        setupMessageData()
        
        animateView()
        setupDismiss()
    }
}

//Setup logic
extension PinMessageViewController {
    func setupLayout() {
        drawArrow()
        
        unpinButtonContainer.layer.borderWidth = 1
        unpinButtonContainer.layer.borderColor = UIColor.Sphinx.SecondaryText.cgColor
        unpinButtonContainer.layer.cornerRadius = unpinButtonContainer.frame.height / 2
        
        popupView.layer.cornerRadius = 20.0
        
        bottomBackgroundView.layer.cornerRadius = 15.0
        
        messageBubbleView.layer.cornerRadius = 5.0
        
        pinIconView.makeCircular()
        
        setupMode()
    }
    
    func drawArrow() {
        let arrowBezierPath = UIBezierPath()
        
        arrowBezierPath.move(to: CGPoint(x: 0, y: 0))
        arrowBezierPath.addLine(to: CGPoint(x: messageBubbleArrowView.frame.width, y: 0))
        arrowBezierPath.addLine(to: CGPoint(x: messageBubbleArrowView.frame.width, y: messageBubbleArrowView.frame.height))
        arrowBezierPath.addLine(to: CGPoint(x: 4, y: messageBubbleArrowView.frame.height))
        arrowBezierPath.addLine(to: CGPoint(x: 0, y: 0))
        arrowBezierPath.close()
        
        let messageArrowLayer = CAShapeLayer()
        messageArrowLayer.path = arrowBezierPath.cgPath
        
        messageArrowLayer.frame = CGRect(
            x: 0, y: 0, width: messageBubbleArrowView.frame.width, height: messageBubbleArrowView.frame.height
        )

        messageArrowLayer.fillColor = UIColor.Sphinx.SentMsgBG.cgColor
        
        messageBubbleArrowView.layer.addSublayer(messageArrowLayer)
    }
    
    func setupMode() {
        switch(self.mode) {
        case .PinnedMessageInfo:
            popupView.isHidden = true
            bottomView.isHidden = false
            break
        case .MessagePinned:
            popupView.isHidden = false
            bottomView.isHidden = true
            popupLabel.text = "message.pinned".localized
            break
        case .MessageUnpinned:
            popupView.isHidden = false
            bottomView.isHidden = true
            popupLabel.text = "message.unpinned".localized
            break
        }
    }
    
    func setupDismiss() {
        if mode == .MessagePinned || mode == .MessageUnpinned {
            DelayPerformedHelper.performAfterDelay(seconds: 2.0, completion: {
                self.animateAlphaAndDismiss()
            })
        }
    }
    
    func setupMessageData() {
        if message.isOutgoing() {
            if let owner = UserContact.getOwner() {
                avatarView.configureForUserWith(
                    color: owner.getColor(),
                    alias: owner.nickname,
                    picture: owner.avatarUrl
                )
                
                usernameLabel.text = owner.nickname
                usernameLabel.textColor = owner.getColor()
            }
        } else {
            avatarView.configureForSenderWith(message: message)
            
            usernameLabel.text = message.senderAlias ?? "Unknown"
            usernameLabel.textColor = ChatHelper.getSenderColorFor(message: message)
        }
        
        unpinButtonView.isHidden = message.chat?.isMyPublicGroup() == false
        
        if let messageContent = message.bubbleMessageContentString, messageContent.isNotEmpty {
            configureWith(
                messageContent: BubbleMessageLayoutState.MessageContent(
                    text: messageContent.removingMarkdownDelimiters,
                    linkMatches: messageContent.stringLinks + messageContent.pubKeyMatches + messageContent.mentionMatches,
                    highlightedMatches: messageContent.highlightedMatches,
                    boldMatches: messageContent.boldMatches,
                    shouldLoadPaidText: false
                )
            )
        } else {
            messageLabel.text = message.bubbleMessageContentString ?? ""
        }
    }
    
    func configureWith(
        messageContent: BubbleMessageLayoutState.MessageContent?
    ) {
        urlRanges = []
        
        if let messageContent = messageContent {
            
            let font = UIFont(name: "Roboto-Regular", size: 15.0)!
            let highlightedFont = UIFont(name: "Roboto-Regular", size: 15.0)!
            let boldFont = UIFont(name: "Roboto-Black", size: 15.0)!
            
            messageLabel.attributedText = nil
            messageLabel.text = nil
            
            if messageContent.hasNoMarkdown {
                messageLabel.text = messageContent.text
                messageLabel.font = font
            } else {
                let messageC = messageContent.text ?? ""
                
                let attributedString = NSMutableAttributedString(string: messageC)
                attributedString.addAttributes(
                    [NSAttributedString.Key.font: font], range: messageC.nsRange
                )
                
                ///Highlighted text formatting
                let highlightedNsRanges = messageContent.highlightedMatches.map {
                    return $0.range
                }
                
                for (index, nsRange) in highlightedNsRanges.enumerated() {
                    
                    ///Subtracting the previous matches delimiter characters since they have been removed from the string
                    let substractionNeeded = index * 2
                    let adaptedRange = NSRange(
                        location: nsRange.location - substractionNeeded,
                        length: min(nsRange.length - 2, (messageContent.text ?? "").count)
                    )
                    
                    attributedString.addAttributes(
                        [
                            NSAttributedString.Key.foregroundColor: UIColor.Sphinx.HighlightedText,
                            NSAttributedString.Key.backgroundColor: UIColor.Sphinx.HighlightedTextBackground,
                            NSAttributedString.Key.font: highlightedFont
                        ],
                        range: adaptedRange
                    )
                }
                
                ///Bold text formatting
                let boldNsRanges = messageContent.boldMatches.map {
                    return $0.range
                }
                
                for (index, nsRange) in boldNsRanges.enumerated() {
                    ///Subtracting the previous matches delimiter characters since they have been removed from the string
                    ///Subtracting the ** characters from the length since removing the chars caused the range to be 4 less chars
                    let substractionNeeded = index * 4
                    let adaptedRange = NSRange(
                        location: nsRange.location - substractionNeeded,
                        length: min(nsRange.length - 4, (messageContent.text ?? "").count)
                    )
                    
                    attributedString.addAttributes(
                        [
                            NSAttributedString.Key.font: boldFont
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
                            NSAttributedString.Key.font: font
                        ],
                        range: match.range
                    )
                    
                    urlRanges.append(match.range)
                }
                
                
                messageLabel.attributedText = attributedString
                messageLabel.isUserInteractionEnabled = true
            }
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(labelTapped(gesture:)))
        
        if urlRanges.isEmpty {
            messageLabel.removeGestureRecognizer(tap)
        } else {
            messageLabel.addGestureRecognizer(tap)
        }
        
        urlRanges = ChatHelper.removeDuplicatedContainedFrom(urlRanges: urlRanges)
    }
    
    @objc func labelTapped(gesture: UITapGestureRecognizer) {
        if let label = gesture.view as? UILabel, let text = label.text {
            for range in urlRanges {
                if gesture.didTapAttributedTextInLabel(label, inRange: range) {
                    var link = (text as NSString).substring(with: range)
                    
                    if link.stringLinks.count > 0 {
                        if !link.contains("http") {
                            link = "http://\(link)"
                        }
                        UIApplication.shared.open(URL(string: link)!, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }
}

//View animations
extension PinMessageViewController {
    func animateView() {
        bottomViewBottomConstraint.constant = -(bottomView.frame.height + 100)
        bottomView.superview?.layoutSubviews()
        
        view.alpha = 0.0
        
        UIView.animate(withDuration: 0.1, animations: {
            self.view.alpha = 1.0
            self.animatePopup()
        }, completion: { _ in
            self.animateBottomViewTo(constant: 0.0)
        })
    }
    
    func animatePopup() {
        if mode == .MessagePinned || mode == .MessageUnpinned {
            self.popupView.alpha = 1.0
        }
    }
    
    func animateBottomViewTo(
        constant: CGFloat,
        completion: (() -> ())? = nil
    ) {
        if mode != .PinnedMessageInfo {
            return
        }
        
        self.bottomViewBottomConstraint.constant = constant
        
        UIView.animate(withDuration: 0.3, animations: {
            self.bottomView.superview?.layoutSubviews()
        }, completion: { _ in
            completion?()
        })
    }
    
    func dismissBottomView(
        completion: (() -> ())? = nil
    ) {
        self.delegate?.willDismissPresentedVC()
        
        self.animateBottomViewTo(constant: -(bottomView.frame.height + 100), completion: {
            self.animateAlphaAndDismiss(completion: completion)
        })
    }
    
    func animateAlphaAndDismiss(
        completion: (() -> ())? = nil
    ) {
        UIView.animate(withDuration: 0.1, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: true)
            WindowsManager.sharedInstance.removeCoveringWindow()
            completion?()
        })
    }
}


//Actions handling
extension PinMessageViewController {
    @IBAction func unpinButtonTapped() {
        dismissBottomView() {
            self.delegate?.didTapUnpinButton(message: self.message)
        }
    }
    
    @IBAction func dismissButtonTapped() {
        if mode == .PinnedMessageInfo {
            dismissBottomView()
        }
    }
    
    @IBAction func navigateToMessageButtonTouched() {
        delegate?.shouldNavigateTo(messageId: self.message.id)
        dismissBottomView()
    }
}
