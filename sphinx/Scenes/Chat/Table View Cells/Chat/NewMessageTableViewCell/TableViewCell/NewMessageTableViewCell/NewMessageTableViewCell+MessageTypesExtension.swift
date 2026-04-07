//
//  NewMessageTableViewCell+MessageExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 06/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

extension NewMessageTableViewCell {
    
    func configureWith(
        messageContent: BubbleMessageLayoutState.MessageContent?,
        searchingTerm: String?
    ) {
        urlRanges = []
        
        if let messageContent = messageContent {
            
            textMessageView.isHidden = false
            messageLabel.attributedText = nil
            messageLabel.text = nil
            
            let rendered = NSMutableAttributedString(
                attributedString: ChatHelper.markdownRenderer.render(messageContent.text ?? "")
            )
            if let term = searchingTerm, !term.isEmpty {
                let messageC = messageContent.text ?? ""
                let searchRange = (messageC.lowercased() as NSString).range(of: term.lowercased())
                rendered.addAttributes([.backgroundColor: UIColor.Sphinx.PrimaryGreen], range: searchRange)
            }
            messageLabel.attributedText = rendered
            messageLabel.isUserInteractionEnabled = true
            
            if let messageId = messageId, messageContent.shouldLoadPaidText {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self?.delegate?.shouldLoadTextDataFor(
                        messageId: messageId,
                        and: self?.rowIndex ?? 0
                    )
                }
            }
        }
    }
    
    func configureWith(
        threadMessages: BubbleMessageLayoutState.ThreadMessages?,
        originalMessageMedia: BubbleMessageLayoutState.MessageMedia?,
        originalMessageGenericFile: BubbleMessageLayoutState.GenericFile?,
        originalMessageAudio: BubbleMessageLayoutState.Audio?,
        threadOriginalMsgMediaData: MessageTableCellState.MediaData?,
        bubble: BubbleMessageLayoutState.Bubble,
        mediaDelegate: MediaMessageViewDelegate,
        audioDelegate: AudioMessageViewDelegate
    ) {
        if let threadMessages = threadMessages {
            setMediaContentHeightTo(height: 170.0)
            
            messageThreadView.configureWith(
                threadMessages: threadMessages,
                originalMessageMedia: originalMessageMedia,
                originalMessageGenericFile: originalMessageGenericFile,
                originalMessageAudio: originalMessageAudio,
                mediaData: threadOriginalMsgMediaData,
                bubble: bubble,
                mediaDelegate: mediaDelegate,
                audioDelegate: audioDelegate
            )
            
            messageThreadViewContainer.isHidden = false
        } else {
            setMediaContentHeightTo(
                height: (UIScreen.main.bounds.width - MessageTableCellState.kRowLeftMargin - MessageTableCellState.kRowRightMargin) * 0.7
            )
        }
    }
    
    func setMediaContentHeightTo(
        height: CGFloat
    ) {
        if mediaContentHeightConstraint.constant != height {
            mediaContentHeightConstraint.constant = height
        }
    }
    
    func configureWith(
        threadLastReply: BubbleMessageLayoutState.ThreadLastReply?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let threadLastReply = threadLastReply {
            threadLastReplyHeader.configureWith(threadLastReply: threadLastReply)
            threadLastReplyHeader.isHidden = false
        }
    }
    
    func configureWith(
        messageReply: BubbleMessageLayoutState.MessageReply?,
        and bubble: BubbleMessageLayoutState.Bubble,
        replyViewHeight: CGFloat?
    ) {
        if let messageReply = messageReply {
            messageReplyHeightConstraint.constant = replyViewHeight ?? NewMessageReplyView.kMessageReplyHeight
            
            messageReplyView.configureWith(
                messageReply: messageReply,
                and: bubble,
                delegate: self,
                isExpanded: replyViewHeight != nil
            )
            messageReplyView.isHidden = false
        }
    }
    
    func configureWith(
        directPayment: BubbleMessageLayoutState.DirectPayment?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let directPayment = directPayment {
            directPaymentView.configureWith(directPayment: directPayment, and: bubble)
            directPaymentView.isHidden = false
        }
    }
    
    func configureWith(
        callLink: BubbleMessageLayoutState.CallLink?
    ) {
        if let callLink = callLink {
            callLinkView.configureWith(callLink: callLink, and: self)
            callLinkView.isHidden = false
        }
    }
    
    func configureWith(
        podcastBoost: BubbleMessageLayoutState.PodcastBoost?
    ) {
        if let podcastBoost = podcastBoost {
            podcastBoostView.configureWith(podcastBoost: podcastBoost)
            podcastBoostView.isHidden = false
        }
    }
    
    func configureWith(
        messageMedia: BubbleMessageLayoutState.MessageMedia?,
        mediaData: MessageTableCellState.MediaData?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let messageMedia = messageMedia {
            if messageMedia.isImageLink {
                if let mediaData = mediaData {
                    mediaContentView.configureWith(
                        messageMedia: messageMedia,
                        mediaData: mediaData,
                        isThreadOriginalMsg: false,
                        bubble: bubble,
                        and: self
                    )
                    mediaContentView.isHidden = false
                } else if let messageId = messageId, mediaData == nil {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        self?.delegate?.shouldLoadLinkImageDataFor(
                            messageId: messageId,
                            and: self?.rowIndex ?? 0
                        )
                    }
                }
            } else {
                mediaContentView.configureWith(
                    messageMedia: messageMedia,
                    mediaData: mediaData,
                    isThreadOriginalMsg: false,
                    bubble: bubble,
                    and: self
                )
                
                mediaContentView.isHidden = false
                
                if let messageId = messageId, mediaData == nil {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        let rowIndex = self?.rowIndex ?? 0
                        if messageMedia.isImage {
                            self?.delegate?.shouldLoadImageDataFor(
                                messageId: messageId,
                                and: rowIndex
                            )
                        } else if messageMedia.isPdf {
                            self?.delegate?.shouldLoadPdfDataFor(
                                messageId: messageId,
                                and: rowIndex
                            )
                        } else if messageMedia.isVideo {
                            self?.delegate?.shouldLoadVideoDataFor(
                                messageId: messageId,
                                and: rowIndex
                            )
                        } else if messageMedia.isGiphy {
                            self?.delegate?.shouldLoadGiphyDataFor(
                                messageId: messageId,
                                and: rowIndex
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
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self?.delegate?.shouldLoadFileDataFor(
                        messageId: messageId,
                        and: self?.rowIndex ?? 0
                    )
                }
            }
        }
    }
    
    func configureWith(
        audio: BubbleMessageLayoutState.Audio?,
        mediaData: MessageTableCellState.MediaData?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let audio = audio {
            audioMessageView.configureWith(
                audio: audio,
                mediaData: mediaData,
                isThreadOriginalMsg: false,
                bubble: bubble,
                and: self
            )
            audioMessageView.isHidden = false
            
            if let messageId = messageId, mediaData == nil {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self?.delegate?.shouldLoadAudioDataFor(
                        messageId: messageId,
                        and: self?.rowIndex ?? 0
                    )
                }
            }
        }
    }
    
    func configureWith(
        podcastComment: BubbleMessageLayoutState.PodcastComment?,
        mediaData: MessageTableCellState.MediaData?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let podcastComment = podcastComment {
            podcastAudioView.configureWith(
                podcastComment: podcastComment,
                mediaData: mediaData,
                bubble: bubble,
                and: self
            )
            podcastAudioView.isHidden = false
            
            if let messageId = messageId, mediaData == nil {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self?.delegate?.shouldPodcastCommentDataFor(
                        messageId: messageId,
                        and: self?.rowIndex ?? 0
                    )
                }
            }
        }
    }
    
    func configureWith(
        payment: BubbleMessageLayoutState.Payment?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let payment = payment {
            invoicePaymentView.configureWith(payment: payment, and: bubble)
            invoicePaymentView.isHidden = false
            
            rightPaymentDot.isHidden = bubble.direction.isIncoming()
            leftPaymentDot.isHidden = bubble.direction.isOutgoing()
        } else {
            rightPaymentDot.isHidden = true
            leftPaymentDot.isHidden = true
        }
    }
    
    func configureWith(
        invoice: BubbleMessageLayoutState.Invoice?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let invoice = invoice {
            invoiceView.configureWith(invoice: invoice, bubble: bubble, and: self)
            invoiceView.isHidden = false
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
    
    func configureWith(
        contactLink: BubbleMessageLayoutState.ContactLink?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let contactLink = contactLink {
            contactLinkPreviewView.configureWith(contactLink: contactLink, and: bubble, delegate: self)
            contactLinkPreviewView.isHidden = false
        }
    }
    
    func configureWith(
        tribeLink: BubbleMessageLayoutState.TribeLink?,
        tribeData: MessageTableCellState.TribeData?,
        and bubble: BubbleMessageLayoutState.Bubble
    ) {
        if let _ = tribeLink {
            if let tribeData = tribeData {
                tribeLinkPreviewView.configureWith(tribeData: tribeData, and: bubble, delegate: self)
                tribeLinkPreviewView.isHidden = false
            } else if let messageId = messageId {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self?.delegate?.shouldLoadTribeInfoFor(
                        messageId: messageId,
                        and: self?.rowIndex ?? 0
                    )
                }
            }
        }
    }
    
    func configureWith(
        webLink: BubbleMessageLayoutState.WebLink?,
        linkData: MessageTableCellState.LinkData?
    ) {
        if let _ = webLink {
            if let linkData = linkData {
                if !linkData.failed {
                    linkPreviewView.configureWith(linkData: linkData, delegate: self)
                    linkPreviewView.isHidden = false
                }
            } else if let messageId = messageId {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self?.delegate?.shouldLoadLinkDataFor(
                        messageId: messageId,
                        and: self?.rowIndex ?? 0
                    )
                }
            }
        }
    }
}
