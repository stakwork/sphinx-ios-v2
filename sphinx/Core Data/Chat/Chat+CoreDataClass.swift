//
//  Chat+CoreDataClass.swift
//
//
//  Created by Tomas Timinskas on 06/11/2019.
//
//

import Foundation
import CoreData
import SwiftyJSON

@objc(Chat)
public class Chat: NSManagedObject {
    
    public enum ChatType: Int {
        case conversation = 0
        case privateGroup = 1
        case publicGroup = 2
        
        public init(fromRawValue: Int){
            self = ChatType(rawValue: fromRawValue) ?? .conversation
        }
    }
    
    public enum ChatStatus: Int {
        case approved = 0
        case pending = 1
        case rejected = 2
        
        public init(fromRawValue: Int){
            self = ChatStatus(rawValue: fromRawValue) ?? .approved
        }
    }
    
    public enum NotificationLevel: Int {
        case SeeAll = 0
        case OnlyMentions = 1
        case MuteChat = 2
        
        public init(fromRawValue: Int){
            self = NotificationLevel(rawValue: fromRawValue) ?? .SeeAll
        }
    }
    
    public var conversationContact : UserContact? = nil
    
    var image : UIImage? = nil
    var tribeInfo: GroupsManager.TribeInfo? = nil
    var aliasesAndPics: [(String, String)] = []
    
    
    static func getChatInstance(id: Int, managedContext: NSManagedObjectContext) -> Chat {
        if let ch = Chat.getChatWith(id: id) {
            return ch
        } else {
            return Chat(context: managedContext) as Chat
        }
    }
    
    var podcast: PodcastFeed? {
        get {
            if let feed = contentFeed {
                return PodcastFeed.convertFrom(contentFeed: feed)
            }
            return nil
        }
    }
    
    static func insertChat(chat: JSON) -> Chat? {
        if let id = getChatId(chat: chat) {
            let name = chat["name"].string ?? ""
            let photoUrl = chat["photo_url"].string ?? chat["img"].string ?? ""
            let uuid = chat["uuid"].stringValue
            let type = chat["type"].intValue
            let muted = chat["is_muted"].boolValue
            let seen = chat["seen"].boolValue
            let unlisted = chat["unlisted"].boolValue
            let privateTribe = chat["private"].boolValue
            let host = chat["host"].stringValue
            let groupKey = chat["group_key"].stringValue
            let ownerPubkey = chat["owner_pubkey"].stringValue
            let status = chat["status"].intValue
            let pricePerMessage = chat["price_per_message"].intValue
            let escrowAmount = chat["escrow_amount"].intValue
            let myAlias = chat["my_alias"].string
            let myPhotoUrl = chat["my_photo_url"].string
            let pinnedMessageUUID = chat["pin"].string
            let notify = chat["notify"].intValue
            let date = Date.getDateFromString(dateString: chat["created_at"].stringValue) ?? Date()
            let isTribeICreated = chat["is_tribe_i_created"].boolValue
            
            let contactIds = chat["contact_ids"].arrayObject as? [NSNumber] ?? []
            let pendingContactIds = chat["pending_contact_ids"].arrayObject as? [NSNumber] ?? []
            
//            let isInRemovedChatList = SphinxOnionManager.sharedInstance.isInRemovedTribeList(ownerPubkey: ownerPubkey)
//            if isInRemovedChatList == true{ return nil }
            
            let chat = Chat.createObject(
                id: id,
                name: name,
                photoUrl: photoUrl,
                uuid: uuid,
                type: type,
                status: status,
                muted: muted,
                seen: seen,
                unlisted: unlisted,
                privateTribe: privateTribe,
                host: host,
                groupKey: groupKey,
                ownerPubkey:ownerPubkey,
                pricePerMessage: pricePerMessage,
                escrowAmount: escrowAmount,
                myAlias: myAlias,
                myPhotoUrl: myPhotoUrl,
                notify: notify,
                pinnedMessageUUID: pinnedMessageUUID,
                contactIds: contactIds,
                pendingContactIds: pendingContactIds,
                date: date,
                isTribeICreated: isTribeICreated
            )
            
            return chat
        }
        return nil
    }
    
    static func getChatId(chat: JSON) -> Int? {
        var id : Int?
        if let idInt = chat["id"].int {
            id = idInt
        } else if let idString = chat["id"].string, let idInt = Int(idString) {
            id = idInt
        }
        return id
    }
    
    static func createObject(
        id: Int,
        name: String,
        photoUrl: String?,
        uuid: String?,
        type: Int,
        status: Int,
        muted: Bool,
        seen: Bool,
        unlisted: Bool,
        privateTribe: Bool,
        host: String?,
        groupKey: String?,
        ownerPubkey: String?,
        pricePerMessage: Int,
        escrowAmount: Int,
        myAlias: String?,
        myPhotoUrl: String?,
        notify: Int,
        pinnedMessageUUID: String?,
        contactIds: [NSNumber],
        pendingContactIds: [NSNumber],
        date: Date,
        isTribeICreated:Bool=false
    ) -> Chat? {
        
        let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext
        
        let chat = getChatInstance(id: id, managedContext: managedContext)
        chat.id = id
        chat.name = name
        chat.photoUrl = photoUrl
        chat.uuid = uuid
        chat.type = type
        chat.status = status
        chat.muted = muted
        chat.seen = seen
        chat.unlisted = unlisted
        chat.privateTribe = privateTribe
        chat.host = host
        chat.groupKey = groupKey
        chat.ownerPubkey = ownerPubkey
        chat.createdAt = date
        chat.myAlias = myAlias
        chat.myPhotoUrl = myPhotoUrl
        chat.notify = notify
        chat.contactIds = contactIds
        chat.pendingContactIds = pendingContactIds
        chat.subscription = chat.getContact()?.getCurrentSubscription()
        chat.isTribeICreated = isTribeICreated
        
        if chat.isMyPublicGroup() {
            chat.pricePerMessage = NSDecimalNumber(integerLiteral: pricePerMessage)
            chat.escrowAmount = NSDecimalNumber(integerLiteral: escrowAmount)
            chat.pinnedMessageUUID = pinnedMessageUUID
        }
        
        return chat
    }
    
    func isStatusPending() -> Bool {
        return self.status == ChatStatus.pending.rawValue
    }
    
    func isStatusRejected() -> Bool {
        return self.status == ChatStatus.rejected.rawValue
    }
    
    func getContactIdsArray() -> [Int] {
        var ids:[Int] = []
        for contactId in self.contactIds {
            ids.append(contactId.intValue)
        }
        return ids
    }
    
    func getPendingContactIdsArray() -> [Int] {
        var ids:[Int] = []
        for contactId in self.pendingContactIds {
            ids.append(contactId.intValue)
        }
        return ids
    }
    
    static func getAll() -> [Chat] {
        let predicate: NSPredicate? = Chat.Predicates.all()
        let chats:[Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(predicate: predicate, sortDescriptors: [], entityName: "Chat")
        return chats
    }
    
    public static func getAllExcluding(ids: [Int]) -> [Chat] {
        let predicate = NSPredicate(format: "NOT (id IN %@)", ids)
        
        let chats: [Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(predicate: predicate, sortDescriptors: [], entityName: "Chat")
        return chats
    }
    
    static func getAllTribes() -> [Chat] {
        let predicate = NSPredicate(format: "type == %d", Chat.ChatType.publicGroup.rawValue)
        
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let chats:[Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(predicate: predicate, sortDescriptors: sortDescriptors, entityName: "Chat")
        return chats
    }
    
    static func getTribeChatWithOwnerPubkey(ownerPubkey: String) -> Chat? {
        let predicate = NSPredicate(
            format: "type == %d AND ownerPubkey == %@",
            Chat.ChatType.publicGroup.rawValue,
            ownerPubkey
        )
        
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let chat : Chat? = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            entityName: "Chat",
            fetchLimit: 1
        ).first
        
        return chat
    }
    
    static func getChatTribesFor(ownerPubkeys: [String]) -> [Chat] {
        let predicate = NSPredicate(
            format: "type == %d AND ownerPubkey IN %@",
            Chat.ChatType.publicGroup.rawValue,
            ownerPubkeys
        )
        
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let chats : [Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            entityName: "Chat"
        )
        
        return chats
    }
    
    static func lookupAndCreateTribeChat(ownerPubkey:String) -> Chat? {
        
        
        return nil
    }
    
    public static func getAllConversations() -> [Chat] {
        let predicate = NSPredicate(format: "type = %d", Chat.ChatType.conversation.rawValue)
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let chats:[Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(predicate: predicate, sortDescriptors: sortDescriptors, entityName: "Chat")
        return chats
    }
    
    public static func getPrivateChats() -> [Chat] {
        let predicate = NSPredicate(format: "pin != null")
        let chats: [Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(predicate: predicate, sortDescriptors: [], entityName: "Chat")
        return chats
    }
    
    static func getOrCreateChat(chat: JSON) -> Chat? {
        let chatId = chat["id"].intValue
        if let chat = Chat.getChatWith(id: chatId) {
            return chat
        }
        return Chat.insertChat(chat: chat)
    }
    
    static func getChatWith(id: Int, managedContext: NSManagedObjectContext? = nil) -> Chat? {
        let predicate = NSPredicate(format: "id == %d", id)
        let sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        
        let chat: Chat? = CoreDataManager.sharedManager.getObjectOfTypeWith(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            entityName: "Chat",
            managedContext: managedContext
        )
        
        return chat
    }
    
    static func getChatWith(uuid: String) -> Chat? {
        let predicate = NSPredicate(format: "uuid == %@", uuid)
        let sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        let chat: Chat? = CoreDataManager.sharedManager.getObjectOfTypeWith(predicate: predicate, sortDescriptors: sortDescriptors, entityName: "Chat")
        
        return chat
    }
    
    static func getChatsWith(uuids: [String]) -> [Chat] {
        let predicate = NSPredicate(format: "uuid IN %@", uuids)
        let sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        
        let chats: [Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            entityName: "Chat"
        )
        
        return chats
    }
    
    func getAllMessages(
        limit: Int? = nil,
        context: NSManagedObjectContext? = nil
    ) -> [TransactionMessage] {
        
        return TransactionMessage.getAllMessagesFor(
            chat: self,
            limit: limit,
            context: context
        )
    }
    
    func getNewMessagesCount(lastMessageId: Int? = nil) -> Int {
        guard let lastMessageId = lastMessageId else {
            return 0
        }
        return TransactionMessage.getNewMessagesCountFor(chat: self, lastMessageId: lastMessageId)
    }
    
    func setChatMessagesAsSeen(
        shouldSync: Bool = true,
        shouldSave: Bool = true
    ) {
        let receivedUnseenMessages = getReceivedUnseenMessages()
        
        if receivedUnseenMessages.count > 0 {
            for m in receivedUnseenMessages {
                m.seen = true
            }
        }
        
        if !self.seen {
            seen = true
        }
        
        unseenMessagesCount = 0
        unseenMentionsCount = 0
        
        if let highestIndex = TransactionMessage.getMaxIndexFor(chat: self),
           SphinxOnionManager.sharedInstance.messageIdIsFromHashed(msgId: highestIndex) == false
        {
            SphinxOnionManager.sharedInstance.setReadLevel(index: UInt64(highestIndex), chat: self, recipContact: self.getContact())
        }
        
        CoreDataManager.sharedManager.saveContext()
    }
    
    func getReceivedUnseenMessages(
        context: NSManagedObjectContext? = nil
    ) -> [TransactionMessage] {
        
        let userId = UserData.sharedInstance.getUserId()
        
        let predicate = NSPredicate(
            format: "(senderId != %d || type == %d) AND chat == %@ AND seen == %@",
            userId,
            TransactionMessage.TransactionMessageType.groupJoin.rawValue,
            self,
            NSNumber(booleanLiteral: false)
        )
        
        let messages: [TransactionMessage] = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors: [],
            entityName: "TransactionMessage",
            context: context
        )
        
        return messages
    }
    
    var unseenMessagesCount: Int = 0
    
    func getReceivedUnseenMessagesCount() -> Int {
        return unseenMessagesCount
    }
    
    var unseenMentionsCount: Int = 0
    
    func getReceivedUnseenMentionsCount() -> Int {
        return unseenMentionsCount
    }
    
    func calculateBadge() {
        calculateUnseenMessagesCount()
        calculateUnseenMentionsCount()
    }
    
    func calculateBadgeWith(
        messagesCount: Int,
        mentionsCount: Int
    ) {
        unseenMessagesCount = messagesCount
        unseenMentionsCount = mentionsCount
    }
    
    static func updateMessageReadStatus(chatId: Int, lastReadId: Int) {
        let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<TransactionMessage> = TransactionMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "chat.id == %d", chatId)
        
        do {
            let messages = try managedContext.fetch(fetchRequest)
            for (index, message) in messages.enumerated() {
                if message.id <= lastReadId {
                    if index == 0 {
                        message.chat?.seen = true
                    }
                    message.seen = true
                } else {
                    message.chat?.seen = false
                }
            }
            try managedContext.save()
        } catch let error as NSError {
            print("Error updating messages read status: \(error), \(error.userInfo)")
        }
    }
    
    static func hasRemovalIndicators(chat: Chat) -> Bool {
        let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext

        let groupDeleteType = TransactionMessage.TransactionMessageType.groupDelete.rawValue
        let groupLeaveType = TransactionMessage.TransactionMessageType.groupLeave.rawValue
        let groupJoinType = TransactionMessage.TransactionMessageType.groupJoin.rawValue
        let memberRejectType = TransactionMessage.TransactionMessageType.memberReject.rawValue
        let memberKickType = TransactionMessage.TransactionMessageType.groupKick.rawValue

        // First, check for any groupDelete messages
        let deletePredicate = NSPredicate(format: "chat == %@ AND type == %d", chat, groupDeleteType)
        let deleteFetchRequest: NSFetchRequest<TransactionMessage> = TransactionMessage.fetchRequest()
        deleteFetchRequest.predicate = deletePredicate
        deleteFetchRequest.fetchLimit = 1

        do {
            let deleteMessages = try managedContext.fetch(deleteFetchRequest)
            if !deleteMessages.isEmpty {
                return true
            }
        } catch {
            print("Failed to fetch delete messages: \(error)")
            return false
        }

        // Construct predicates for leave, reject, and kick events
        let leavePredicate = NSPredicate(format: "chat == %@ AND type == %d AND senderId == %d", chat, groupLeaveType, 0)
        
        let rejectPredicate: NSPredicate? = chat.isTribeICreated ? nil : NSPredicate(format: "chat == %@ AND type == %d", chat, memberRejectType)
        
        let kickPredicate: NSPredicate? = chat.isTribeICreated ? nil : NSPredicate(format: "chat == %@ AND type == %d", chat, memberKickType)
        
        var eventPredicates = [leavePredicate]
        if let rejectPredicate = rejectPredicate {
            eventPredicates.append(rejectPredicate)
        }
        if let kickPredicate = kickPredicate {
            eventPredicates.append(kickPredicate)
        }

        let combinedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: eventPredicates)
        let leaveFetchRequest: NSFetchRequest<TransactionMessage> = TransactionMessage.fetchRequest()
        leaveFetchRequest.predicate = combinedPredicate
        leaveFetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        leaveFetchRequest.fetchLimit = 1

        do {
            let leaveMessages = try managedContext.fetch(leaveFetchRequest)
            if let leaveMessage = leaveMessages.first, let leaveMessageDate = leaveMessage.date {
                // Check for newer groupJoin messages
                let joinPredicate = NSPredicate(format: "chat == %@ AND type == %d AND date > %@", chat, groupJoinType, leaveMessageDate as NSDate)
                let joinFetchRequest: NSFetchRequest<TransactionMessage> = TransactionMessage.fetchRequest()
                joinFetchRequest.predicate = joinPredicate
                joinFetchRequest.fetchLimit = 1

                do {
                    let joinMessages = try managedContext.fetch(joinFetchRequest)
                    if joinMessages.isEmpty {
                        return true
                    }
                } catch {
                    print("Failed to fetch join messages: \(error)")
                    return false
                }
            }
        } catch {
            print("Failed to fetch leave messages: \(error)")
            return false
        }

        return false
    }
    
    static func calculateUnseenMessagesCount(
        mentions: Bool
    ) -> [Int: Int] {
        let userId = UserData.sharedInstance.getUserId()
        
        var predicate = NSPredicate(
            format: "(senderId != %d || type == %d) AND seen == %@ AND chat.seen == %@",
            userId,
            TransactionMessage.TransactionMessageType.groupJoin.rawValue,
            NSNumber(booleanLiteral: false),
            NSNumber(booleanLiteral: false)
        )
        
        if mentions {
            predicate = NSPredicate(
                format: "(senderId != %d || type == %d) AND seen == %@ AND push == %@ AND chat.seen == %@",
                userId,
                TransactionMessage.TransactionMessageType.groupJoin.rawValue,
                NSNumber(booleanLiteral: false),
                NSNumber(booleanLiteral: true),
                NSNumber(booleanLiteral: false)
            )
        }
        
        let messages: [TransactionMessage] = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors: [],
            entityName: "TransactionMessage"
        )
        
        var messagesCountMap: [Int: Int] = [:]
        
        for m in messages {
            if let chatId = m.chat?.id {
                if let messagesCount = messagesCountMap[chatId] {
                    messagesCountMap[chatId] = messagesCount + 1
                } else {
                    messagesCountMap[chatId] = 1
                }
            }
        }
        
        return messagesCountMap
    }
    
    func calculateUnseenMessagesCount() {
        let userId = UserData.sharedInstance.getUserId()
        let predicate = NSPredicate(
            format: "(senderId != %d || type == %d) AND chat == %@ AND seen == %@ AND chat.seen == %@",
            userId,
            TransactionMessage.TransactionMessageType.groupJoin.rawValue,
            self,
            NSNumber(booleanLiteral: false),
            NSNumber(booleanLiteral: false)
        )
        unseenMessagesCount = CoreDataManager.sharedManager.getObjectsCountOfTypeWith(predicate: predicate, entityName: "TransactionMessage")        
    }
    
    func calculateUnseenMentionsCount() {
        let userId = UserData.sharedInstance.getUserId()
        let predicate = NSPredicate(
            format: "(senderId != %d || type == %d) AND chat == %@ AND seen == %@ AND push == %@ AND chat.seen == %@",
            userId,
            TransactionMessage.TransactionMessageType.groupJoin.rawValue,
            self,
            NSNumber(booleanLiteral: false),
            NSNumber(booleanLiteral: true),
            NSNumber(booleanLiteral: false)
        )
        unseenMentionsCount = CoreDataManager.sharedManager.getObjectsCountOfTypeWith(predicate: predicate, entityName: "TransactionMessage")
    }
    
    func getLastMessageToShow() -> TransactionMessage? {
        let sortDescriptors = [NSSortDescriptor(key: "date", ascending: false), NSSortDescriptor(key: "id", ascending: false)]
        let predicate = NSPredicate(format: "chat == %@ AND type != %d", self, TransactionMessage.TransactionMessageType.repayment.rawValue)
        let messages: [TransactionMessage] = CoreDataManager.sharedManager.getObjectsOfTypeWith(predicate: predicate, sortDescriptors: sortDescriptors, entityName: "TransactionMessage", fetchLimit: 1)
        return messages.first
    }
    
    public func setLastMessage(_ message: TransactionMessage) {
        guard let lastM = lastMessage else {
            lastMessage = message
            calculateBadge()
            return
        }
        
        if (lastM.messageDate < message.messageDate) {
            lastMessage = message
            calculateBadge()
        }
    }
    
    public func updateLastMessage() {
        if lastMessage == nil && messages?.count ?? 0 > 0 {
            lastMessage = getLastMessageToShow()
        }
    }
    
    public func groupChatUserAlias(id: Int) -> String? {
        // Get the managed object context
        let context = CoreDataManager.sharedManager.persistentContainer.viewContext
        
        // Create a fetch request for TransactionMessage with a predicate to find the message with the given senderId
        let fetchRequest = NSFetchRequest<TransactionMessage>(entityName: "TransactionMessage")
        
        
        // Set the predicate to find the first message with a matching senderId
        fetchRequest.predicate = NSPredicate(format: "chat == %@ AND senderId == %d", self, id)
        
        // Set fetch limit to 1, as we only need the first matching message
        fetchRequest.fetchLimit = 1
        
        do {
            // Execute the fetch request
            let results = try context.fetch(fetchRequest)
            
            // If a matching message is found, return its senderAlias
            if let matchingMessage = results.first {
                return matchingMessage.senderAlias
            }
            
            // If no matching message is found, return nil
            return nil
        } catch {
            // If an error occurs, return nil
            return nil
        }
    }
    
    public func getContact() -> UserContact? {
        if self.type == Chat.ChatType.conversation.rawValue {
            return getConversationContact()
        }
        return nil
    }
    
    func getAdmin() -> UserContact? {
        let contacts = getContacts(includeOwner: false)
        if self.type == Chat.ChatType.publicGroup.rawValue && contacts.count > 0 {
            return contacts.first
        }
        return nil
    }
    
    func getContactForRouteCheck() -> UserContact? {
        if let contact = getContact() {
            return contact
        }
        if let admin = getAdmin() {
            return admin
        }
        return nil
    }
    
    func getContacts(includeOwner: Bool = true, ownerAtEnd: Bool = false) -> [UserContact] {
        let ids:[Int] = self.getContactIdsArray()
        let contacts: [UserContact] = UserContact.getContactsWith(ids: ids, includeOwner: includeOwner, ownerAtEnd: ownerAtEnd)
        return contacts
    }
    
    func getPendingContacts() -> [UserContact] {
        let ids:[Int] = self.getPendingContactIdsArray()
        let contacts: [UserContact] = UserContact.getContactsWith(ids: ids, includeOwner: false, ownerAtEnd: false)
        return contacts
    }
    
    func removedFromGroup() -> Bool {
        let predicate = NSPredicate(format: "chat == %@ AND type == %d", self, TransactionMessage.TransactionMessageType.groupKick.rawValue)
        let messagesCount = CoreDataManager.sharedManager.getObjectsCountOfTypeWith(predicate: predicate, entityName: "TransactionMessage")
        return messagesCount > 0
    }
    
    func isPendingMember(id: Int) -> Bool {
        return getPendingContactIdsArray().contains(id)
    }
    
    func isActiveMember(id: Int) -> Bool {
        return getContactIdsArray().contains(id)
    }
    
    
    func updateTribeInfo(completion: @escaping () -> ()) {
        if let uuid = ownerPubkey, isPublicGroup() {
            let host = SphinxOnionManager.sharedInstance.tribesServerIP
            
            API.sharedInstance.getTribeInfo(
                host: host,
                uuid: uuid,
                callback: { chatJson in
                    self.tribeInfo = GroupsManager.sharedInstance.getTribesInfoFrom(json: chatJson)
                    self.updateChatFromTribesInfo()
                    
                    if let feedUrl = self.tribeInfo?.feedUrl, !feedUrl.isEmpty {
                        ContentFeed.fetchChatFeedContentInBackground(feedUrl: feedUrl, chatId: self.id) { feedId in
                            if let feedId = feedId {
                                self.contentFeed = ContentFeed.getFeedById(feedId: feedId)
                                self.saveChat()
                            }
                            completion()
                        }
                        return
                    } else if let existingFeed = self.contentFeed {
                        ContentFeed.deleteFeedWith(feedId: existingFeed.feedID)
                    }
                    completion()
                },
                errorCallback: {
                    completion()
                }
            )
        }
    }
    
    
    
    func getAppUrl() -> String? {
        if let tribeInfo = self.tribeInfo, let appUrl = tribeInfo.appUrl, !appUrl.isEmpty {
            return appUrl
        }
        return nil
    }
    
    func getSecondBrainAppUrl() -> String? {
        if let tribeInfo = self.tribeInfo, let secondBrainUrl = tribeInfo.secondBrainUrl, !secondBrainUrl.isEmpty {
            return secondBrainUrl
        }
        return nil
    }

    
    func getFeedUrl() -> String? {
        if
            let tribeInfo = self.tribeInfo,
            let feedUrl = tribeInfo.feedUrl,
            feedUrl.isEmpty == false
        {
            return feedUrl
        }
        return nil
    }
    
    func updateWebAppLastDate() {
        self.webAppLastDate = Date()
    }
    
    func getTribePrices() -> (Int, Int) {
        return (self.pricePerMessage?.intValue ?? 0, self.escrowAmount?.intValue ?? 0)
    }
    
    func updateChatFromTribesInfo() {
        if isMyPublicGroup() {
            pinnedMessageUUID = tribeInfo?.pin ?? nil
            saveChat()
            return
        }
        
        escrowAmount = NSDecimalNumber(integerLiteral: tribeInfo?.amountToStake ?? (escrowAmount?.intValue ?? 0))
        pricePerMessage = NSDecimalNumber(integerLiteral: tribeInfo?.pricePerMessage ?? (pricePerMessage?.intValue ?? 0))
        pinnedMessageUUID = tribeInfo?.pin ?? nil
        name = (tribeInfo?.name?.isEmpty ?? true) ? name : tribeInfo!.name
        
        let tribeImage = tribeInfo?.img ?? photoUrl
        
        if photoUrl != tribeImage {
            photoUrl = tribeImage
            image = nil
        }
        
        syncAfterUpdate()
    }
    
    func syncAfterUpdate() {
        syncTribeWithServer()
        checkForDeletedTribe()
    } 
    
    func checkForDeletedTribe() {
        if let tribeInfo = self.tribeInfo, tribeInfo.deleted {
            if let lastMessage = self.getAllMessages(limit: 1).last, lastMessage.type != TransactionMessage.TransactionMessageType.groupDelete.rawValue {
                AlertHelper.showAlert(title: "deleted.tribe.title".localized, message: "deleted.tribe.description".localized)
            }
        }
    }
    
    func shouldShowPrice() -> Bool {
        return (pricePerMessage?.intValue ?? 0) > 0
    }
    
    func isGroup() -> Bool {
        return type == Chat.ChatType.privateGroup.rawValue || type == Chat.ChatType.publicGroup.rawValue
    }
    
    func isPrivateGroup() -> Bool {
        return type == Chat.ChatType.privateGroup.rawValue
    }
    
    public func isPublicGroup() -> Bool {
        return type == Chat.ChatType.publicGroup.rawValue
    }
    
    public func isConversation() -> Bool {
        return type == Chat.ChatType.conversation.rawValue
    }
    
    public func isEncrypted() -> Bool {
        return true
    }
    
    func isMyPublicGroup() -> Bool {
        return isPublicGroup() && isTribeICreated == true
    }
    
    
    func syncTribeWithServer() {
        DispatchQueue.global().async {
            let params: [String: AnyObject] = ["name" : self.name as AnyObject, "img": self.photoUrl as AnyObject]
            //TODO: @Jim implement when edit group binding available
//            API.sharedInstance.editGroup(id: self.id, params: params, callback: { _ in }, errorCallback: {})
        }
    }
    
    func getJoinChatLink() -> String? {
        if let pubkey = self.ownerPubkey {
            return "sphinx.chat://?action=tribeV2&pubkey=\(pubkey)&host=\(SphinxOnionManager.sharedInstance.tribesServerIP)"
        }
        return nil
    }
    
    func processAliases() {
        if self.isConversation() {
            return
        }
        
        let backgroundContext = CoreDataManager.sharedManager.getBackgroundContext()
        
        backgroundContext.perform {
            let messages = self.getAllMessages(
                limit: 2000,
                context: backgroundContext
            )
            
            for message in messages {
                if let alias = message.senderAlias, alias.isNotEmpty {
                    if !self.aliasesAndPics.contains(where: {$0.0 == alias}) {
                        self.aliasesAndPics.append(
                            (alias, message.senderPic ?? "")
                        )
                    }
                }
            }
        }
    }
    
    func processAliasesFrom(
        messages: [TransactionMessage]
    ) {
        for message in messages {
            if let alias = message.senderAlias, alias.isNotEmpty {
                if !aliasesAndPics.contains(where: {$0.0 == alias}) {
                    self.aliasesAndPics.append(
                        (alias, message.senderPic ?? "")
                    )
                }
            }
        }
    }
    
    func getActionsMenuOptions() -> [TransactionMessage.ActionsMenuOption] {
        let isRead = lastMessage?.seen ?? false
        
        let options = [
            TransactionMessage.ActionsMenuOption.init(
                tag: TransactionMessage.MessageActionsItem.ToggleReadUnread,
                materialIconName: isRead ? "" : "",
                iconImage: nil,
                label: isRead ? "mark.as.unread".localized : "mark.as.read".localized
            )
        ]
        
        return options
    }
    
    func saveChat() {
        CoreDataManager.sharedManager.saveContext()
    }
}
