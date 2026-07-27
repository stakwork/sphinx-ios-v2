//
//  NewMessageTableViewCell+DelegateExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 14/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation

extension NewMessageTableViewCell : NewMessageReplyViewDelegate {
    func didTapMessageReplyViewWith(height: CGFloat?) {
        if let messageId = messageId {
            delegate?.didTapMessageReplyFor(
                messageId: messageId,
                and: rowIndex,
                with: height
            )
        }
    }
}

extension NewMessageTableViewCell : JoinCallViewDelegate {
    func didTapCopyLink() {
        if let messageId = messageId {
            delegate?.didTapCallLinkCopyFor(messageId: messageId, and: rowIndex)
        }
    }
    
    func didTapAudioButton() {
        if let messageId = messageId {
            delegate?.didTapCallJoinAudioFor(messageId: messageId, and: rowIndex)
        }
    }
    
    func didTapVideoButton() {
        if let messageId = messageId {
            delegate?.didTapCallJoinVideoFor(messageId: messageId, and: rowIndex)
        }
    }
}

extension NewMessageTableViewCell : MediaMessageViewDelegate {
    func didTapMediaButton(isThreadOriginalMsg: Bool) {
        if let messageId = originalMessageId, isThreadOriginalMsg {
            delegate?.didTapMediaButtonFor(messageId: messageId, and: rowIndex, isThreadOriginalMsg: isThreadOriginalMsg)
        } else if let messageId = messageId {
            delegate?.didTapMediaButtonFor(messageId: messageId, and: rowIndex, isThreadOriginalMsg: isThreadOriginalMsg)
        }
    }
    
    func shouldLoadOriginalMessageMediaDataFrom(
        originalMessageMedia: BubbleMessageLayoutState.MessageMedia
    ) {
        if let originalMessageId = originalMessageId {
            let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            let delegate = self.delegate
            let rowIndex: Int = self.rowIndex
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
                if originalMessageMedia.isImage {
                    delegate?.shouldLoadImageDataFor(
                        messageId: originalMessageId,
                        and: rowIndex
                    )
                } else if originalMessageMedia.isPdf {
                    delegate?.shouldLoadPdfDataFor(
                        messageId: originalMessageId,
                        and: rowIndex
                    )
                } else if originalMessageMedia.isVideo {
                    delegate?.shouldLoadVideoDataFor(
                        messageId: originalMessageId,
                        and: rowIndex
                    )
                } else if originalMessageMedia.isGiphy {
                    delegate?.shouldLoadGiphyDataFor(
                        messageId: originalMessageId,
                        and: rowIndex
                    )
                }
            }
        }
    }

    func shouldLoadOriginalMessageFileDataFrom(
        originalMessageFile: BubbleMessageLayoutState.GenericFile
    ) {
        if let originalMessageId = originalMessageId {
            let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            let delegate = self.delegate
            let rowIndex: Int = self.rowIndex
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
                delegate?.shouldLoadFileDataFor(
                    messageId: originalMessageId,
                    and: rowIndex
                )
            }
        }
    }
}

extension NewMessageTableViewCell : FileDetailsViewDelegate {
    func didTapDownloadButton() {
        if let messageId = messageId {
            delegate?.didTapFileDownloadButtonFor(messageId: messageId, and: rowIndex)
        }
    }
}

extension NewMessageTableViewCell : LinkPreviewDelegate {
    func didTapOnTribeButton() {
        if let messageId = messageId {
            delegate?.didTapTribeButtonFor(messageId: messageId, and: rowIndex)
        }
    }
    
    func didTapOnContactButton() {
        if let messageId = messageId {
            delegate?.didTapContactButtonFor(messageId: messageId, and: rowIndex)
        }
    }
    
    func didTapOnWebLinkButton() {
        if let messageId = messageId {
            delegate?.didTapOnLinkButtonFor(messageId: messageId, and: rowIndex)
        }
    }
}

extension NewMessageTableViewCell : ChatAvatarViewDelegate {
    func didTapAvatarView() {
        if let messageId = messageId {
            delegate?.didTapAvatarViewFor(messageId: messageId, and: rowIndex)
        }
    }
}

extension NewMessageTableViewCell : PaidAttachmentViewDelegate {
    func didTapPayButton() {
        if let messageId = messageId {
            delegate?.didTapPayButtonFor(messageId: messageId, and: rowIndex)
        }
    }
}

extension NewMessageTableViewCell : AudioMessageViewDelegate {
    func didTapPlayPauseButton(
        isThreadOriginalMsg: Bool
    ) {
        if let messageId = originalMessageId, isThreadOriginalMsg {
            delegate?.didTapPlayPauseButtonFor(messageId: messageId, and: rowIndex)
        } else if let messageId = messageId {
            delegate?.didTapPlayPauseButtonFor(messageId: messageId, and: rowIndex)
        }
    }
    
    func shouldLoadOriginalMessageAudioDataFrom(originalMessageAudio: BubbleMessageLayoutState.Audio) {
        if let originalMessageId = originalMessageId {
            let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            let delegate = self.delegate
            let rowIndex: Int = self.rowIndex
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
                delegate?.shouldLoadAudioDataFor(
                    messageId: originalMessageId,
                    and: rowIndex
                )
            }
        }
    }
}

extension NewMessageTableViewCell : PodcastAudioViewDelegate {
    func didTapClipPlayPauseButtonAt(time: Double) {
        if let messageId = messageId {
            delegate?.didTapClipPlayPauseButtonFor(messageId: messageId, and: rowIndex, atTime: time)
        }
    }
    
    func shouldSeekTo(time: Double) {
        if let messageId = messageId {
            delegate?.shouldSeekClipFor(messageId: messageId, and: rowIndex, atTime: time)
        }
    }
    
    func shouldToggleReplyGesture(enable: Bool) {
        shouldPreventOtherGestures = !enable
    }
}

extension NewMessageTableViewCell : InvoiceViewDelegate {
    func didTapInvoicePayButton() {
        if let messageId = messageId {
            delegate?.didTapInvoicePayButtonFor(messageId: messageId, and: rowIndex)
        }
    }
}
