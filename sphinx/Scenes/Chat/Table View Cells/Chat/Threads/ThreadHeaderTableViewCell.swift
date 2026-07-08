//
//  ThreadHeaderTableViewCell.swift
//  sphinx
//
//  Created by Tomas Timinskas on 02/08/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

@MainActor protocol ThreadHeaderTableViewCellDelegate: class {
    func shouldExpandHeaderMessage()
    
    func shouldLoadImageDataFor(messageId: Int, and rowIndex: Int)
    func shouldLoadPdfDataFor(messageId: Int, and rowIndex: Int)
    func shouldLoadFileDataFor(messageId: Int, and rowIndex: Int)
    func shouldLoadVideoDataFor(messageId: Int, and rowIndex: Int)
    func shouldLoadGiphyDataFor(messageId: Int, and rowIndex: Int)
    func shouldLoadAudioDataFor(messageId: Int, and rowIndex: Int)
    func shouldLoadLinkImageDataFor(messageId: Int, and rowIndex: Int)
    
    func didTapMediaButtonFor(messageId: Int, and rowIndex: Int, isThreadOriginalMsg: Bool)
    func didTapFileDownloadButtonFor(messageId: Int, and rowIndex: Int)
    func didTapPlayPauseButtonFor(messageId: Int, and rowIndex: Int)
    
    func didTapOnLink(_ link: String)
    func didLongPressOn(cell: UITableViewCell, with messageId: Int, bubbleViewRect: CGRect)
}

class ThreadHeaderTableViewCell: UITableViewCell {
    
    weak var delegate: ThreadHeaderTableViewCellDelegate!
    
    var rowIndex: Int!
    var messageId: Int?
    
    @IBOutlet weak var mediaMessageView: MediaMessageView!
    @IBOutlet weak var fileDetailsView: FileDetailsView!
    @IBOutlet weak var audioMessageView: AudioMessageView!
    @IBOutlet weak var messageBoostView: NewMessageBoostView!
    @IBOutlet weak var messageContainer: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var senderNameLabel: UILabel!
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var senderAvatarView: ChatAvatarView!
    @IBOutlet weak var showMoreLabel: UILabel!
    @IBOutlet weak var showMoreContainer: UIView!
    @IBOutlet weak var bottomMarginView: UIView!
    @IBOutlet weak var differenceViewHeightConstraint: NSLayoutConstraint!
    
    var tap: UITapGestureRecognizer! = nil
    var urlRanges = [NSRange]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.contentView.clipsToBounds = false
        
        mediaMessageView.layer.cornerRadius = 9
        mediaMessageView.clipsToBounds = true
        
        fileDetailsView.layer.cornerRadius = 9
        fileDetailsView.clipsToBounds = true
        
        audioMessageView.layer.cornerRadius = 9
        audioMessageView.clipsToBounds = true
        
        tap = UITapGestureRecognizer(target: self, action: #selector(labelTapped(gesture:)))
        
        mediaMessageView.removeMargin()
        
        addLongPressRescognizer()
    }
    
    func addLongPressRescognizer() {
        let lpgr = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        lpgr.minimumPressDuration = 0.5
        lpgr.delaysTouchesBegan = true
        
        contentView.addGestureRecognizer(lpgr)
    }
    
    @objc func handleLongPress(gestureReconizer: UILongPressGestureRecognizer) {
        if (gestureReconizer.state == .began) {
            didLongPressOnCell()
        }
    }
    
    func didLongPressOnCell() {
        if let messageId = messageId {
            
            let kMargin: CGFloat = 16
            let contentViewFrame = contentView.frame
            
            let frame = CGRect(
                x: contentViewFrame.origin.x,
                y: contentViewFrame.origin.y - kMargin,
                width: contentViewFrame.size.width,
                height: contentViewFrame.size.height - differenceViewHeightConstraint.constant + kMargin
            )
            
            delegate?.didLongPressOn(
                cell: self,
                with: messageId,
                bubbleViewRect: frame
            )
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func hideAllSubviews() {
        mediaMessageView.isHidden = true
        fileDetailsView.isHidden = true
        messageContainer.isHidden = true
        audioMessageView.isHidden = true
        messageBoostView.isHidden = true
    }
    
    func configureWith(
        messageCellState: MessageTableCellState,
        mediaData: MessageTableCellState.MediaData?,
        isHeaderExpanded: Bool,
        delegate: ThreadHeaderTableViewCellDelegate,
        indexPath: IndexPath,
        headerDifference: CGFloat?
    ) {
        var mutableMessageCellState = messageCellState
        
        self.delegate = delegate
        self.rowIndex = indexPath.row
        self.messageId = mutableMessageCellState.messageId
        
        hideAllSubviews()
        
        configureWith(
            threadOriginalMessage: mutableMessageCellState.threadOriginalMessageHeader,
            isHeaderExpanded: isHeaderExpanded,
            headerDifference: headerDifference
        )
        
        configureWith(messageMedia: mutableMessageCellState.messageMedia, mediaData: mediaData)
        configureWith(genericFile: mutableMessageCellState.genericFile, mediaData: mediaData)
        configureWith(audio: mutableMessageCellState.audio, mediaData: mediaData)
        
        if let bubble = mutableMessageCellState.bubble {
            configureWith(boosts: mutableMessageCellState.boosts, and: bubble)
        }
    }
    
    func configureWith(
        threadOriginalMessage: NoBubbleMessageLayoutState.ThreadOriginalMessage?,
        isHeaderExpanded: Bool,
        headerDifference: CGFloat?
    ) {
        guard let threadOriginalMessage = threadOriginalMessage else {
            return
        }
        
        if threadOriginalMessage.text.isNotEmpty {
            messageContainer.isHidden = false
        }
        
        addLinksToLabel(threadOriginalMessage: threadOriginalMessage)
        
        messageLabel.numberOfLines = isHeaderExpanded ? 0 : 12
        
        // Ensure the label knows its layout width for correct intrinsic-size
        // calculation when numberOfLines > 0 and Auto Layout needs to resolve the
        // multi-line height.  We set it here (after numberOfLines is assigned) so
        // it is always current for the content being displayed.
        let labelWidth: CGFloat = messageLabel.bounds.width > 0
            ? messageLabel.bounds.width
            : UIScreen.main.bounds.width - 32
        messageLabel.preferredMaxLayoutWidth = labelWidth
        
        timestampLabel.text = threadOriginalMessage.timestamp
        senderNameLabel.text = threadOriginalMessage.senderAlias
        
        senderAvatarView.configureForUserWith(
            color: threadOriginalMessage.senderColor,
            alias: threadOriginalMessage.senderAlias,
            picture: threadOriginalMessage.senderPic
        )
        
        showMoreContainer.isHidden = !showMoreVisible(isHeaderExpanded)
        bottomMarginView.isHidden = !showMoreVisible(isHeaderExpanded)
        
        differenceViewHeightConstraint.constant = headerDifference ?? 0
    }
    
    func addLinksToLabel(
        threadOriginalMessage: NoBubbleMessageLayoutState.ThreadOriginalMessage
    ) {
        urlRanges = []
        
        let rendered = NSMutableAttributedString(
            attributedString: ChatHelper.markdownRenderer.render(threadOriginalMessage.text)
        )
        ChatHelper.applySphinxLinkTransforms(to: rendered)
        
        rendered.enumerateAttribute(.sphinxURL, in: NSRange(location: 0, length: rendered.length)) { value, range, _ in
            if value != nil { urlRanges.append(range) }
        }
        
        messageLabel.attributedText = rendered
        messageLabel.isUserInteractionEnabled = true
        
        if urlRanges.isEmpty {
            messageLabel.removeGestureRecognizer(tap)
        } else {
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
                    if let url = attributedText.attribute(.sphinxURL, at: range.location, effectiveRange: nil) as? URL {
                        delegate?.didTapOnLink(url.absoluteString)
                    } else {
                        let link = (attributedText.string as NSString).substring(with: range)
                        delegate?.didTapOnLink(link)
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
            if messageMedia.isImageLink {
                if let mediaData = mediaData {
                    mediaMessageView.configureWith(
                        messageMedia: messageMedia,
                        mediaData: mediaData,
                        isThreadOriginalMsg: false,
                        bubble: BubbleMessageLayoutState.Bubble(direction: .Incoming, grouping: .Isolated),
                        and: self
                    )
                    mediaMessageView.isHidden = false
                }
//                else if let messageId = messageId, mediaData == nil {
//                    let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
//                    DispatchQueue.global().asyncAfter(deadline: delayTime) {
//                        self.delegate?.shouldLoadLinkImageDataFor(
//                            messageId: messageId,
//                            and: self.rowIndex
//                        )
//                    }
//                }
            } else {
                mediaMessageView.configureWith(
                    messageMedia: messageMedia,
                    mediaData: mediaData,
                    isThreadOriginalMsg: false,
                    bubble: BubbleMessageLayoutState.Bubble(direction: .Incoming, grouping: .Isolated),
                    and: self
                )
                
                mediaMessageView.isHidden = false
                
                if let messageId = messageId, mediaData == nil {
                    let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                    DispatchQueue.global().asyncAfter(deadline: delayTime) {
                        if messageMedia.isImage {
                            self.delegate?.shouldLoadImageDataFor(
                                messageId: messageId,
                                and: self.rowIndex
                            )
                        } else if messageMedia.isPdf {
                            self.delegate?.shouldLoadPdfDataFor(
                                messageId: messageId,
                                and: self.rowIndex
                            )
                        } else if messageMedia.isVideo {
                            self.delegate?.shouldLoadVideoDataFor(
                                messageId: messageId,
                                and: self.rowIndex
                            )
                        } else if messageMedia.isGiphy {
                            self.delegate?.shouldLoadGiphyDataFor(
                                messageId: messageId,
                                and: self.rowIndex
                            )
                        }
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
            
            fileDetailsView.configureWith(
                mediaData: mediaData,
                and: self
            )
            
            fileDetailsView.isHidden = false
            
            if let messageId = messageId, mediaData == nil {
                let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.global().asyncAfter(deadline: delayTime) {
                    self.delegate?.shouldLoadFileDataFor(
                        messageId: messageId,
                        and: self.rowIndex
                    )
                }
            }
        }
    }
    
    func configureWith(
        audio: BubbleMessageLayoutState.Audio?,
        mediaData: MessageTableCellState.MediaData?
    ) {
        if let audio = audio {
            
            audioMessageView.configureWith(
                audio: audio,
                mediaData: mediaData,
                isThreadOriginalMsg: false,
                bubble: BubbleMessageLayoutState.Bubble(direction: .Incoming, grouping: .Isolated),
                and: self
            )
            
            audioMessageView.isHidden = false
            
            if let messageId = messageId, mediaData == nil {
                let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.global().asyncAfter(deadline: delayTime) {
                    self.delegate?.shouldLoadAudioDataFor(
                        messageId: messageId,
                        and: self.rowIndex
                    )
                }
            }
        }
    }
    
    func configureWith(
        boosts: BubbleMessageLayoutState.Boosts?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let boosts = boosts {
            messageBoostView.configureWith(boosts: boosts, and: bubble)
            messageBoostView.isHidden = false
        }
    }
    
    func showMoreVisible(
        _ isHeaderExpanded: Bool
    ) -> Bool {
        return !isHeaderExpanded && isLabelTruncated() && (messageLabel.text ?? "").isNotEmpty
    }
    
    /// Non-cached: recomputes every call from the rendered attributedText (or plain text
    /// fallback) so cell reuse always reflects the current message's content.
    var labelHeight: CGFloat {
        // Prefer measuring the actual rendered attributed string (mixed fonts, code
        // blocks, line spacing) over the plain-text single-font estimate, which
        // systematically under-counts the real rendered height.
        let measureWidth: CGFloat
        if messageLabel.bounds.width > 0 {
            measureWidth = messageLabel.bounds.width
        } else {
            // Before the first layout pass use the container width minus horizontal
            // padding (16 pt leading + 16 pt trailing inside the outer stack).
            measureWidth = UIScreen.main.bounds.width - 32
        }
        
        if let attributed = messageLabel.attributedText, attributed.length > 0 {
            let boundingRect = attributed.boundingRect(
                with: CGSize(width: measureWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            return ceil(boundingRect.height)
        }
        
        // Fallback: plain-text measurement (used when attributedText is not set yet).
        return UILabel.getTextSize(
            width: measureWidth,
            text: messageLabel.text ?? "",
            font: messageLabel.font
        ).height
    }

    func isLabelTruncated() -> Bool {
        guard let text = messageLabel.text, text.isNotEmpty else {
            return false
        }
        
        let maximumHeight: CGFloat = 240
        
        return labelHeight > maximumHeight
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Reset attributed text so labelHeight (now a computed var) returns a fresh
        // value on the next configuration rather than measuring stale content.
        messageLabel.attributedText = nil
        messageLabel.text = nil
    }
    
    @IBAction func showMoreButtonTouched() {
        delegate?.shouldExpandHeaderMessage()
    }
}

extension ThreadHeaderTableViewCell : MediaMessageViewDelegate {
    func didTapMediaButton(isThreadOriginalMsg: Bool) {
        if let messageId = messageId {
            delegate?.didTapMediaButtonFor(messageId: messageId, and: rowIndex, isThreadOriginalMsg: isThreadOriginalMsg)
        }
    }
    
    func shouldLoadOriginalMessageMediaDataFrom(originalMessageMedia: BubbleMessageLayoutState.MessageMedia) {}
    func shouldLoadOriginalMessageFileDataFrom(originalMessageFile: BubbleMessageLayoutState.GenericFile) {}
}

extension ThreadHeaderTableViewCell : FileDetailsViewDelegate {
    func didTapDownloadButton() {
        if let messageId = messageId {
            delegate?.didTapFileDownloadButtonFor(messageId: messageId, and: rowIndex)
        }
    }
}

extension ThreadHeaderTableViewCell : AudioMessageViewDelegate {
    func didTapPlayPauseButton(isThreadOriginalMsg: Bool) {
        if let messageId = messageId {
            delegate?.didTapPlayPauseButtonFor(messageId: messageId, and: rowIndex)
        }
    }
    
    func shouldLoadOriginalMessageAudioDataFrom(originalMessageAudio: BubbleMessageLayoutState.Audio) {}
}
