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
    var timezoneData: [String: String] = [:]
    
    
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
    
    static func getAll(context: NSManagedObjectContext? = nil) -> [Chat] {
        let predicate: NSPredicate? = Chat.Predicates.all()
        let chats:[Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(predicate: predicate, sortDescriptors: [], entityName: "Chat", context: context)
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
    
    static func getAllSecondBrainTribes() -> [Chat] {
        let predicate = NSPredicate(format: "type == %d AND secondBrainUrl != nil", Chat.ChatType.publicGroup.rawValue)
        
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let chats:[Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            entityName: "Chat"
        )
        
        return chats
    }
    
    static func getTribeChatWithOwnerPubkey(
        ownerPubkey: String,
        context: NSManagedObjectContext? = nil
    ) -> Chat? {
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
            fetchLimit: 1,
            context: context
        ).first
        
        return chat
    }
    
    static func getChatTribesFor(
        ownerPubkeys: [String],
        context: NSManagedObjectContext? = nil
    ) -> [Chat] {
        let predicate = NSPredicate(
            format: "type == %d AND ownerPubkey IN %@",
            Chat.ChatType.publicGroup.rawValue,
            ownerPubkeys
        )
        
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let chats : [Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            entityName: "Chat",
            context: context
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
        let predicate = NSPredicate(format: "pin != nil")
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
        context: NSManagedObjectContext? = nil,
        forceAllMsgs: Bool = false
    ) -> [TransactionMessage] {
        
        return TransactionMessage.getAllMessagesFor(
            chat: self,
            limit: limit,
            context: context,
            forceAllMsgs: forceAllMsgs
        )
    }
    
    func setChatMessagesAsSeen(
        shouldSync: Bool = true,
        shouldSave: Bool = true
    ) {
        let backgroundContext = CoreDataManager.sharedManager.getBackgroundContext()
        
        backgroundContext.perform { [weak self] in
            guard let self = self else {
                return
            }
            guard let chat = Chat.getChatWith(id: self.id, managedContext: backgroundContext) else {
                return
            }
            let receivedUnseenMessages = chat.getReceivedUnseenMessages(context: backgroundContext)
            
            if receivedUnseenMessages.count > 0 {
                for m in receivedUnseenMessages {
                    m.seen = true
                }
            }
            
            if !chat.seen {
                chat.seen = true
            }
            
            chat.unseenMessagesCount = 0
            chat.unseenMentionsCount = 0
            
            if let lastMessage = chat.getLastMessageToShow(
                includeContactKeyTypes: true,
                sortById: true,
                context: backgroundContext
            ) {
                if lastMessage.isKeyExchangeType() || (lastMessage.isTribeInitialMessageType() && chat.messages?.count == 1) {
                    if let maxMessageIndex = TransactionMessage.getMaxIndex(context: backgroundContext) {
                        let _  = SphinxOnionManager.sharedInstance.setReadLevel(
                            index: UInt64(maxMessageIndex),
                            chat: chat,
                            recipContact: chat.getConversationContact(context: backgroundContext)
                        )
                    }
                } else if SphinxOnionManager.sharedInstance.messageIdIsFromHashed(msgId: lastMessage.id) == false {
                    let _ = SphinxOnionManager.sharedInstance.setReadLevel(
                        index: UInt64(lastMessage.id),
                        chat: chat,
                        recipContact: chat.getConversationContact(context: backgroundContext)
                    )
                }
            }
        
            backgroundContext.saveContext()
        }
    }
    
    func getReceivedUnseenMessages(
        context: NSManagedObjectContext
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
    
    static func updateMessageReadStatus(
        chatId: Int,
        lastReadId: Int,
        context: NSManagedObjectContext? = nil
    ) {
        let managedContext = context ?? CoreDataManager.sharedManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<TransactionMessage> = TransactionMessage.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(
            format: "chat.id == %d AND (seen = %@ || id > %d)",
            chatId,
            NSNumber(booleanLiteral: false),
            lastReadId
        )
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]

        do {
            let messages = try managedContext.fetch(fetchRequest)
            for (index, message) in messages.enumerated() {
                if message.id <= lastReadId {
                    if index == 0 {
                        message.chat?.seen = true
                    }
                    message.seen = true
                } else {
                    message.seen = false
                    message.chat?.seen = false
                }
            }
            try managedContext.save()
        } catch let error as NSError {
            print("Error updating messages read status: \(error), \(error.userInfo)")
        }
    }
    
    static func calculateUnseenMessagesCount(
        mentions: Bool
    ) -> [Int: Int] {
        let userId = UserData.sharedInstance.getUserId()
        
        var predicate = NSPredicate(
            format: "(senderId != %d || type == %d) AND seen == %@ AND chat.seen == %@ AND NOT (type IN %@)",
            userId,
            TransactionMessage.TransactionMessageType.groupJoin.rawValue,
            NSNumber(booleanLiteral: false),
            NSNumber(booleanLiteral: false),
            [
                TransactionMessage.TransactionMessageType.delete.rawValue,
                TransactionMessage.TransactionMessageType.contactKey.rawValue,
                TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue,
                TransactionMessage.TransactionMessageType.unknown.rawValue
            ]
        )
        
        if mentions {
            predicate = NSPredicate(
                format: "(senderId != %d || type == %d) AND seen == %@ AND push == %@ AND chat.seen == %@ AND NOT (type IN %@)",
                userId,
                TransactionMessage.TransactionMessageType.groupJoin.rawValue,
                NSNumber(booleanLiteral: false),
                NSNumber(booleanLiteral: true),
                NSNumber(booleanLiteral: false),
                [
                    TransactionMessage.TransactionMessageType.delete.rawValue,
                    TransactionMessage.TransactionMessageType.contactKey.rawValue,
                    TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue,
                    TransactionMessage.TransactionMessageType.unknown.rawValue
                ]
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
            format: "(senderId != %d || type == %d) AND chat == %@ AND seen == %@ AND chat.seen == %@ AND NOT (type IN %@)",
            userId,
            TransactionMessage.TransactionMessageType.groupJoin.rawValue,
            self,
            NSNumber(booleanLiteral: false),
            NSNumber(booleanLiteral: false),
            [
                TransactionMessage.TransactionMessageType.delete.rawValue,
                TransactionMessage.TransactionMessageType.contactKey.rawValue,
                TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue,
                TransactionMessage.TransactionMessageType.unknown.rawValue
            ]
        )
        unseenMessagesCount = CoreDataManager.sharedManager.getObjectsCountOfTypeWith(predicate: predicate, entityName: "TransactionMessage")        
    }
    
    func calculateUnseenMentionsCount() {
        let userId = UserData.sharedInstance.getUserId()
        let predicate = NSPredicate(
            format: "(senderId != %d || type == %d) AND chat == %@ AND seen == %@ AND push == %@ AND chat.seen == %@ AND NOT (type IN %@)",
            userId,
            TransactionMessage.TransactionMessageType.groupJoin.rawValue,
            self,
            NSNumber(booleanLiteral: false),
            NSNumber(booleanLiteral: true),
            NSNumber(booleanLiteral: false),
            [
                TransactionMessage.TransactionMessageType.delete.rawValue,
                TransactionMessage.TransactionMessageType.contactKey.rawValue,
                TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue,
                TransactionMessage.TransactionMessageType.unknown.rawValue
            ]
        )
        unseenMentionsCount = CoreDataManager.sharedManager.getObjectsCountOfTypeWith(predicate: predicate, entityName: "TransactionMessage")
    }
    
    func getOkKeyMessages() -> [TransactionMessage] {
        let types = [
            TransactionMessage.TransactionMessageType.payment.rawValue,
            TransactionMessage.TransactionMessageType.directPayment.rawValue,
            TransactionMessage.TransactionMessageType.purchase.rawValue,
            TransactionMessage.TransactionMessageType.boost.rawValue,
            TransactionMessage.TransactionMessageType.contactKey.rawValue,
            TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue
        ]
        
        let predicate = NSPredicate(
            format: "chat == %@ AND type IN %@",
            self,
            types
        )
        
        let messages: [TransactionMessage] = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors:[],
            entityName: "TransactionMessage"
        )
        
        return messages
    }
    
    func getLastMessageToShow(
        includeContactKeyTypes: Bool = false,
        sortById: Bool = false,
        context: NSManagedObjectContext? = nil
    ) -> TransactionMessage? {
        let context = context ?? CoreDataManager.sharedManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<TransactionMessage> = TransactionMessage.fetchRequest()
        
        var typeToExclude = [
            TransactionMessage.TransactionMessageType.contactKey.rawValue,
            TransactionMessage.TransactionMessageType.contactKeyConfirmation.rawValue,
            TransactionMessage.TransactionMessageType.unknown.rawValue
        ]
        
        if includeContactKeyTypes {
            typeToExclude = []
        }
        
        fetchRequest.predicate = NSPredicate(
            format: "chat == %@ AND NOT (type IN %@)",
            self,
            typeToExclude
        )
        
        if sortById {
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        } else {
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        }
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch let error as NSError {
            print("Error fetching message with max ID: \(error), \(error.userInfo)")
            return nil
        }
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
    
    func getContacts(
        includeOwner: Bool = true,
        ownerAtEnd: Bool = false,
        context: NSManagedObjectContext? = nil
    ) -> [UserContact] {
        let ids:[Int] = self.getContactIdsArray()
        let contacts: [UserContact] = UserContact.getContactsWith(
            ids: ids,
            includeOwner: includeOwner,
            ownerAtEnd: ownerAtEnd,
            context: context
        )
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
                        let _ = ContentFeed.deleteFeedWith(feedId: existingFeed.feedID)
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
    
    func hasWebApp() -> Bool {
        return tribeInfo?.appUrl != nil && tribeInfo?.appUrl?.isEmpty == false
    }
    
    func hasSecondBrainApp() -> Bool {
        return tribeInfo?.secondBrainUrl != nil && tribeInfo?.secondBrainUrl?.isEmpty == false
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
        return (
            (self.pricePerMessage?.intValue ?? 0) / 1000,
            (self.escrowAmount?.intValue ?? 0) / 1000
        )
    }
    
    func updateChatFromTribesInfo() {
        escrowAmount = NSDecimalNumber(integerLiteral: tribeInfo?.amountToStake ?? (escrowAmount?.intValue ?? 0))
        pricePerMessage = NSDecimalNumber(integerLiteral: tribeInfo?.pricePerMessage ?? (pricePerMessage?.intValue ?? 0))
        pinnedMessageUUID = tribeInfo?.pin ?? nil
        name = (tribeInfo?.name?.isEmpty ?? true) ? name : tribeInfo!.name
        
        let tribeImage = tribeInfo?.img ?? photoUrl
        
        if photoUrl != tribeImage {
            photoUrl = tribeImage
            image = nil
        }
        
        self.secondBrainUrl = tribeInfo?.secondBrainUrl
        
        saveChat()
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
    
    public static func processTimezoneChanges() {
        DispatchQueue.global(qos: .background).async {
            let backgroundContext = CoreDataManager.sharedManager.getBackgroundContext()
            
            backgroundContext.perform {
                let didMigrateToTZ: Bool = UserDefaults.Keys.didMigrateToTZ.get(defaultValue: false)
                
                if !didMigrateToTZ {
                    Chat.resetTimezones(context: backgroundContext)
                }
                
                if let systemTimezone: String? = UserDefaults.Keys.systemTimezone.get() {
                    if systemTimezone != TimeZone.current.abbreviation() {
                        Chat.setChatsToTimezoneUpdated(context: backgroundContext)
                    }
                }
                
                UserDefaults.Keys.systemTimezone.set(TimeZone.current.abbreviation())
                UserDefaults.Keys.didMigrateToTZ.set(true)
                
                backgroundContext.saveContext()
            }
        }
    }
    
    public static func resetTimezones(context: NSManagedObjectContext) {
        let chats: [Chat] = Chat.getAll(context: context)
        
        for chat in chats {
            chat.remoteTimezoneIdentifier = nil
            chat.timezoneIdentifier = nil
            chat.timezoneEnabled = true
            chat.timezoneUpdated = true
        }
    }
    
    public static func setChatsToTimezoneUpdated(context: NSManagedObjectContext) {
        let predicate = NSPredicate(format: "timezoneIdentifier == nil && timezoneEnabled == true")
        
        let chats: [Chat] = CoreDataManager.sharedManager.getObjectsOfTypeWith(
            predicate: predicate,
            sortDescriptors: [],
            entityName: "Chat",
            context: context
        )
        
        for chat in chats {
            chat.timezoneUpdated = true
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
        
        backgroundContext.perform { [weak self] in
            guard let self = self else {
                return
            }
            self.aliasesAndPics = []
            
            let messages = self.getAllMessages(
                limit: 2000,
                context: backgroundContext,
                forceAllMsgs: true
            )
            
            self.processAliasesFrom(messages: messages.reversed())
        }
    }
 
    func processAliasesFrom(
        messages: [TransactionMessage]
    ) {
        let ownerId = UserData.sharedInstance.getUserId()
        
        let declinedRequestResponses = messages.filter { $0.isDeclinedRequest() }
        let declinedRequestResponsesDictionary = Dictionary(uniqueKeysWithValues: declinedRequestResponses.map { ($0.replyUUID, $0) })
        
        for message in messages {
            if !message.isIncoming(ownerId: ownerId) {
                continue
            }
            if isDateBeforeThreeMonthsAgo(message.messageDate) {
                continue
            }
            if let alias = message.senderAlias, alias.isNotEmpty {
                if let remoteTimezoneIdentifier = message.remoteTimezoneIdentifier, remoteTimezoneIdentifier.isNotEmpty {
                    timezoneData[alias] = remoteTimezoneIdentifier
                }
                if let picture = message.senderPic, picture.isNotEmpty {
                    if message.isMemberRequest() {
                        if
                            let originalRequestMsg = declinedRequestResponsesDictionary[message.uuid],
                            let alias = originalRequestMsg.senderAlias, alias.isNotEmpty,
                            let picture = originalRequestMsg.senderPic, picture.isNotEmpty
                        {
                            if let index = aliasesAndPics.firstIndex(where: { $0.1 == picture || $0.0 == alias }) {
                                aliasesAndPics.remove(at: index)
                            }
                            continue
                        }
                    }
                    if message.isGroupLeaveMessage() {
                        if let index = aliasesAndPics.firstIndex(where: { $0.1 == picture || $0.0 == alias }) {
                            aliasesAndPics.remove(at: index)
                        }
                        continue
                    }
                    if let index = aliasesAndPics.firstIndex(where: { $0.0 == alias }) {
                        self.aliasesAndPics[index] = (alias, message.senderPic ?? "")
                    } else if !aliasesAndPics.contains(where: { $0.1 == picture || $0.0 == alias }) {
                        self.aliasesAndPics.append(
                            (alias, message.senderPic ?? "")
                        )
                    }
                } else {
                    if message.isMemberRequest() {
                        if
                            let originalRequestMsg = declinedRequestResponsesDictionary[message.uuid],
                            let alias = originalRequestMsg.senderAlias, alias.isNotEmpty
                        {
                            if let index = aliasesAndPics.firstIndex(where: { $0.0 == alias }) {
                                aliasesAndPics.remove(at: index)
                            }
                            continue
                        }
                    }
                    if message.isGroupLeaveMessage() {
                        if let index = aliasesAndPics.firstIndex(where: { $0.0 == alias }) {
                            aliasesAndPics.remove(at: index)
                        }
                        continue
                    }
                    if let index = aliasesAndPics.firstIndex(where: { $0.0 == alias }) {
                        self.aliasesAndPics[index] = (alias, message.senderPic ?? "")
                    } else {
                        self.aliasesAndPics.append(
                            (alias, message.senderPic ?? "")
                        )
                    }
                }
            }
        }
    }
    
    func isDateBeforeThreeMonthsAgo(_ date: Date) -> Bool {
        let calendar = Calendar.current
        if let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date()) {
            return date < threeMonthsAgo
        }
        return false
    }
    
    func getActionsMenuOptions() -> [TransactionMessage.ActionsMenuOption] {
        let isRead = lastMessage?.seen ?? false
        
        var options: [TransactionMessage.ActionsMenuOption] = []
        
        if lastMessage?.isOutgoing() == false {
            options.append(
                TransactionMessage.ActionsMenuOption.init(
                    tag: TransactionMessage.MessageActionsItem.ToggleReadUnread,
                    materialIconName: isRead ? "" : "",
                    iconImage: nil,
                    label: isRead ? "mark.as.unread".localized : "mark.as.read".localized
                )
            )
        }
        
        if isConversation() {
            options.append(
                TransactionMessage.ActionsMenuOption.init(
                    tag: TransactionMessage.MessageActionsItem.Delete,
                    materialIconName: "delete",
                    iconImage: nil,
                    label: "delete.contact".localized
                )
            )
        }
        
        return options
    }
    
    func getMetaDataJsonStringValue() -> String? {
        var metaData: String? = nil
        
        if self.timezoneEnabled, self.timezoneUpdated {
            if let timezoneToSend = TimeZone(identifier: self.timezoneIdentifier ?? TimeZone.current.identifier)?.abbreviation() {
                let timezoneMetadata = ["tz": timezoneToSend]
                
                if let metadataJSON = try? JSONSerialization.data(withJSONObject: timezoneMetadata),
                   let metadataString = String(data: metadataJSON, encoding: .utf8) {
                    metaData = metadataString
                }
            }
        }
        
        return metaData
    }
    
    func saveChat() {
        CoreDataManager.sharedManager.saveContext()
    }
}
