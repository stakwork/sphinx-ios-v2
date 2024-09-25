//
//  ThreadHeaderView.swift
//  sphinx
//
//  Created by James Carucci on 7/19/23.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit
import SDWebImage

@objc protocol ThreadHeaderViewDelegate {
    func didTapBackButton()
    
    @objc optional func didTapThreadHeaderButton()
    
    @objc optional func shouldLoadImageDataFor(messageId: Int, and rowIndex: Int)
    @objc optional func shouldLoadPdfDataFor(messageId: Int, and rowIndex: Int)
    @objc optional func shouldLoadFileDataFor(messageId: Int, and rowIndex: Int)
    @objc optional func shouldLoadVideoDataFor(messageId: Int, and rowIndex: Int)
    @objc optional func shouldLoadGiphyDataFor(messageId: Int, and rowIndex: Int)
    @objc optional func shouldLoadAudioDataFor(messageId: Int, and rowIndex: Int)
}

class ThreadHeaderView : UIView {
    
    weak var delegate : ThreadHeaderViewDelegate? = nil
    
    var messageId: Int?
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var messageLabelContainer: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    
    @IBOutlet weak var messageAndMediaContainer: UIView!
    @IBOutlet weak var messageAndMediaLabel: UILabel!
    @IBOutlet weak var mediaView: ThreadMediaView!
    @IBOutlet weak var messageBoostView: NewMessageBoostView!
    
    @IBOutlet weak var senderContainer: UIView!
    @IBOutlet weak var senderNameLabel: UILabel!
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var senderAvatarView: ChatAvatarView!
    
    var isExpanded : Bool = false
    var isBoosted: Bool = false
    
    var viewToShow: UIView! = nil
    
    var urlRanges = [NSRange]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        Bundle.main.loadNibNamed("ThreadHeaderView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        mediaView.layer.cornerRadius = 4
        mediaView.clipsToBounds = true
    }
    
    func configureWith(
        messageCellState: MessageTableCellState,
        mediaData: MessageTableCellState.MediaData?,
        delegate: ThreadHeaderViewDelegate
    ){
        var mutableMessageCellState = messageCellState
        
        self.delegate = delegate
        self.messageId = mutableMessageCellState.messageId
        
        configureWith(threadOriginalMessage: mutableMessageCellState.threadOriginalMessageHeader)
        configureWith(messageMedia: mutableMessageCellState.messageMedia, mediaData: mediaData)
        configureWith(genericFile: mutableMessageCellState.genericFile, mediaData: mediaData)
        configureWith(audio: mutableMessageCellState.audio, mediaData: mediaData)
        
        if let bubble = mutableMessageCellState.bubble {
            configureWith(boosts: mutableMessageCellState.boosts, and: bubble)
        }
    }
    
    func configureWith(
        threadOriginalMessage: NoBubbleMessageLayoutState.ThreadOriginalMessage?
    ) {
        guard let threadOriginalMessage = threadOriginalMessage else {
            return
        }
        
        viewToShow = messageLabelContainer
        
        configureMessageContentWith(threadOriginalMessage: threadOriginalMessage)
        
        timestampLabel.text = threadOriginalMessage.timestamp
        senderNameLabel.text = threadOriginalMessage.senderAlias
        
        senderAvatarView.configureForUserWith(
            color: threadOriginalMessage.senderColor,
            alias: threadOriginalMessage.senderAlias,
            picture: threadOriginalMessage.senderPic
        )
    }
    
    func configureMessageContentWith(
        threadOriginalMessage: NoBubbleMessageLayoutState.ThreadOriginalMessage
    ) {
        messageAndMediaLabel.attributedText = nil
        messageAndMediaLabel.text = nil
        
        messageLabel.attributedText = nil
        messageLabel.text = nil
        
        if threadOriginalMessage.hasNoMarkdown {
            messageAndMediaLabel.text = threadOriginalMessage.text
            messageAndMediaLabel.font = UIFont.getThreadHeaderFont()
            
            messageLabel.text = threadOriginalMessage.text
            messageLabel.font = UIFont.getThreadHeaderFont()
        } else {
            let messageC = threadOriginalMessage.text
            
            let attributedString = NSMutableAttributedString(string: messageC)
            attributedString.addAttributes(
                [NSAttributedString.Key.font: UIFont.getThreadHeaderFont()], range: messageC.nsRange
            )
            
            ///Highlighted text formatting
            let highlightedNsRanges = threadOriginalMessage.highlightedMatches.map {
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
                        NSAttributedString.Key.font: UIFont.getThreadHeaderHightlightedFont()
                    ],
                    range: adaptedRange
                )
            }
            
            ///Bold text formatting
            let boldNsRanges = threadOriginalMessage.boldMatches.map {
                return $0.range
            }
            
            for nsRange in boldNsRanges {
                
                let adaptedRange = NSRange(
                    location: nsRange.location,
                    length: nsRange.length
                )
                
                attributedString.addAttributes(
                    [
                        NSAttributedString.Key.font: UIFont.getThreadHeaderBoldFont()
                    ],
                    range: adaptedRange
                )
            }
            
            ///Links formatting
            for match in threadOriginalMessage.linkMatches {
                
                attributedString.addAttributes(
                    [
                        NSAttributedString.Key.foregroundColor: UIColor.Sphinx.PrimaryBlue,
                        NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
                        NSAttributedString.Key.font: UIFont.getThreadHeaderFont()
                    ],
                    range: match.range
                )
                
                urlRanges.append(match.range)
            }
            
            ///Markdown Links formatting
            for (textCheckingResult, _, link, _) in threadOriginalMessage.linkMarkdownMatches {
                
                let nsRange = textCheckingResult.range
                
                if let url = URL(string: link) {
                    attributedString.addAttributes(
                        [
                            NSAttributedString.Key.link: url,
                            NSAttributedString.Key.foregroundColor: UIColor.Sphinx.PrimaryBlue,
                            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
                            NSAttributedString.Key.font: UIFont.getThreadHeaderFont()
                        ],
                        range: nsRange
                    )
                }
                
                urlRanges.append(nsRange)
            }
            
            messageAndMediaLabel.attributedText = attributedString
            messageLabel.attributedText = attributedString
            messageAndMediaLabel.isUserInteractionEnabled = true
            messageLabel.isUserInteractionEnabled = true
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(labelTapped(gesture:)))
        
        if urlRanges.isEmpty {
            messageAndMediaLabel.removeGestureRecognizer(tap)
            messageLabel.removeGestureRecognizer(tap)
        } else {
            messageAndMediaLabel.addGestureRecognizer(tap)
            messageLabel.addGestureRecognizer(tap)
        }
        
        urlRanges = ChatHelper.removeDuplicatedContainedFrom(urlRanges: urlRanges)
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
                        UIApplication.shared.open(URL(string: link)!, options: [:], completionHandler: nil)
                    } else {
                        let link = (attributedText.string as NSString).substring(with: range)
                        UIApplication.shared.open(URL(string: link)!, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }
    
    func configureWith(
        messageMedia: BubbleMessageLayoutState.MessageMedia?,
        mediaData: MessageTableCellState.MediaData?
    ) {
        if let messageMedia = messageMedia {
            
            viewToShow = messageAndMediaContainer
            
            mediaView.configureWith(
                messageMedia: messageMedia,
                mediaData: mediaData,
                bubble: BubbleMessageLayoutState.Bubble(direction: .Incoming, grouping: .Isolated)
            )

            if let messageId = messageId, mediaData == nil {
                let delayTime = DispatchTime.now() + Double(Int64(0.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.global().asyncAfter(deadline: delayTime) {
                    if messageMedia.isImage {
                        self.delegate?.shouldLoadImageDataFor?(
                            messageId: messageId,
                            and: -1
                        )
                    } else if messageMedia.isPdf {
                        self.delegate?.shouldLoadPdfDataFor?(
                            messageId: messageId,
                            and: -1
                        )
                    } else if messageMedia.isVideo {
                        self.delegate?.shouldLoadVideoDataFor?(
                            messageId: messageId,
                            and: -1
                        )
                    } else if messageMedia.isGiphy {
                        self.delegate?.shouldLoadGiphyDataFor?(
                            messageId: messageId,
                            and: -1
                        )
                    }
                }
            }
        }
    }
    
    func configureWith(
        genericFile: BubbleMessageLayoutState.GenericFile?,
        mediaData: MessageTableCellState.MediaData?
    ) {
        if let _ = genericFile {
            
            viewToShow = messageAndMediaContainer
            
            mediaView.configureForGenericFile()
            
            if let messageId = messageId, mediaData == nil {
                let delayTime = DispatchTime.now() + Double(Int64(0.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.global().asyncAfter(deadline: delayTime) {
                    self.delegate?.shouldLoadFileDataFor?(
                        messageId: messageId,
                        and: -1
                    )
                }
            }
        }
    }
    
    func configureWith(
        audio: BubbleMessageLayoutState.Audio?,
        mediaData: MessageTableCellState.MediaData?
    ) {
        if let _ = audio {
            
            viewToShow = messageAndMediaContainer
            
            mediaView.configureForAudio()
            
            if let messageId = messageId, mediaData == nil {
                let delayTime = DispatchTime.now() + Double(Int64(0.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.global().asyncAfter(deadline: delayTime) {
                    self.delegate?.shouldLoadAudioDataFor?(
                        messageId: messageId,
                        and: -1
                    )
                }
            }
        }
    }
    
    func configureWith(
        boosts: BubbleMessageLayoutState.Boosts?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        isBoosted = false
        
        if let boosts = boosts {
            messageBoostView.configureWith(boosts: boosts, and: bubble)
            isBoosted = true
        }
    }
    
    func toggleThreadHeaderView(expanded: Bool) {
        let newAlpha = expanded ? 1.0 : 0.0
        if newAlpha == senderContainer.alpha {
            return
        }
        
        if expanded {
            self.senderContainer.isHidden = false
            self.viewToShow.isHidden = false
            self.messageBoostView.isHidden = !isBoosted
            
            UIView.animate(withDuration: 0.2, animations: {
                self.senderContainer.alpha = 1.0
                self.viewToShow.alpha = 1.0
                self.messageBoostView.alpha = 1.0
            })
        } else {
            self.viewToShow.alpha = 0.0
            self.viewToShow.isHidden = true
            self.messageBoostView.isHidden = true
            
            UIView.animate(withDuration: 0.2, animations: {
                self.senderContainer.alpha = 0.0
                self.messageBoostView.alpha = 0.0
            }, completion: { _ in
                self.senderContainer.isHidden = true
            })
        }
    }
    
    @IBAction func headerButtonTouched() {
        delegate?.didTapThreadHeaderButton?()
    }
    
    @IBAction func backButtonTouched() {
        delegate?.didTapBackButton()
    }
}
