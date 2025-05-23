//
//  SphinxOnionManager+AccountRestore.swift
//  sphinx
//
//  Created by James Carucci on 3/20/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import CoreData
import ObjectMapper

class ChatsFetchParams {
    var restoreInProgress: Bool
    var itemsPerPage: Int
    var fetchStartIndex: Int
    var restoredItems: Int
    var restoredTribesPubKeys: [String] = []

    enum FetchDirection {
        case forward, backward
    }

    init(
        restoreInProgress: Bool,
        fetchStartIndex: Int,
        itemsPerPage: Int,
        restoredItems: Int
    ) {
        self.restoreInProgress = restoreInProgress
        self.fetchStartIndex = fetchStartIndex
        self.itemsPerPage = itemsPerPage
        self.restoredItems = restoredItems
        self.restoredTribesPubKeys = []
    }
    
    var debugDescription: String {
        return """
        restoreInProgress: \(restoreInProgress)
        fetchStartIndex: \(fetchStartIndex)
        itemsPerPage: \(itemsPerPage)
        """
    }
}

class MessageFetchParams {
    
    var itemsPerPage: Int
    var fetchStartIndex: Int
    var restoredItems: Int
    var stopIndex: Int
    var direction: FetchDirection
    var restoredTribesPubKeys: [String] = []

    enum FetchDirection {
        case forward, backward
    }

    init(
        fetchStartIndex: Int,
        itemsPerPage: Int,
        restoredItems: Int,
        stopIndex: Int,
        direction: FetchDirection
    ) {
        self.fetchStartIndex = fetchStartIndex
        self.itemsPerPage = itemsPerPage
        self.restoredItems = restoredItems
        self.stopIndex = stopIndex
        self.direction = direction
        self.restoredTribesPubKeys = []
    }
    
    var debugDescription: String {
        return """
        fetchStartIndex: \(fetchStartIndex)
        itemsPerPage: \(itemsPerPage)
        stopIndex: \(stopIndex)
        """
    }
}

class MsgTotalCounts: Mappable {
    var totalMessageAvailableCount: Int?
    var okKeyMessageAvailableCount: Int?
    var firstMessageAvailableCount: Int?
    var totalMessageMaxIndex: Int?
    var okKeyMessageMaxIndex: Int?
    var firstMessageMaxIndex: Int?

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        totalMessageAvailableCount  <- map["total"]
        okKeyMessageAvailableCount  <- map["ok_key"]
        firstMessageAvailableCount  <- map["first_for_each_scid"]
        totalMessageMaxIndex        <- map["total_highest_index"]
        okKeyMessageMaxIndex        <- map["ok_key_highest_index"]
        firstMessageMaxIndex        <- map["first_for_each_scid_highest_index"]
    }

    func hasOneValidCount() -> Bool {
        // Use an array to check for non-nil properties in a condensed form
        let properties = [totalMessageAvailableCount, okKeyMessageAvailableCount, firstMessageAvailableCount]
        return properties.contains(where: { $0 != nil })
    }
}

///account restore related
extension SphinxOnionManager {
    
    func isMnemonic(code: String) -> Bool {
        let words = code.split(separator: " ").map { String($0).trim().lowercased() }
        let (error, _) = validateSeed(words: words)
        return error == nil
    }
    
    func syncContactsAndMessages() {
        setupSyncWith(callback: processMessageCountReceived)
    }
    
    func setupSyncWith(
        callback: @escaping () -> ()
    ) {
        guard let seed = getAccountSeed() else{
            return
        }
        
        totalMsgsCountCallback = callback
        
        do {
            let rr = try getMsgsCounts(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData()
            )
            
            let _ = handleRunReturn(rr: rr)
        } catch {
            print("Error getting msgs count")
        }
    }
    
    func processMessageCountReceived() {
        if let msgTotalCounts = msgTotalCounts,
           msgTotalCounts.hasOneValidCount()
        {
            kickOffFullRestore()
        }
    }
    
    func kickOffFullRestore() {
        guard let msgTotalCounts = msgTotalCounts else {return}
        
        if let _ = msgTotalCounts.firstMessageAvailableCount {
            
            self.restoreFirstScidMessages()
        }
    }
    
    func doNextRestorePhase() {
        guard let _ = messageFetchParams else {
            startMessagesRestore()
            return
        }
        
        finishMessagesFetch(isRestore: true)
    }
    
    func restoreFirstScidMessages(
        startIndex: Int = 0
    ) {
        guard let seed = getAccountSeed() else{
            finishMessagesFetch(isRestore: true)
            return
        }
        
        chatsFetchParams = ChatsFetchParams(
            restoreInProgress: true,
            fetchStartIndex: startIndex,
            itemsPerPage: SphinxOnionManager.kContactsBatchSize,
            restoredItems: chatsFetchParams?.restoredItems ?? 0
        )
        
        firstSCIDMsgsCallback = handleFetchFirstScidMessages
        
        fetchFirstContactPerKey(
            seed: seed,
            lastMessageIndex: startIndex,
            msgCountLimit: SphinxOnionManager.kContactsBatchSize
        )
    }
    
    func fetchFirstContactPerKey(
        seed: String,
        lastMessageIndex: Int,
        msgCountLimit: Int
    ){
        do {
            let rr = try fetchFirstMsgsPerKey(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                lastMsgIdx: UInt64(lastMessageIndex),
                limit: UInt32(msgCountLimit),
                reverse: false
            )
            
            let _ = handleRunReturn(rr: rr)
        } catch {}
    }
    
    func startMessagesRestore() {
        if let msgTotalCounts = self.msgTotalCounts,
           msgTotalCounts.totalMessageAvailableCount ?? 0 > 0 {
            
            let startIndex = (msgTotalCounts.totalMessageMaxIndex ?? 0)
            let lastMessageIndex = 0
            
            let safeSpread = max(0, startIndex - lastMessageIndex)
            let firstBatchSize = min(SphinxOnionManager.kMessageBatchSize, safeSpread) //either do max batch size or less if less is needed
            
            if (safeSpread <= 0) {
                finishMessagesFetch(isRestore: true)
                return
            }
            
            startAllMsgBlockFetch(
                startIndex: startIndex,
                itemsPerPage: firstBatchSize,
                stopIndex: lastMessageIndex,
                reverse: true
            )
        } else {
            finishMessagesFetch(isRestore: true)
        }
    }

    func startAllMsgBlockFetch(
        startIndex: Int,
        itemsPerPage: Int,
        stopIndex: Int,
        reverse: Bool
    ) {
        guard let seed = getAccountSeed() else {
            finishMessagesFetch(isRestore: reverse)
            return
        }
        
        chatsFetchParams = nil
        messageFetchParams = MessageFetchParams(
            fetchStartIndex: startIndex,
            itemsPerPage: itemsPerPage,
            restoredItems: 0,
            stopIndex: stopIndex,
            direction: reverse ? .backward : .forward
        )
        
        firstSCIDMsgsCallback = nil
        onMessageRestoredCallback = handleFetchMessagesBatch
        
        fetchMessageBlock(
            seed: seed,
            lastMessageIndex: startIndex,
            msgCountLimit: itemsPerPage,
            reverse: reverse
        )
    }
    
    func fetchMessageBlock(
        seed: String,
        lastMessageIndex: Int,
        msgCountLimit: Int,
        reverse: Bool
    ) {
//        startWatchdogTimer()
        
        let safeLastMsgIndex = max(lastMessageIndex, 0)
        
        do {
            let rr = try fetchMsgsBatch(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                lastMsgIdx: UInt64(safeLastMsgIndex),
                limit: UInt32(msgCountLimit),
                reverse: reverse
            )
            let _ = handleRunReturn(rr: rr)
        } catch let error {
            print(error)
        }
    }
    
    func fetchOkKeyMessages() {
        guard let seed = getAccountSeed() else {
            return
        }
        
        do {
            let rr = try fetchMsgsBatchOkkey(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                lastMsgIdx: UInt64(0),
                limit: UInt32(250),
                reverse: false
            )
            let _ = handleRunReturn(rr: rr)
        } catch let error {
            print(error)
        }
    }
}

extension SphinxOnionManager {
    //MARK: Process all first scid messages
    func handleFetchFirstScidMessages(msgs: [Msg]) {
        guard let params = chatsFetchParams, let _ = msgTotalCounts?.firstMessageMaxIndex else {
            doNextRestorePhase()
            return
        }
        
        let maxRestoreIndex = msgs.max {
            let firstIndex = Int($0.index ?? "0") ?? -1
            let secondIndex = Int($1.index ?? "0") ?? -1
            return firstIndex < secondIndex
        }?.index
        
        ///Contacts Restore
        if let totalMsgCount = msgTotalCounts?.firstMessageAvailableCount {
            
            if let contactRestoreCallback = contactRestoreCallback, totalMsgCount > 0 {
                ///Contacts Restore progress
                params.restoredItems = params.restoredItems + msgs.count
                
                let restoredMsgsCount = min(params.restoredItems, totalMsgCount)
                let percentage = 2 + (Double(restoredMsgsCount) / Double(totalMsgCount)) * 18
                let pctInt = Int(percentage.rounded())
                contactRestoreCallback(pctInt)
            }
            
            if msgs.count <= 0 {
                doNextRestorePhase()
                return
            }
            
            if let scidMaxIndex = msgTotalCounts?.firstMessageMaxIndex,
                let maxRestoreIndex = maxRestoreIndex,
                let maxRestoredIndexInt = Int(maxRestoreIndex)
            {
                if maxRestoredIndexInt < scidMaxIndex {
                    ///Didn't restore max index yet. Proceed to next page
                    restoreFirstScidMessages(startIndex: maxRestoredIndexInt + 1)
                    return
                }
            }
        }
        
        doNextRestorePhase()
    }
    
    //MARK: Process all messages
    func handleFetchMessagesBatch(msgs: [Msg]) {
        guard let params = messageFetchParams else {
            finishMessagesFetch(isRestore: true)
            return
        }
        
        if params.direction == .forward {
            handleFetchMessagesBatchInForward(msgs: msgs)
            return
        }
        
        guard let _ = msgTotalCounts?.totalMessageMaxIndex else {
            finishMessagesFetch(isRestore: true)
            return
        }
        
        let minRestoreIndex = msgs.min {
            let firstIndex = Int($0.index ?? "0") ?? -1
            let secondIndex = Int($1.index ?? "0") ?? -1
            return firstIndex < secondIndex
        }?.index ?? "0"
        
        if let minRestoredIndexInt = Int(minRestoreIndex), minRestoredIndexInt - 1 < params.stopIndex {
            finishMessagesFetch(isRestore: true)
            return
        }
        
        if let totalMsgCount = msgTotalCounts?.totalMessageAvailableCount {
            ///Contacts Restore progress
            if let messageRestoreCallback = messageRestoreCallback, totalMsgCount > 0 {
                params.restoredItems = params.restoredItems + msgs.count
                let msgsCount = min(params.restoredItems, totalMsgCount)
                let percentage = 20 + (Double(msgsCount) / Double(totalMsgCount)) * 80
                let pctInt = Int(percentage.rounded())
                messageRestoreCallback(pctInt)
            }
            
            ///Restore finished
            if msgs.count <= 0 {
                finishMessagesFetch(isRestore: true)
                return
            }
        }
        
        guard let seed = getAccountSeed() else {
            finishMessagesFetch(isRestore: true)
            return
        }
        
        fetchMessageBlock(
            seed: seed,
            lastMessageIndex: Int(minRestoreIndex)! - 1,
            msgCountLimit: params.itemsPerPage,
            reverse: true
        )
    }
    
    func handleFetchMessagesBatchInForward(msgs: [Msg]) {
        guard let params = messageFetchParams else {
            finishMessagesFetch()
            return
        }
        
        let maxRestoreIndex = msgs.min {
            let firstIndex = Int($0.index ?? "0") ?? -1
            let secondIndex = Int($1.index ?? "0") ?? -1
            return firstIndex > secondIndex
        }?.index ?? "0"
        
        guard let maxRestoredIndexInt = Int(maxRestoreIndex) else {
            finishMessagesFetch()
            return
        }
        
        if msgs.count <= 0 {
            finishMessagesFetch()
            return
        }
        
        maxMessageIndex = maxRestoredIndexInt
        
        guard let seed = getAccountSeed() else {
            finishMessagesFetch()
            return
        }
        
        fetchMessageBlock(
            seed: seed,
            lastMessageIndex: maxRestoredIndexInt + 1,
            msgCountLimit: params.itemsPerPage,
            reverse: false
        )
    }
    
    func restoreContactsFrom(messages: [Msg]) {
        if messages.isEmpty {
            return
        }
        
        let allowedTypes = [
            UInt8(TransactionMessage.TransactionMessageType.unknown.rawValue),
            UInt8(TransactionMessage.TransactionMessageType.contactKey.rawValue),
            UInt8(TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue)
        ]
        
        let filteredMsgs = messages.filter({ $0.type != nil && allowedTypes.contains($0.type!) })
        
        for message in filteredMsgs {
            guard let sender = message.sender,
               let csr =  ContactServerResponse(JSONString: sender),
               let recipientPubkey = csr.pubkey
            else {
                continue
            }
            
            if (chatsFetchParams?.restoredTribesPubKeys ?? []).contains(recipientPubkey) {
                ///If is tribe message, then continue
                continue
            }
            
            let routeHint: String? = csr.routeHint
                
            let contact = UserContact.getContactWithDisregardStatus(pubkey: recipientPubkey) ?? createNewContact(
                pubkey: recipientPubkey,
                routeHint: routeHint,
                nickname: csr.alias,
                photoUrl: csr.photoUrl,
                code: csr.code,
                date: message.date
            )
            
            if contact.isOwner {
                continue
            }
            
            if let routeHint = routeHint {
                contact.routeHint = routeHint
            }
            
            let isConfirmed = csr.confirmed == true
            
            if contact.isPending() {
                contact.status = isConfirmed ? UserContact.Status.Confirmed.rawValue : UserContact.Status.Pending.rawValue
            }
            
            if contact.getChat() == nil && isConfirmed {
                let _ = createChat(for: contact, with: message.date)
            }
            
            createKeyExchangeMsgFrom(msg: message)
        }
    }
    
    func restoreTribesFrom(
        rr: RunReturn,
        topic: String?,
        completion: @escaping (RunReturn, String?) -> ()
    ) {
        let messages = rr.msgs
        
        if messages.isEmpty {
            completion(rr, topic)
            return
        }

        let allowedTypes = [
            UInt8(TransactionMessage.TransactionMessageType.groupJoin.rawValue),
            UInt8(TransactionMessage.TransactionMessageType.memberApprove.rawValue)
        ]
        
        let filteredMsgs = messages.filter({ $0.type != nil && allowedTypes.contains($0.type!) })
        
        if filteredMsgs.isEmpty {
            completion(rr, topic)
            return
        }
        
        let total = filteredMsgs.count
        var index = 0
        
        for (i, message) in filteredMsgs.enumerated() {
            
            ///Check for sender information
            guard let sender = message.sender,
                  let csr =  ContactServerResponse(JSONString: sender),
                  let tribePubkey = csr.pubkey else
            {
                if index == total - 1 {
                    completion(rr, topic)
                } else {
                    index = index + 1
                }
                continue
            }
            
            if let chat = Chat.getTribeChatWithOwnerPubkey(ownerPubkey: tribePubkey) {
                restoreGroupJoinMsg(
                    message: message,
                    chat: chat,
                    didCreateTribe: false
                )
                if index == total - 1 {
                    completion(rr, topic)
                } else {
                    index = index + 1
                }
            } else {
                fetchOrCreateChatWithTribe(
                    ownerPubkey: tribePubkey,
                    host: csr.host,
                    index: i,
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
                        
                        if index == total - 1 {
                            completion(rr, topic)
                        } else {
                            index = index + 1
                        }
                    }
                )
            }
        }
    }
    
    func restoreGroupJoinMsg(
        message: Msg,
        chat: Chat,
        didCreateTribe: Bool
    ) {
        guard let uuid = message.uuid,
              let index = message.index,
              let timestamp = message.timestamp,
              let type = message.type,
              let date = timestampToDate(timestamp: timestamp) else
        {
            return
        }
        
        ///Check for sender information
        guard let sender = message.sender,
              let csr =  ContactServerResponse(JSONString: sender) else
        {
            return
        }
        
        let groupActionMessage = TransactionMessage.getMessageInstanceWith(
            id: Int(index),
            context: managedContext
        )
        groupActionMessage.uuid = uuid
        groupActionMessage.id = Int(index) ?? uniqueIntHashFromString(stringInput: UUID().uuidString)
        groupActionMessage.chat = chat
        groupActionMessage.type = Int(type)
        
        let innerContentDate = message.getInnerContentDate()
        groupActionMessage.createdAt = innerContentDate ?? date
        groupActionMessage.date = innerContentDate ?? date
        groupActionMessage.updatedAt = innerContentDate ?? date
        
        groupActionMessage.setAsLastMessage()
        groupActionMessage.senderAlias = csr.alias
        groupActionMessage.senderPic = csr.photoUrl
        groupActionMessage.senderId = message.fromMe == true ? UserData.sharedInstance.getUserId() : chat.id
        groupActionMessage.status = TransactionMessage.TransactionMessageStatus.confirmed.rawValue
        
        if let message = message.message,
           let innerContent = MessageInnerContent(JSONString: message)
        {
            groupActionMessage.replyUUID = innerContent.replyUuid
        }
        
        chat.seen = false
        
        if (didCreateTribe && csr.role != nil) {
            chat.isTribeICreated = csr.role == 0 && message.fromMe == true
        }
        if (type == TransactionMessage.TransactionMessageType.memberApprove.rawValue) {
            chat.status = Chat.ChatStatus.approved.rawValue
        }
        if (type == TransactionMessage.TransactionMessageType.memberReject.rawValue) {
            chat.status = Chat.ChatStatus.rejected.rawValue
        }
    }
    
    func attempFinishResotoration() {
        messageFetchParams = nil
        chatsFetchParams = nil
    }
    
    func endWatchdogTime() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }
    
    func startWatchdogTimer() {
        watchdogTimer?.invalidate()
        
        watchdogTimer = Timer.scheduledTimer(
            timeInterval: 10.0,
            target: self,
            selector: #selector(watchdogTimerFired),
            userInfo: nil,
            repeats: false
        )
    }
    
    @objc func watchdogTimerFired() {
        onMessageRestoredCallback = nil
        firstSCIDMsgsCallback = nil
        totalMsgsCountCallback = nil
        
        messageFetchParams = nil
        chatsFetchParams = nil
        
        restoredContactInfoTracker = []
        
        endWatchdogTime()
        resetFromRestore()
    }
    
    func finishMessagesFetch(
        isRestore: Bool = false
    ) {
        onMessageRestoredCallback = nil
        firstSCIDMsgsCallback = nil
        totalMsgsCountCallback = nil
        
        messageFetchParams = nil
        chatsFetchParams = nil
        
        restoredContactInfoTracker = []
        
        if (UIApplication.shared.delegate as? AppDelegate)?.isActive == true {
            ///Avoid processes that will run after the completion handler is called
            requestPings()
            updateRoutingInfo()
        } else {
            ///Disconnect MQTT if it's a background process
            disconnectMqtt()
        }
        
        if isRestore, let maxIndex = TransactionMessage.getMaxIndex() {
            maxMessageIndex = maxIndex
        }
        
        endWatchdogTime()
        resetFromRestore()
    }
    
    func requestPings() {
        guard let seed = getAccountSeed() else{
            return
        }
        readyForPing = true
        do {
            let rr = try sphinx.fetchPings(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData()
            )
            let _ = handleRunReturn(rr: rr)
        } catch {
            print("Error fetching pings")
        }
    }
    
    func resetFromRestore() {
        setLastMessagesOnChats()
        processDeletedRestoredMessages()
        updateIsPaidAllMessages()
        
        CoreDataManager.sharedManager.saveContext()
        
        isV2InitialSetup = false
        contactRestoreCallback = nil
        messageRestoreCallback = nil
        
        joinInitialTribe()
        
        if let hideRestoreCallback = hideRestoreCallback {
            hideRestoreCallback(false)
        }
    }
    
    func setLastMessagesOnChats() {
        if !isV2Restore {
            return
        }
        
        for chat in Chat.getAll() {
            if let lastMessage = chat.getLastMessageToShow(includeContactKeyTypes: true) {
                if lastMessage.isKeyExchangeType() {
                    fixSeenStateForChatsWithNoMessages(
                        chat: chat,
                        message: lastMessage,
                        shouldSetLastMessage: false
                    )
                } else if lastMessage.isTribeInitialMessageType() && chat.messages?.count == 1 {
                    fixSeenStateForChatsWithNoMessages(
                        chat: chat,
                        message: lastMessage,
                        shouldSetLastMessage: true
                    )
                } else if lastMessage.isOutgoing() {
                    chat.setChatMessagesAsSeen()
                } else {
                    chat.lastMessage = lastMessage
                }
            }
        }
    }
    
    func fixSeenStateForChatsWithNoMessages(
        chat: Chat,
        message: TransactionMessage,
        shouldSetLastMessage: Bool
    ) {
        message.seen = true
        chat.seen = true
        chat.lastMessage = shouldSetLastMessage ? message : nil
        
        if let maxMessageIndex = TransactionMessage.getMaxIndex() {
            let _  = SphinxOnionManager.sharedInstance.setReadLevel(
                index: UInt64(maxMessageIndex),
                chat: chat,
                recipContact: chat.getContact()
            )
        }
    }
    
    func processDeletedRestoredMessages() {
        let deleteRequests = TransactionMessage.getMessageDeletionRequests()
        
        for deleteRequest in deleteRequests {
            if let replyUUID = deleteRequest.replyUUID,
               let messageToDelete = TransactionMessage.getMessageWith(uuid: replyUUID)
            {
                messageToDelete.status = TransactionMessage.TransactionMessageStatus.deleted.rawValue
            }
        }
    }
    
    func registerDeviceID(id: String) {
        guard let seed = getAccountSeed(), let _ = mqtt else {
            return
        }
        
        guard let pushKey = self.pushKey else {
            return
        }
        
        do {
            let rr = try setPushToken(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                pushToken: id,
                pushKey: pushKey
            )
            
            let _ = handleRunReturn(rr: rr)
        } catch {
            print("Error setting push token")
        }
    }

}
