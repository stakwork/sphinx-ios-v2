//
//  Library
//
//  Created by Tomas Timinskas on 18/03/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

final class ChatListViewModel {
    
    init() {}
    
    public static let kMessagesPerPage: Int = 200
    
    func loadFriends(
        progressCompletion: ((Bool) -> ())? = nil,
        completion: @escaping (Bool) -> ()
    ) {
        let restoring = self.isRestoring()
        
        SphinxOnionManager.sharedInstance.restoreFirstScidMessages()
    }
    
    func saveObjects(
        contacts: [JSON],
        chats: [JSON],
        subscriptions: [JSON],
        invites: [JSON]
    ) {
        UserContactsHelper.insertObjects(
            contacts: contacts,
            chats: chats,
            subscriptions: subscriptions,
            invites: invites
        )
    }
    
    func forceKeychainSync() {
        UserData.sharedInstance.forcePINSyncOnKeychain()
        UserData.sharedInstance.saveNewNodeOnKeychain()
        EncryptionManager.sharedInstance.saveKeysOnKeychain()
    }
    
    func authenticateWithMemesServer() {
        AttachmentsManager.sharedInstance.runAuthentication()
    }
    
    func askForNotificationPermissions() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.registerForPushNotifications()
    }
    
    func isRestoring() -> Bool {
        return API.sharedInstance.lastSeenMessagesDate == nil
    }
    
    var syncMessagesTask: DispatchWorkItem? = nil
    var syncMessagesDate = Date()
    var newMessagesChatIds = [Int]()
    var syncing = false
    
    func finishRestoring() {
        self.syncing = false
        syncMessagesTask?.cancel()
        
        UserDefaults.Keys.messagesFetchPage.removeValue()
        API.sharedInstance.lastSeenMessagesDate = syncMessagesDate
    }
    
    func getRestoreProgress(
        currentPage: Int,
        newMessagesTotal: Int,
        itemsPerPage: Int
    ) -> Int {
        
        if (newMessagesTotal <= 0) {
            return -1
        }
        
        let pages = (newMessagesTotal <= itemsPerPage) ? 1 : ceil(Double(newMessagesTotal) / Double(itemsPerPage))
        let progress: Int = currentPage * 100 / Int(pages)

        return progress
    }
    
    func getExistingMessagesFor(
        ids: [Int]
    ) -> [Int: TransactionMessage] {
        var messagesMap: [Int: TransactionMessage] = [:]
        
        for existingMessage in TransactionMessage.getMessagesWith(ids: ids) {
            messagesMap[existingMessage.id] = existingMessage
        }
        
        return messagesMap
    }
    
    func addMessages(
        messages: [JSON],
        chatId: Int? = nil,
        completion: @escaping (Int, Int) -> ()
    ) {
        let ids: [Int] = messages.map({ $0["id"].intValue })
        let existingMessagesMap = getExistingMessagesFor(ids: ids)
        
        var newMessagesCount = 0
        
        for messageDictionary in messages {
            var existingMessage: TransactionMessage? = nil
            
            if let id = messageDictionary["id"].int {
                existingMessage = existingMessagesMap[id]
            }
            
            let (message, isNew) = TransactionMessage.insertMessage(
                m: messageDictionary,
                existingMessage: existingMessage
            )

            if let message = message {
                message.setPaymentInvoiceAsPaid()
                
                if isAddedRow(message: message, isNew: isNew, viewChatId: chatId) {
                    newMessagesCount = newMessagesCount + 1
                }
                
                if let chat = message.chat, !newMessagesChatIds.contains(chat.id) {
                    newMessagesChatIds.append(chat.id)
                }
            }

        }
        completion(newMessagesCount, messages.count)
    }
    
    func isAddedRow(
        message: TransactionMessage,
        isNew: Bool,
        viewChatId: Int?
    ) -> Bool {
        
        if TransactionMessage.typesToExcludeFromChat.contains(message.type) {
            return false
        }
        
        if viewChatId == nil {
            return true
        }
        
        if let messageChatId = message.chat?.id, let viewChatId = viewChatId {
            if (isNew || !message.seen) {
                return messageChatId == viewChatId
            }
        }
        return false
    }
    
}
