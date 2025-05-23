//
//  SphinxOnionManager+ChatExtension.swift
//  sphinx
//
//  Created by James Carucci on 12/4/23.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation
import CocoaMQTT
import SwiftyJSON

extension SphinxOnionManager {
    
    func getChatWithTribeOrContactPubkey(
        contactPubkey: String?,
        tribePubkey: String?
    ) -> Chat? {
        if let contact = UserContact.getContactWithDisregardStatus(pubkey: contactPubkey ?? ""), let oneOnOneChat = contact.getChat() {
            return oneOnOneChat
        } else if let tribeChat = Chat.getTribeChatWithOwnerPubkey(ownerPubkey: tribePubkey ?? "") {
            return tribeChat
        }
        return nil
    }
    
    func fetchOrCreateChatWithTribe(
        ownerPubkey: String,
        host: String?,
        index: Int,
        completion: @escaping (Chat?, Bool, Int) -> ()
    ) {
        if (chatsFetchParams?.restoredTribesPubKeys ?? []).contains(ownerPubkey) {
            ///Tribe restore in progress
            completion(nil, false, index)
            return
        }
        
        if (messageFetchParams?.restoredTribesPubKeys ?? []).contains(ownerPubkey) {
            if let chat = Chat.getTribeChatWithOwnerPubkey(ownerPubkey: ownerPubkey) {
                completion(chat, false, index)
            } else {
                completion(nil, false, index)
            }
            return
        }
        
        if deletedTribesPubKeys.contains(ownerPubkey) {
            ///Tribe deleted
            completion(nil, false, index)
            return
        }
        
        chatsFetchParams?.restoredTribesPubKeys.append(ownerPubkey)
        messageFetchParams?.restoredTribesPubKeys.append(ownerPubkey)
        
        if let chat = Chat.getTribeChatWithOwnerPubkey(ownerPubkey: ownerPubkey) {
            ///Tribe restore found, no need to restore
            completion(chat, false, index)
        } else if let host = host {
            ///Tribe not found in the database, attempt to lookup and restore.
            GroupsManager.sharedInstance.lookupAndRestoreTribe(pubkey: ownerPubkey, host: host) { chat in
                completion(chat, chat != nil, index)
            }
        } else {
            completion(nil, false, index)
        }
    }
    
    func loadMediaToken(
        recipPubkey: String?,
        muid: String?,
        price: Int? = nil
    ) -> String? {
        guard let seed = getAccountSeed(), let recipPubkey = recipPubkey, let muid = muid, let expiry = Calendar.current.date(byAdding: .year, value: 1, to: Date()) else {
            return nil
        }
        do {
            let hostname = "memes.sphinx.chat"
            var mt: String
            
            if (price == nil) {
                mt = try makeMediaToken(
                    seed: seed,
                    uniqueTime: getTimeWithEntropy(),
                    state: loadOnionStateAsData(),
                    host: hostname,
                    muid: muid,
                    to: recipPubkey,
                    expiry: UInt32(expiry.timeIntervalSince1970)
                )
            } else {
                mt = try makeMediaTokenWithPrice(
                    seed: seed,
                    uniqueTime: getTimeWithEntropy(),
                    state: loadOnionStateAsData(),
                    host: hostname,
                    muid: muid,
                    to: recipPubkey,
                    expiry: UInt32(expiry.timeIntervalSince1970),
                    price: UInt64((price!))
                )
            }
            return mt
        } catch {
            return nil
        }
    }
    
    func formatMsg(
        content: String,
        type: UInt8,
        muid: String? = nil,
        purchaseItemAmount: Int? = nil,
        recipPubkey: String? = nil,
        mediaKey: String? = nil,
        mediaType: String? = "file",
        threadUUID: String?,
        replyUUID: String?,
        invoiceString: String?,
        tribeKickMember: String? = nil,
        paidAttachmentMediaToken: String? = nil,
        isTribe: Bool,
        metaData: String? = nil
    ) -> (String?, String?)? {
        
        var msg: [String: Any] = ["content": content]
        var mt: String? = nil
        
        if let metaData = metaData {
            msg["metadata"] = metaData
        }
        
        switch TransactionMessage.TransactionMessageType(rawValue: Int(type)) {
        case .message, .boost, .delete, .call, .groupLeave, .memberReject, .memberApprove,.groupDelete:
            break
        case .attachment, .directPayment, .purchaseAccept, .purchaseDeny:
            
            msg["mediaKey"] = mediaKey
            msg["mediaKeyForSelf"] = mediaKey
            msg["mediaType"] = mediaType
            
            if Int(type) == TransactionMessage.TransactionMessageType.purchaseAccept.rawValue ||
               Int(type) == TransactionMessage.TransactionMessageType.purchaseDeny.rawValue
            {
                ///reference mediaToken made by sender of encrypted message we are paying for
                mt = paidAttachmentMediaToken
            } else {
                ///create a media token corresponding to attachment (paid or unpaid)
                mt = loadMediaToken(recipPubkey: recipPubkey, muid: muid, price: purchaseItemAmount)
            }
            msg["mediaToken"] = mt
            
            if let _ = purchaseItemAmount {
                ///Remove content if it's a paid text message
                if mediaType == "sphinx/text" {
                    msg.removeValue(forKey: "content")
                }
                
                ///Remove mediaKey if it's a conversation, otherwise send it since tribe admin will custodial it
                if !isTribe {
                    msg.removeValue(forKey: "mediaKey")
                }
            }
            break
        case .invoice, .payment:
            msg["invoice"] = invoiceString
            break
        case .groupKick:
            if let member = tribeKickMember {
                msg["member"] = member
            } else {
                return nil
            }
            break
        case .purchase:
            if let paidAttachmentMediaToken = paidAttachmentMediaToken {
                mt = paidAttachmentMediaToken
                msg["mediaToken"] = mt
            } else {
                return nil
            }
            break
        default:
            return nil
        }
        
        replyUUID != nil ? (msg["replyUuid"] = replyUUID) : ()
        threadUUID != nil ? (msg["threadUuid"] = threadUUID) : ()
        
        guard let contentData = try? JSONSerialization.data(withJSONObject: msg), let contentJSONString = String(data: contentData, encoding: .utf8) else {
            return nil
        }
        
        return (contentJSONString, mt)
    }
    
    func sendMessage(
        to recipContact: UserContact?,
        content: String,
        chat: Chat,
        provisionalMessage: TransactionMessage?,
        amount: Int = 0,
        purchaseAmount: Int? = nil,
        shouldSendAsKeysend: Bool = false,
        msgType: UInt8 = 0,
        muid: String? = nil,
        mediaKey: String? = nil,
        mediaType: String? = nil,
        threadUUID: String?,
        replyUUID: String?,
        invoiceString: String? = nil,
        tribeKickMember: String? = nil,
        paidAttachmentMediaToken: String? = nil
    ) -> (TransactionMessage?, String?) {
        
        guard let seed = getAccountSeed() else {
            return (nil, "Account seed not found")
        }
        
        let isTribe = recipContact == nil
        
        guard let selfContact = UserContact.getOwner(),
              let nickname = isTribe ? (chat.myAlias?.isNotEmpty == true ? chat.myAlias : selfContact.nickname)?.fixedAlias : (chat.myAlias?.isNotEmpty == true ? chat.myAlias : selfContact.nickname),
              let recipPubkey = recipContact?.publicKey ?? chat.ownerPubkey
        else {
            return (nil, "Owner not found")
        }
        
        let metaData = chat.getMetaDataJsonStringValue()
        
        guard let (contentJSONString, mediaToken) = formatMsg(
            content: content,
            type: msgType,
            muid: muid,
            purchaseItemAmount: purchaseAmount,
            recipPubkey: recipPubkey,
            mediaKey: mediaKey,
            mediaType: mediaType,
            threadUUID: threadUUID,
            replyUUID: replyUUID,
            invoiceString: invoiceString,
            tribeKickMember: tribeKickMember,
            paidAttachmentMediaToken: paidAttachmentMediaToken,
            isTribe: isTribe,
            metaData: metaData
        ) else {
            return (nil, "Msg json format issue")
        }
        
        guard let contentJSONString = contentJSONString else {
            return (nil, "Msg json format issue")
        }
        
        let myImg = (chat.myPhotoUrl?.isNotEmpty == true ? (chat.myPhotoUrl ?? "") : (selfContact.avatarUrl ?? ""))
        
        do {
            var amtMsat = tribeMinSats
            
            if isTribe && amount == 0 {
                let escrowAmountSats = Int(truncating: chat.escrowAmount ?? 0)
                let pricePerMessage = Int(truncating: chat.pricePerMessage ?? 0)
                amtMsat = max((escrowAmountSats + pricePerMessage), tribeMinSats)
            } else {
                amtMsat = amount
            }
            
            let rr = try sphinx.send(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                to: recipPubkey,
                msgType: msgType,
                msgJson: contentJSONString,
                state: loadOnionStateAsData(),
                myAlias: nickname,
                myImg: myImg,
                amtMsat: UInt64(amtMsat),
                isTribe: isTribe
            )
            
            let tag = handleRunReturn(
                rr: rr,
                isSendingMessage: true
            )
            
            let sentMessage = processNewOutgoingMessage(
                rr: rr,
                chat: chat,
                provisionalMessage: provisionalMessage,
                msgType: msgType,
                content: content,
                amount: amount,
                mediaKey: mediaKey,
                mediaToken: mediaToken ?? paidAttachmentMediaToken,
                mediaType: mediaType,
                replyUUID: replyUUID,
                threadUUID: threadUUID,
                invoiceString: invoiceString,
                tag: tag
            )
            
            if let sentMessage = sentMessage {
                assignReceiverId(localMsg: sentMessage)
            }
            
            if let metaData = metaData {
                chat.timezoneUpdated = false
                chat.managedObjectContext?.saveContext()
            }
            
            return (sentMessage, nil)
        } catch let error {
            print("error sending msg \(error.localizedDescription)")
            return (nil, "Send msg error \(error)")
        }
    }
    
    func processNewOutgoingMessage(
        rr: RunReturn,
        chat: Chat,
        provisionalMessage: TransactionMessage?,
        msgType: UInt8,
        content: String,
        amount: Int,
        mediaKey: String?,
        mediaToken: String?,
        mediaType: String?,
        replyUUID: String?,
        threadUUID: String?,
        invoiceString: String?,
        tag: String?
    ) -> TransactionMessage? {
        
        if rr.msgs.count > 1 && msgType == TransactionMessage.TransactionMessageType.directPayment.rawValue {
            return processNewOutgoingPayment(
                rr: rr,
                chat: chat,
                provisionalMessage: provisionalMessage,
                msgType: msgType,
                content: content,
                amount: amount,
                mediaKey: mediaKey,
                mediaToken: mediaToken,
                mediaType: mediaType
            )
        }
        
        for msg in rr.msgs {
            
            if msgType == TransactionMessage.TransactionMessageType.delete.rawValue {
                guard let replyUUID = replyUUID, let messageToDelete = TransactionMessage.getMessageWith(uuid: replyUUID) else {
                    return nil
                }
                messageToDelete.status = TransactionMessage.TransactionMessageStatus.deleted.rawValue
                messageToDelete.setAsLastMessage()
                messageToDelete.managedObjectContext?.saveContext()
                
                return messageToDelete
            }
            
            if msgType == TransactionMessage.TransactionMessageType.memberApprove.rawValue {
                return nil
            }
            
            if let sentUUID = msg.uuid {
                
                let date = Date()
                
                let message  = provisionalMessage ?? TransactionMessage.createProvisionalMessage(
                    messageContent: content,
                    type: Int(msgType),
                    date: date,
                    chat: chat,
                    replyUUID: replyUUID,
                    threadUUID: threadUUID
                )
                
                message?.tag = tag ?? msg.tag
                
                if msgType == TransactionMessage.TransactionMessageType.boost.rawValue {
                    message?.amount = NSDecimalNumber(value: amount / 1000)
                }
                
                if chat.isPublicGroup(), let owner = UserContact.getOwner() {
                    message?.senderAlias = owner.nickname
                    message?.senderPic = owner.avatarUrl
                }
                
                if msgType == TransactionMessage.TransactionMessageType.purchase.rawValue || msgType == TransactionMessage.TransactionMessageType.attachment.rawValue {
                    message?.mediaKey = mediaKey
                    message?.mediaToken = mediaToken
                    message?.mediaType = mediaType
                }
                
                if msgType == TransactionMessage.TransactionMessageType.invoice.rawValue {
                    guard let invoiceString = invoiceString else { return nil}
                    
                    let prd = PaymentRequestDecoder()
                    prd.decodePaymentRequest(paymentRequest: invoiceString)
                    
                    guard let paymentHash = try? paymentHashFromInvoice(bolt11: invoiceString),
                          let expiry = prd.getExpirationDate(),
                          let amount = prd.getAmount() else
                    {
                        return nil
                    }
                    
                    message?.paymentHash = paymentHash
                    message?.invoice = invoiceString
                    message?.amount = NSDecimalNumber(value: amount)
                    message?.expirationDate = expiry
                }
                
                if let paymentHash = rr.msgs.first?.paymentHash {
                    message?.paymentHash = paymentHash
                }
                
                message?.createdAt = date
                message?.updatedAt = date
                message?.uuid = sentUUID
                message?.id = provisionalMessage?.id ?? uniqueIntHashFromString(stringInput: UUID().uuidString)
                message?.setAsLastMessage()
                message?.muid = TransactionMessage.getMUIDFrom(mediaToken: mediaToken)
                message?.managedObjectContext?.saveContext()
                
                return message
            }
        }
        return nil
    }
    
    func processNewOutgoingPayment(
        rr: RunReturn,
        chat: Chat,
        provisionalMessage: TransactionMessage?,
        msgType: UInt8,
        content: String,
        amount: Int,
        mediaKey: String?,
        mediaToken: String?,
        mediaType: String?
    ) -> TransactionMessage? {
        
        let paymentMsg = rr.msgs[0]
        var paymentMessage: TransactionMessage? = nil
        
        if let sentUUID = paymentMsg.uuid {
            let date = Date()
            paymentMessage = provisionalMessage ?? TransactionMessage.createProvisionalMessage(
                messageContent: content,
                type: Int(msgType),
                date: date,
                chat: chat
            )
            
            paymentMessage?.id = uniqueIntHashFromString(stringInput: UUID().uuidString)
            paymentMessage?.amount = NSDecimalNumber(value: amount / 1000)
            paymentMessage?.mediaKey = mediaKey
            paymentMessage?.mediaToken = mediaToken
            paymentMessage?.mediaType = mediaType
            paymentMessage?.createdAt = date
            paymentMessage?.updatedAt = date
            paymentMessage?.uuid = sentUUID
            paymentMessage?.tag = paymentMsg.tag
            paymentMessage?.paymentHash = paymentMsg.paymentHash
            paymentMessage?.setAsLastMessage()
            paymentMessage?.managedObjectContext?.saveContext()
            
            return paymentMessage
        }
        return nil
    }
    
    func finalizeSentMessage(
        localMsg: TransactionMessage,
        remoteMsg: Msg
    ){
        let remoteMessageAsGenericMessage = GenericIncomingMessage(msg: remoteMsg)
        
        if let contentTimestamp = remoteMessageAsGenericMessage.timestamp {
            let date = timestampToDate(timestamp: UInt64(contentTimestamp))
            localMsg.date = date
            localMsg.updatedAt = Date()
        } else if let timestamp = remoteMsg.timestamp {
            let date = timestampToDate(timestamp: timestamp) ?? Date()
            localMsg.date = date
            localMsg.updatedAt = Date()
        }
        
        if let type = remoteMsg.type,
           type == TransactionMessage.TransactionMessageType.memberApprove.rawValue,
           let ruuid = localMsg.replyUUID,
           let messageWeAreReplying = TransactionMessage.getMessageWith(uuid: ruuid)
        {
            localMsg.senderAlias = messageWeAreReplying.senderAlias
        } else if let owner = UserContact.getOwner() {
            localMsg.senderAlias = owner.nickname
            localMsg.senderPic = owner.avatarUrl
        }
        
        if
            let msg = remoteMsg.message,
            let innerContent = MessageInnerContent(JSONString: msg),
            let metadataString = innerContent.metadata,
            let metadataData = metadataString.data(using: .utf8) 
        {
            do {
                if 
                    let metadataDict = try JSONSerialization.jsonObject(with: metadataData, options: []) as? [String: Any],
                    let timezone = metadataDict["tz"] as? String
                {
                    if localMsg.chat?.isPublicGroup() == true {
                        localMsg.remoteTimezoneIdentifier = timezone
                    }
                }
            } catch {
                print("Error parsing metadata JSON: \(error)")
            }
        }
        
        localMsg.senderId = UserData.sharedInstance.getUserId()
        assignReceiverId(localMsg: localMsg)
        localMsg.managedObjectContext?.saveContext()
    }
    
    func assignReceiverId(localMsg: TransactionMessage) {
        var receiverId :Int = -1
        
        if let contact = localMsg.chat?.getContact() {
            receiverId = contact.id
        } else if localMsg.type == TransactionMessage.TransactionMessageType.boost.rawValue,
            let replyUUID = localMsg.replyUUID,
            let replyMsg = TransactionMessage.getMessageWith(uuid: replyUUID)
        {
            receiverId = replyMsg.senderId
        }
        localMsg.receiverId = receiverId
    }
    
    func isTribeMessage(
        senderPubkey: String
    ) -> Bool {
        
        var isTribe = false
        
        if let _ = Chat.getTribeChatWithOwnerPubkey(ownerPubkey: senderPubkey){
            isTribe = true
        }
        
        return isTribe
    }
    
    func processInvoicePaid(rr: RunReturn) {
        if let _ = rr.settleTopic, let _ = rr.settlePayload {
            let paymentHashes = rr.msgs.compactMap({ $0.paymentHash })
            for paymentHash in paymentHashes {
                NotificationCenter.default.post(
                    name: .sentInvoiceSettled,
                    object: nil,
                    userInfo: ["paymentHash": paymentHash]
                )
            }
        }
    }
    
    //MARK: processes updates from general purpose messages like plaintext and attachments
    func processGenericMessages(rr: RunReturn) {
        if rr.msgs.isEmpty {
            return
        }
        
        let isRestoringContactsAndTribes = firstSCIDMsgsCallback != nil
        
        if isRestoringContactsAndTribes {
            return
        }
        
        let genericPmtMsgs = rr.msgs.filter({ $0.type == nil && $0.msat ?? 0 > 0 && $0.message?.isNotEmpty == true })
        restoreGenericPmts(pmts: genericPmtMsgs)
        
        let notAllowedTypes = [
            UInt8(TransactionMessage.TransactionMessageType.contactKey.rawValue),
            UInt8(TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue),
            UInt8(TransactionMessage.TransactionMessageType.unknown.rawValue)
        ]
        
        let filteredMsgs = rr.msgs.filter({ $0.type != nil && !notAllowedTypes.contains($0.type!) })
        
        if filteredMsgs.isEmpty {
            return
        }
        
        let owner = UserContact.getOwner()
        
        for message in filteredMsgs {
            
            if let fromMe = message.fromMe, fromMe == true {
                
                ///New sent message
                processSentMessage(
                    message: message,
                    owner: owner
                )
                
            } else if let uuid = message.uuid, TransactionMessage.getMessageWith(uuid: uuid) == nil {
                
                ///New Incoming message
                guard let type = message.type else {
                    continue
                }
                
                if isMessageWithText(type: type) {
                    processIncomingMessagesAndAttachments(
                        message: message,
                        owner: owner
                    )
                }
                
                if isBoostOrPayment(type: type) {
                    processIncomingPaymentsAndBoosts(message: message)
                }
                
                if isDelete(type: type) {
                    processIncomingDeletion(message: message)
                }
                
                if isGroupAction(type: type) {
                    processIncomingGroupJoinMsg(message: message)
                }
                
                if isInvoice(type: type) {
                    processIncomingInvoice(message: message)
                }
                
                if isPaidMessageRelated(type: type) {
                    processIncomingPaidMessageEvent(
                        message: message,
                        owner: owner
                    )
                }
            }
            
            processIndexUpdate(message: message)
        }
        
        managedContext.saveContext()
    }
    
    func restoreGenericPmts(pmts: [Msg]) {
        if pmts.isEmpty {
            return
        }
        
        for pmt in pmts {
            
            guard let index = pmt.index,
                  let indexInt = Int(index) else
            {
                return
            }
            
            var messageContent: String? = nil
            
            if let message = pmt.message,
               let innerContent = MessageInnerContent(JSONString: message)
            {
                messageContent = innerContent.content
            }
            
            let newMessage = TransactionMessage.getMessageInstanceWith(
                id: indexInt,
                context: managedContext
            )
            
            newMessage.id = indexInt
            
            if let amount = pmt.msat {
                newMessage.amount = NSDecimalNumber(value: amount / 1000)
                newMessage.amountMsat = NSDecimalNumber(value: amount)
            }
            
            newMessage.messageContent = messageContent
            newMessage.paymentHash = pmt.paymentHash
            
            if let timestamp = pmt.timestamp {
                newMessage.date = timestampToDate(timestamp: timestamp)
            }
        }
        
        managedContext.saveContext()
    }
    
    func updateIsPaidAllMessages() {
        let msgs = TransactionMessage.getAllPayment()
        for msg in msgs {
            msg.setPaymentInvoiceAsPaid()
        }
    }
    
    func processSentMessage(
        message: Msg,
        owner: UserContact? = nil
    ) {
        let genericIncomingMessage = GenericIncomingMessage(msg: message)
        
        if let omuuid = genericIncomingMessage.originalUuid, let newUUID = message.uuid,
           let originalMessage = TransactionMessage.getMessageWith(uuid: omuuid)
        {
            originalMessage.uuid = newUUID
            
            finalizeSentMessage(localMsg: originalMessage, remoteMsg: message)
            return
        }
        
        if let uuid = message.uuid,
           let type = message.type,
           TransactionMessage.getMessageWith(uuid: uuid) == nil
        {
            guard let localMsg = processGenericIncomingMessage(
                message: genericIncomingMessage,
                date: Date(),
                delaySave: true,
                type: Int(type),
                fromMe: true,
                owner: owner
            ) else {
                return
            }
            
            localMsg.uuid = uuid
            
            if let invoice = genericIncomingMessage.invoice {
                
                let prd = PaymentRequestDecoder()
                prd.decodePaymentRequest(paymentRequest: invoice)
                
                if let expiry = prd.getExpirationDate(),
                   let paymentHash = try? sphinx.paymentHashFromInvoice(bolt11: invoice)
                {
                    
                    localMsg.messageContent = prd.getMemo()
                    localMsg.paymentHash = paymentHash
                    localMsg.expirationDate = expiry
                    localMsg.invoice = genericIncomingMessage.invoice
                    localMsg.status = TransactionMessage.TransactionMessageStatus.pending.rawValue
                }
            }
            
            
            if let genericMessageMsat = genericIncomingMessage.amount {
                localMsg.amount = NSDecimalNumber(value:  genericMessageMsat/1000)
                localMsg.amountMsat = NSDecimalNumber(value: Int(truncating: (genericMessageMsat) as NSNumber))
            }
            
            finalizeSentMessage(localMsg: localMsg, remoteMsg: message)
        }
    }
    
    func processIncomingMessagesAndAttachments(
        message: Msg,
        owner: UserContact? = nil
    ) {
        guard let index = message.index,
              let uuid = message.uuid,
              let sender = message.sender,
              let date = message.date,
              let type = message.type,
              let csr = ContactServerResponse(JSONString: sender) else
        {
            return
        }
        
        var genericIncomingMessage = GenericIncomingMessage(msg: message)
        genericIncomingMessage.senderPubkey = csr.pubkey
        genericIncomingMessage.uuid = uuid
        genericIncomingMessage.index = index
        
        let _ = processGenericIncomingMessage(
            message: genericIncomingMessage,
            date: date,
            csr: csr,
            type: Int(type),
            fromMe: message.fromMe ?? false,
            owner: owner
        )
    }
    
    func processIncomingPaymentsAndBoosts(
        message: Msg
    ) {
        guard let index = message.index,
              let uuid = message.uuid,
              let sender = message.sender,
              let date = message.date,
              let type = message.type,
              let csr = ContactServerResponse(JSONString: sender) else
        {
            return
        }
        
        var genericIncomingMessage = GenericIncomingMessage(msg: message)
        genericIncomingMessage.senderPubkey = csr.pubkey
        genericIncomingMessage.uuid = uuid
        genericIncomingMessage.index = index
        
        let _ = processGenericIncomingMessage(
            message: genericIncomingMessage,
            date: date,
            csr: csr,
            amount: Int(message.msat ?? 0),
            type: Int(type),
            fromMe: message.fromMe ?? false
        )
    }
    
    func processIncomingDeletion(message: Msg){
        let genericIncomingMessage = GenericIncomingMessage(msg: message)
        
        if let messageToDeleteUUID = genericIncomingMessage.replyUuid {
            if let messageToDelete = TransactionMessage.getMessageWith(uuid: messageToDeleteUUID) {
                messageToDelete.status = TransactionMessage.TransactionMessageStatus.deleted.rawValue
                
                messageToDelete.managedObjectContext?.saveContext()
            } else {
                guard let sender = message.sender,
                      let date = message.date,
                      let type = message.type,
                      let csr = ContactServerResponse(JSONString: sender) else
                {
                    return
                }
                
                guard let msg = processGenericIncomingMessage(
                    message: genericIncomingMessage,
                    date: date,
                    csr: csr,
                    type: Int(type),
                    fromMe: message.fromMe ?? false
                ) else {
                    return
                }
                
                msg.managedObjectContext?.saveContext()
            }
        }
    }
    
    func processIncomingGroupJoinMsg(
        message: Msg
    ) {
        ///Check for sender information
        guard let sender = message.sender,
              let csr =  ContactServerResponse(JSONString: sender),
              let tribePubkey = csr.pubkey else
        {
            return
        }
        
        if let chat = Chat.getTribeChatWithOwnerPubkey(ownerPubkey: tribePubkey) {
            restoreGroupJoinMsg(
                message: message,
                chat: chat,
                didCreateTribe: false
            )
        } else {
            fetchOrCreateChatWithTribe(
                ownerPubkey: tribePubkey,
                host: csr.host,
                index: 0,
                completion: { [weak self] chat, didCreateTribe, ind in
                    guard let self = self else {
                        return
                    }
                    
                    if let chat = chat {
                        self.restoreGroupJoinMsg(
                            message: message,
                            chat: chat,
                            didCreateTribe: didCreateTribe
                        )
                    }
                }
            )
        }
    }
    
    func processIncomingPaidMessageEvent(
        message: Msg,
        owner: UserContact? = nil
    ) {
        guard let type = message.type,
              let sender = message.sender,
              let _ = message.index,
              let _ = message.uuid,
              let date = message.date,
              let csr = ContactServerResponse(JSONString: sender) else
        {
            return
        }
        
        let genericIncomingMessage = GenericIncomingMessage(msg: message)
        
        guard let newMessage = processGenericIncomingMessage(
            message: genericIncomingMessage,
            date: date,
            csr: csr,
            amount: genericIncomingMessage.amount ?? 0,
            type: Int(type),
            fromMe: message.fromMe ?? false,
            owner: owner
        ) else {
            return
        }
        
        ///process purchase attempt
        if newMessage.type == TransactionMessage.TransactionMessageType.purchase.rawValue,
          let mediaToken = newMessage.mediaToken,
          let muid = TransactionMessage.getMUIDFrom(mediaToken: mediaToken),
          let encryptedAttachmentMessage = TransactionMessage.getAttachmentMessageWith(muid: muid, managedContext: self.managedContext),
          let purchaseMinAmount = encryptedAttachmentMessage.getAttachmentPrice(),
          let chat = newMessage.chat,
          let mediaKey = encryptedAttachmentMessage.mediaKey
        {
            if chat.isPublicGroup() {
                return
            }
            
            if Int(truncating: newMessage.amount ?? 0) + kRoutingOffset >= purchaseMinAmount {
                ///purchase of media received with sufficient amount
                let _ = sendMessage(
                    to: chat.getContact(),
                    content: "",
                    chat: chat,
                    provisionalMessage: nil,
                    msgType: UInt8(TransactionMessage.TransactionMessageType.purchaseAccept.rawValue),
                    mediaKey: mediaKey,
                    threadUUID: nil,
                    replyUUID: nil,
                    paidAttachmentMediaToken: mediaToken
                )
            } else {
                ///purchase of media received but amount insufficient
                let _ = sendMessage(
                    to: chat.getContact(),
                    content: "",
                    chat: chat,
                    provisionalMessage: nil,
                    amount: ((newMessage.amount as? Int) ?? 0) * 1000,
                    msgType: UInt8(TransactionMessage.TransactionMessageType.purchaseDeny.rawValue),
                    threadUUID: nil,
                    replyUUID: nil,
                    paidAttachmentMediaToken: mediaToken
                )
            }
            newMessage.muid = muid
        }
    }
    
    func processIncomingInvoice(
        message: Msg
    ) {
        guard let type = message.type,
              let sender = message.sender,
              let index = message.index,
              let uuid = message.uuid,
              let date = message.date,
              let csr = ContactServerResponse(JSONString: sender) else
        {
            return
        }
        
        var genericIncomingMessage = GenericIncomingMessage(msg: message)
        
        if let invoice = genericIncomingMessage.invoice {
            genericIncomingMessage.senderPubkey = csr.pubkey
            genericIncomingMessage.uuid = uuid
            genericIncomingMessage.index = index
            
            let prd = PaymentRequestDecoder()
            prd.decodePaymentRequest(paymentRequest: invoice)
            
            if let expiry = prd.getExpirationDate(),
                let amount = prd.getAmount(),
                let paymentHash = try? paymentHashFromInvoice(bolt11: invoice)
            {
                guard let newMessage = processGenericIncomingMessage(
                    message: genericIncomingMessage,
                    date: date,
                    csr: csr,
                    amount: amount * 1000,
                    type: Int(type),
                    fromMe: message.fromMe ?? false
                ) else {
                    return
                }
                
                newMessage.messageContent = prd.getMemo()
                newMessage.paymentHash = paymentHash
                newMessage.expirationDate = expiry
                newMessage.invoice = genericIncomingMessage.invoice
                newMessage.amountMsat = NSDecimalNumber(value: Int(truncating: newMessage.amount ?? 0) * 1000)
                newMessage.status = TransactionMessage.TransactionMessageStatus.pending.rawValue
            }
            
        }
    }
    
    func processGenericIncomingMessage(
        message: GenericIncomingMessage,
        date: Date,
        csr: ContactServerResponse? = nil,
        amount: Int = 0,
        delaySave: Bool = false,
        type: Int? = nil,
        status: Int? = nil,
        fromMe: Bool = false,
        owner: UserContact? = nil
    ) -> TransactionMessage? {
        
        let content = message.content
        
        guard let indexString = message.index,
            let index = Int(indexString),
            let pubkey = message.senderPubkey,
            let uuid = message.uuid else
        {
            return nil
        }
        
        if let _ = TransactionMessage.getMessageWith(id: index) {
            return nil
        }
        
        var chat : Chat? = nil
        var senderId: Int? = nil
        var receiverId: Int? = nil
        
        if let contact = UserContact.getContactWithDisregardStatus(pubkey: pubkey) {
            if let oneOnOneChat = contact.getChat() {
                chat = oneOnOneChat
            } else {
                chat = createChat(for: contact, with: date)
            }
            
            senderId = (fromMe == true) ? (UserData.sharedInstance.getUserId()) : contact.id
            receiverId = (fromMe == true) ? contact.id : (UserData.sharedInstance.getUserId())
            
            if fromMe {
                if let owner = owner ?? UserContact.getOwner(), let pubKey = owner.publicKey {
                    updateContactInfoFromMessage(
                        contact: owner,
                        alias: message.alias,
                        photoUrl: message.photoUrl,
                        pubkey: pubKey,
                        isOwner: true
                    )
                }
            } else {
                updateContactInfoFromMessage(
                    contact: contact,
                    alias: message.alias,
                    photoUrl: message.photoUrl,
                    pubkey: pubkey
                )
            }
            
        } else if let tribeChat = Chat.getTribeChatWithOwnerPubkey(ownerPubkey: pubkey) {
            chat = tribeChat
            senderId = tribeChat.id
            
            if fromMe == false, let replyUuid = message.replyUuid, let localReplyMsgRecord = TransactionMessage.getMessageWith(uuid: replyUuid) {
                receiverId = localReplyMsgRecord.senderId
            } else {
                receiverId = tribeChat.id
            }
        }
        
        guard let chat = chat,
              let senderId = senderId,
              let receiverId = receiverId else
        {
            return nil
        }
        
        let newMessage = TransactionMessage.getMessageInstanceWith(
            id: index,
            context: managedContext
        )
        
        newMessage.id = index
        newMessage.uuid = uuid
        
        if let timestamp = message.timestamp,
           let dateFromMessage = timestampToDate(timestamp: UInt64(timestamp))
        {
            newMessage.createdAt = dateFromMessage
            newMessage.updatedAt = dateFromMessage
            newMessage.date = dateFromMessage
        } else {
            newMessage.createdAt = date
            newMessage.updatedAt = date
            newMessage.date = date
        }
        
        newMessage.status = status ?? TransactionMessage.TransactionMessageStatus.confirmed.rawValue
        newMessage.type = type ?? TransactionMessage.TransactionMessageType.message.rawValue
        newMessage.encrypted = true
        newMessage.senderId = senderId
        newMessage.receiverId = receiverId
        newMessage.chat = chat
        newMessage.chat?.seen = false
        newMessage.messageContent = content
        newMessage.replyUUID = message.replyUuid
        newMessage.threadUUID = message.threadUuid
        newMessage.senderAlias = csr?.alias
        newMessage.senderPic = csr?.photoUrl
        newMessage.mediaKey = message.mediaKey
        newMessage.mediaType = message.mediaType
        newMessage.mediaToken = message.mediaToken
        newMessage.muid = TransactionMessage.getMUIDFrom(mediaToken: message.mediaToken)
        newMessage.paymentHash = message.paymentHash
        newMessage.tag = message.tag
        
        if let myAlias = chat.myAlias ?? owner?.nickname, chat.isPublicGroup() {
            newMessage.push = content?.contains("@\(myAlias) ") == true
        } else {
            newMessage.push = false
        }
        
        let msgAmount = message.amount ?? amount
        newMessage.amount = NSDecimalNumber(value: msgAmount / 1000)
        newMessage.amountMsat = NSDecimalNumber(value: msgAmount)
        
        if type == TransactionMessage.TransactionMessageType.payment.rawValue,
           let ph = message.paymentHash,
           let _ = TransactionMessage.getInvoiceWith(paymentHash: ph)
        {
            newMessage.setPaymentInvoiceAsPaid()
        }

        if let timezone = message.tz {
            if chat.isGroup() {
                newMessage.remoteTimezoneIdentifier = timezone
            } else {
                if (!isV2Restore || chat.remoteTimezoneIdentifier == nil) && !fromMe {
                    chat.remoteTimezoneIdentifier = timezone
                }
            }
        }
        
        if !delaySave {
            managedContext.saveContext()
        }
                
        newMessage.setAsLastMessage()
        
        if !fromMe {
            newMessageBubbleHelper.showMessageView(message: newMessage)
        }
        
        return newMessage
    }
    
    func createKeyExchangeMsgFrom(
        msg: Msg
    ) {
        guard let sender = msg.sender, let csr = ContactServerResponse(JSONString: sender), let pubKey = csr.pubkey else {
            return
        }
        
        guard let contact = UserContact.getContactWithDisregardStatus(pubkey: pubKey) else {
            return
        }
        
        guard let index = msg.index, let intIndex = Int(index), let msgType = msg.type else {
            return
        }
        
        let allowedTypes = [
            UInt8(TransactionMessage.TransactionMessageType.unknown.rawValue),
            UInt8(TransactionMessage.TransactionMessageType.contactKey.rawValue),
            UInt8(TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue)
        ]
        
        if !allowedTypes.contains(msgType) {
            return
        }
        
        if let _ = TransactionMessage.getMessageWith(id: intIndex) {
            return
        }
        
        let newMessage = TransactionMessage(context: managedContext)
        
        newMessage.id = intIndex
        newMessage.uuid = msg.uuid
        
        if let timestamp = msg.timestamp,
           let dateFromMessage = timestampToDate(timestamp: UInt64(timestamp))
        {
            newMessage.createdAt = dateFromMessage
            newMessage.updatedAt = dateFromMessage
            newMessage.date = dateFromMessage
        } else {
            let date = Date()
            newMessage.createdAt = date
            newMessage.updatedAt = date
            newMessage.date = date
        }
        
        newMessage.status = TransactionMessage.TransactionMessageStatus.confirmed.rawValue
        newMessage.type = Int(msgType)
        newMessage.encrypted = true
        newMessage.senderId = contact.id
        newMessage.push = false
        newMessage.chat = contact.getChat()
        newMessage.chat?.seen = false
        newMessage.messageContent = msg.message
        
        managedContext.saveContext()
    }
    
    func updateContactInfoFromMessage(
        contact: UserContact,
        alias: String?,
        photoUrl: String?,
        pubkey: String,
        isOwner: Bool = false
    ) {
        ///Avoid updating it again since it was already updated from most recent messahe
        if restoredContactInfoTracker.contains(pubkey) && isV2Restore {
            return
        }
        
        var contactDidChange = false
        
        if isOwner && isV2Restore {
            ///Just update Owner during restore if  nickname or photo Url was not set during restore and last message has a valid one
            if (
                (contact.nickname == nil || contact.nickname?.isEmpty == true) &&
                alias != nil &&
                alias?.isEmpty == false
            ) {
                contact.nickname = alias
                contactDidChange = true
            }
            
            if (
                (contact.avatarUrl == nil || contact.avatarUrl?.isEmpty == true) &&
                photoUrl != nil &&
                photoUrl?.isEmpty == false
            ) {
                contact.avatarUrl = photoUrl
                contactDidChange = true
            }
        } else {
            if (alias != nil && alias?.isEmpty == false && contact.nickname != alias) {
                contact.nickname = alias
                contactDidChange = true
            }
            
            if (photoUrl != nil && photoUrl?.isEmpty == false && contact.avatarUrl != photoUrl) {
                contact.avatarUrl = photoUrl
                contactDidChange = true
            }
        }
        
        if contactDidChange {
            contact.managedObjectContext?.saveContext()
        }
        
        if isV2Restore {
            restoredContactInfoTracker.append(pubkey)
        }
    }
    
    func processIndexUpdate(message: Msg) {
        if isMyMessageNeedingIndexUpdate(msg: message),
            let uuid = message.uuid,
            let cachedMessage = TransactionMessage.getMessageWith(uuid: uuid),
            let indexString = message.index,
            let index = Int(indexString)
        {
            cachedMessage.id = index //sync self index
            cachedMessage.updatedAt = Date()
        }
    }

    func signChallenge(challenge: String) -> String? {
        guard let seed = self.getAccountSeed() else {
            return nil
        }
        do {
            if challenge.isBase64Encoded {
                let resultBase64 = try sphinx.signBase64(
                    seed: seed,
                    idx: 0,
                    time: getTimeWithEntropy(),
                    network: network,
                    msg: challenge
                )
                return resultBase64
            }
            
            if let challengeData = challenge.nonBase64Data {
                let resultHex = try sphinx.signBytes(
                    seed: seed,
                    idx: 0,
                    time: getTimeWithEntropy(),
                    network: network,
                    msg: challengeData
                )
                
                let resultBase64 = Data(hexString: resultHex)?
                    .base64EncodedString().urlSafe
                
                return resultBase64
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    func getSignedToken() -> String? {
        guard let seed = self.getAccountSeed() else {
            return nil
        }
        do {
            let idx: UInt64 = 0
            
            let token = try sphinx.signedTimestamp(
                seed: seed,
                idx: idx,
                time: getTimeWithEntropy(),
                network: network
            )
            
            return token
        } catch {
            return nil
        }
    }
    
    func payAttachment(
        message: TransactionMessage,
        price: Int
    ){
        guard let chat = message.chat else{
            return
        }
         
        let _ = sendMessage(
            to: message.chat?.getContact(),
            content: "",
            chat: chat,
            provisionalMessage: nil,
            amount: price * 1000,
            msgType: UInt8(TransactionMessage.TransactionMessageType.purchase.rawValue),
            muid: message.muid,
            threadUUID: nil,
            replyUUID: message.uuid,
            paidAttachmentMediaToken: message.mediaToken
        )
    }
    

    func sendAttachment(
        file: NSDictionary,
        attachmentObject: AttachmentObject,
        chat: Chat?,
        provisionalMessage: TransactionMessage? = nil,
        replyingMessage: TransactionMessage? = nil,
        threadUUID: String? = nil
    ) -> (TransactionMessage?, String?) {
        
        guard let muid = file["muid"] as? String,
            let chat = chat,
            let mk = attachmentObject.mediaKey else
        {
            return (nil, "MUID or mediaKey not found")
        }
        
        let (_, mediaType) = attachmentObject.getFileAndMime()
        
        //Create JSON object and push through onion network
        var recipContact : UserContact? = nil
        
        if let contact = chat.getContact() {
            recipContact = contact
        }
        
        let type = (TransactionMessage.TransactionMessageType.attachment.rawValue)
        let purchaseAmt = (attachmentObject.price > 0) ? (attachmentObject.price) : nil
        
        let (sentMessage, errorMessage) = sendMessage(
            to: recipContact,
            content: attachmentObject.text ?? "",
            chat: chat,
            provisionalMessage: provisionalMessage,
            purchaseAmount: purchaseAmt,
            msgType: UInt8(type),
            muid: muid,
            mediaKey: mk,
            mediaType: mediaType,
            threadUUID:threadUUID,
            replyUUID: replyingMessage?.uuid
        )
        
        if let sentMessage = sentMessage {
            if (type == TransactionMessage.TransactionMessageType.attachment.rawValue) {
                AttachmentsManager.sharedInstance.cacheImageAndMediaData(message: sentMessage, attachmentObject: attachmentObject)
            } else if (type == TransactionMessage.TransactionMessageType.purchase.rawValue) {
                print(sentMessage)
            }
            
            return (sentMessage, nil)
        }
        
        return (nil, errorMessage ?? "generic.error.message".localized)
    }
    
    //MARK: Payments related
    func sendBoostReply(
        params: [String: AnyObject],
        chat: Chat,
        completion: @escaping (TransactionMessage?) -> ()
    ) {
        let pubkey = chat.getContact()?.publicKey ?? chat.ownerPubkey
        let routeHint = chat.getContact()?.routeHint
        
        guard let _ = params["reply_uuid"] as? String,
              let _ = params["text"] as? String,
              let pubkey = pubkey,
              let amount = params["amount"] as? Int else
        {
            completion(nil)
            return
        }
        
        if chat.isPublicGroup(), let _ = chat.ownerPubkey {
            ///If it's a tribe and I'm already in, then there's a route
            let message = self.finalizeSendBoostReply(
                params: params,
                chat: chat
            )
            completion(message)
            return
        }
        
        checkAndFetchRouteTo(
            publicKey: pubkey,
            routeHint: routeHint,
            amtMsat: amount
        ) { success in
            if success {
                let message = self.finalizeSendBoostReply(
                    params: params,
                    chat: chat
                )
                completion(message)
            } else {
                AlertHelper.showAlert(
                    title: "Routing Error",
                    message: "There was a routing error. Please try again."
                )
                completion(nil)
            }
        }
    }
    
    func sendFeedBoost(
        params: [String: AnyObject],
        chat: Chat,
        completion: @escaping (TransactionMessage?) -> ()
    ) {
        let pubkey = chat.getContact()?.publicKey ?? chat.ownerPubkey
        
        guard let _ = params["text"] as? String,
              let _ = pubkey,
              let _ = params["amount"] as? Int else
        {
            completion(nil)
            return
        }
        
        let message = self.finalizeSendBoostReply(
            params: params,
            chat: chat
        )
        completion(message)
    }
    
    func finalizeSendBoostReply(
        params: [String: AnyObject],
        chat:Chat
    ) -> TransactionMessage? {
        guard let text = params["text"] as? String,
            let amount = params["amount"] as? Int else{
            return nil
        }
        
        let (sentMessage, _) = self.sendMessage(
            to: chat.getContact(),
            content: text,
            chat: chat,
            provisionalMessage: nil,
            amount: amount,
            msgType: UInt8(TransactionMessage.TransactionMessageType.boost.rawValue),
            threadUUID: nil,
            replyUUID: params["reply_uuid"] as? String
        )
        
        return sentMessage
    }
    
    func sendDirectPaymentMessage(
        amount: Int,
        muid: String?,
        content: String?,
        chat: Chat,
        completion: @escaping (Bool, TransactionMessage?) -> ()
    ){
        guard let contact = chat.getContact(),
              let pubkey = contact.publicKey else
        {
            return
        }
        
        checkAndFetchRouteTo(
            publicKey: pubkey,
            routeHint: contact.routeHint,
            amtMsat: amount
        ) { success in
            if(success){
                self.finalizeDirectPayment(
                    amount: amount,
                    muid: muid,
                    content: content,
                    chat: chat,
                    completion: { success, message in
                        completion(success,message)
                    }
                )
            } else {
                completion(false,nil)
            }
        }
    }
    
    func finalizeDirectPayment(
        amount: Int,
        muid: String?,
        content: String?,
        chat: Chat,
        completion: @escaping (Bool, TransactionMessage?) -> ()
    ){
        guard let contact = chat.getContact() else {
            return
        }
        
        if let sentMessage = self.sendMessage(
            to: contact,
            content: content ?? "",
            chat: chat,
            provisionalMessage: nil,
            amount: amount,
            msgType: UInt8(TransactionMessage.TransactionMessageType.directPayment.rawValue),
            muid: muid,
            mediaType: "image/png",
            threadUUID: nil,
            replyUUID: nil
        ).0 {
            SphinxOnionManager.sharedInstance.assignReceiverId(localMsg: sentMessage)
            sentMessage.managedObjectContext?.saveContext()
            completion(true, sentMessage)
        } else {
            completion(false, nil)
        }
    }
    
    func sendDeleteRequest(
        message: TransactionMessage
    ){
        guard let chat = message.chat else{
            return
        }
        let contact = chat.getContact()
        
        let _ = sendMessage(
            to: contact,
            content: "",
            chat: chat,
            provisionalMessage: nil,
            msgType: UInt8(TransactionMessage.TransactionMessageType.delete.rawValue),
            threadUUID: nil,
            replyUUID: message.uuid
        )
    }
    
    func getDestinationPubkey(for chat: Chat) -> String? {
        return chat.getContact()?.publicKey ?? chat.ownerPubkey ?? nil
    }
    
    func toggleChatSound(
        chatId: Int,
        muted: Bool,
        completion: @escaping (Chat?) -> ()
    ) {
        guard let chat = Chat.getChatWith(id: chatId) else{
            return
        }

        let level = muted ? Chat.NotificationLevel.MuteChat.rawValue : Chat.NotificationLevel.SeeAll.rawValue

        setMuteLevel(muteLevel: UInt8(level), chat: chat, recipContact: chat.getContact())
        chat.notify = level
        chat.managedObjectContext?.saveContext()
        completion(chat)
    }
    
    func setMuteLevel(
        muteLevel: UInt8,
        chat: Chat,
        recipContact: UserContact?
    ) {
        guard let seed = getAccountSeed() else{
            return
        }
        guard let recipPubkey = (recipContact?.publicKey ?? chat.ownerPubkey) else { return  }
        
        do {
            let rr = try sphinx.mute(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                pubkey: recipPubkey,
                muteLevel: muteLevel
            )
            
            let _ = handleRunReturn(rr: rr)
        } catch {
            print("Error setting mute level")
        }
    }
    
    func getMuteLevels() {
        guard let seed = getAccountSeed() else{
            return
        }
        do {
            let rr = try  sphinx.getMutes(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData()
            )
            let _ = handleRunReturn(rr: rr)
        } catch {
            print("Error getting mute level")
        }
    }
    
    func setReadLevel(
        index: UInt64,
        chat: Chat,
        recipContact: UserContact?
    ) -> Bool {
        guard let seed = getAccountSeed() else{
            return false
        }
        
        guard let _ = mqtt else {
            return false
        }
        
        guard let recipPubkey = (recipContact?.publicKey ?? chat.ownerPubkey) else {
            return false
        }
        
        do {
            let rr = try sphinx.read(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                pubkey: recipPubkey,
                msgIdx: index
            )
            let _ = handleRunReturn(rr: rr)
            return true
        } catch {
            print("Error setting read level")
            return false
        }
    }
    
    func getReads() {
        guard let seed = getAccountSeed() else{
            return
        }
        do {
            let rr = try sphinx.getReads(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData()
            )
            let _ = handleRunReturn(rr: rr)
        } catch {
            print("Error getting read level")
        }
    }
    
    func isMessageLengthValid(
        text: String,
        sendingAttachment: Bool,
        threadUUID: String?,
        replyUUID: String?,
        metaDataString: String? = nil
    ) -> Bool {
        let contentBytes: Int = 18
        let attachmentBytes: Int = 389
        let replyBytes: Int = 84
        let threadBytes: Int = 84
        
        var bytes = text.byteSize() + contentBytes
        
        if sendingAttachment {
            bytes += attachmentBytes
        }
        
        if replyUUID != nil {
            bytes += replyBytes
        }
        
        if threadUUID != nil {
            bytes += threadBytes
        }
        
        if let metaDataBytes = metaDataString?.lengthOfBytes(using: .utf8) {
            bytes += metaDataBytes
        }
        
        return bytes <= 869
    }
    
//    func startSendTimeoutTimer(
//        for messageUUID: String,
//        msgType: UInt8
//    ) {
//        let excludedTypes = [
//            UInt8(TransactionMessage.TransactionMessageType.payment.rawValue),
//            UInt8(TransactionMessage.TransactionMessageType.directPayment.rawValue),
//            UInt8(TransactionMessage.TransactionMessageType.boost.rawValue),
//            UInt8(TransactionMessage.TransactionMessageType.keysend.rawValue),
//            UInt8(TransactionMessage.TransactionMessageType.delete.rawValue),
//        ]
//        
//        if excludedTypes.contains(msgType) {
//            return
//        }
//        
//        sendTimeoutTimers[messageUUID]?.invalidate() // Invalidate any existing timer for this UUID
//
//        let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] timer in
//            self?.handleSendTimeout(for: messageUUID)
//        }
//        
//        sendTimeoutTimers[messageUUID] = timer
//    }
//
//    func handleSendTimeout(for messageUUID: String) {
//        guard let message = TransactionMessage.getMessageWith(uuid: messageUUID) else { return }
//        
//        message.status = TransactionMessage.TransactionMessageStatus.failed.rawValue
//        message.managedObjectContext?.saveContext()
//        
//        sendTimeoutTimers[messageUUID] = nil // Remove the timer reference
//    }
//    
//    // Call this method when you receive Ongoing Message UUID
//    func receivedOMuuid(_ omuuid: String) {
//        sendTimeoutTimers[omuuid]?.invalidate()
//        sendTimeoutTimers[omuuid] = nil
//    }
    
    func getMessagesStatusForPendingMessages() {
        let dispatchQueue = DispatchQueue.global(qos: .utility)
        dispatchQueue.async {
            let backgroundContext = CoreDataManager.sharedManager.getBackgroundContext()
            
            backgroundContext.performAndWait {
                let messages = TransactionMessage.getAllNotConfirmed()
                
                if messages.isEmpty {
                    return
                }
                
                Task {
                    for i in stride(from: 0, to: messages.count, by: 200) {
                        let chunk = Array(messages[i..<min(i + 200, messages.count)])
                        
                        let tags = chunk.compactMap({ $0.tag })
                        
                        SphinxOnionManager.sharedInstance.getMessagesStatusFor(tags: tags)
                        
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
        }
    }
    
    func getMessagesStatusFor(tags: [String]) {
        guard let seed = getAccountSeed() else{
            return
        }
        
        do {
            let rr = try sphinx.getTags(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                tags: tags,
                pubkey: nil
            )
            let _ = handleRunReturn(rr: rr)
        } catch {
            print("Error getting read level")
        }
    }

}


extension Data {
    init?(hexString: String) {
        let cleanHex = hexString.replacingOccurrences(of: " ", with: "")
        var data = Data(capacity: cleanHex.count / 2)

        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            let byteString = cleanHex[index ..< cleanHex.index(index, offsetBy: 2)]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = cleanHex.index(index, offsetBy: 2)
        }

        self = data
    }
}

extension Msg {
    func getInnerContentDate() -> Date? {
        if let msg = self.message,
           let innerContent = MessageInnerContent(JSONString: msg),
           let innerContentDate = innerContent.date,
           let date = self.timestampToDate(timestamp: UInt64(innerContentDate))
        {
            return date
        }
        return nil
    }
    
    func timestampToDate(
        timestamp: UInt64
    ) -> Date? {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return date
    }
    
    var date: Date? {
        get {
            if let timestamp = self.timestamp {
                return self.timestampToDate(timestamp: UInt64(timestamp))
            }
            return nil
        }
    }
}
