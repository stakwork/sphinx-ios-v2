//
//  NewChatViewModel+SendMessageExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 16/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

extension NewChatViewModel {
    func shouldSendGiphyMessage(
        text: String,
        type: Int,
        data: Data,
        completion: @escaping (Bool, String?) -> ()
    ) {
        chatDataSource?.setMediaDataForMessageWith(
            messageId: SphinxOnionManager.sharedInstance.uniqueIntHashFromString(stringInput: UUID().uuidString),
            mediaData: MessageTableCellState.MediaData(
                image: data.gifImageFromData(),
                failed: false
            )
        )
        
        shouldSendMessage(
            text: text,
            type: type,
            provisionalMessage: nil,
            completion: completion
        )
    }
    
    func shouldSendMessage(
        text: String,
        type: Int,
        provisionalMessage: TransactionMessage?,
        completion: @escaping (Bool, String?) -> ()
    ) {
        var messageText = text
        
        if messageText.isEmpty {
            return
        }
        
        if let podcastComment = podcastComment {
            messageText = podcastComment.getJsonString(withComment: text) ?? text
        }
        
        let (_, wrongAmount) = isWrongBotCommandAmount(text: messageText)
        
        if wrongAmount {
            completion(false, "Wrong Amount")
            return
        }
        guard let chat = chat else{
            completion(false, "Chat not found")
            return
        }
        
        let tuuid = threadUUID ?? replyingTo?.threadUUID ?? replyingTo?.uuid
        
        let (validMessage, errorMsg) = SphinxOnionManager.sharedInstance.sendMessage(
            to: contact,
            content: messageText,
            chat: chat,
            provisionalMessage: provisionalMessage,
            msgType: UInt8(type),
            threadUUID: tuuid,
            replyUUID: replyingTo?.uuid
        )
        
        let message = validMessage?.makeProvisional(chat: self.chat)
        updateSnapshotWith(message: message)
        
        completion(validMessage != nil, errorMsg)
        
        if let message = validMessage {
            joinIfCallMessage(message: message)
        }
        
        resetReply()
    }
    
    
    func updateSnapshotWith(
        message: TransactionMessage?
    ) {
        guard let message = message else {
            return
        }
        
        chatDataSource?.updateSnapshotWith(message: message)
    }
    
    func deleteMessageWith(
        id: Int?
    ) {
        if let id = id {
            TransactionMessage.deleteMessageWith(id: id)
        }
    }

    func insertSentMessage(
        message: TransactionMessage,
        completion: @escaping (Bool) -> ()
    ) {
        ChatTrackingHandler.shared.deleteOngoingMessage(with: chat?.id)

        joinIfCallMessage(message: message)
        showBoostErrorAlert(message: message)
        
        resetReply()
        
        completion(true)
    }

    func joinIfCallMessage(
        message: TransactionMessage
    ) {
        if message.isCallMessageType() {
            if let link = message.messageContent {
                VideoCallManager.sharedInstance.startVideoCall(
                    link: link,
                    shouldStartRecording: chat?.hasSecondBrainApp() == true || chat?.hasWebApp() == true,
                    audioOnly: link.contains("startAudioOnly=true")
                )
            }
        }
    }
    
    func showBoostErrorAlert(
        message: TransactionMessage
    ) {
        if message.isMessageBoost() && message.failed() {
            AlertHelper.showAlert(title: "boost.error.title".localized, message: message.errorMessage ?? "generic.error.message".localized)
        }
    }

    func isWrongBotCommandAmount(
        text: String
    ) -> (Int, Bool) {
        let (botAmount, failureMessage) = GroupsManager.sharedInstance.calculateBotPrice(chat: chat, text: text)
        
        if let failureMessage = failureMessage {
            AlertHelper.showAlert(title: "generic.error.title".localized, message: failureMessage)
            return (botAmount, true)
        }
        
        return (botAmount, false)
    }
    
    func shouldSendTribePayment(
        amount: Int,
        message: String,
        messageUUID: String,
        callback: (() -> ())?
    ) {
        //TODO: @Jim reimplement on V2
        
//        guard let params = TransactionMessage.getTribePaymentParams(
//            chat: chat,
//            messageUUID: messageUUID,
//            amount: amount,
//            text: message
//        ) else {
//            callback?()
//            return
//        }
//        sendMessage(provisionalMessage: nil, params: params, completion: { _ in
//            callback?()
//        })
    }
    
    func createCallMessage(sender: UIButton) {
        VideoCallHelper.createCallMessage(
            button: sender,
            secondBrainUrl: chat?.getSecondBrainAppUrl(),
            appUrl: chat?.getAppUrl(),
            callback: { link in
                self.sendCallMessage(link: link)
            }
        )
    }
    
    func sendCallMessage(link: String) {
        let voipRequestMessage = VoIPRequestMessage()
        voipRequestMessage.recurring = false
        voipRequestMessage.link = link
        voipRequestMessage.cron = ""
        
        let messageText = voipRequestMessage.getCallLinkMessage() ?? link
        
        self.shouldSendMessage(
            text: messageText,
            type: TransactionMessage.TransactionMessageType.call.rawValue,
            provisionalMessage: nil,
            completion: { _, _ in }
        )
    }
}
