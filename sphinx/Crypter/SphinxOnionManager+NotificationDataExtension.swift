//
//  SphinxOnionManager+NotificationDataExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 21/08/2024.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit
import CoreData

extension SphinxOnionManager : NSFetchedResultsControllerDelegate {    
    func observeRemoteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange(notification:)),
            name: .NSPersistentStoreRemoteChange,
            object: SharedPushNotificationContainerManager.shared.persistentContainer.persistentStoreCoordinator
        )
    }
    
    @objc func storeRemoteChange(notification: Notification) {
        let context = SharedPushNotificationContainerManager.shared.viewContext
        if let lastNotification = NotificationData.getLastReceivedNotification(context: context) {
            lastNotification.title = "Sphinx"
            
            if 
                let nd = lastNotification.userInfo as? [String:AnyObject],
                let chat = self.mapNotificationToChat(notificationUserInfo: nd)
            {
                let chatName = chat.0.getName()
                
                if chat.0.isPublicGroup() {
                    lastNotification.body = "You have new messages in \(chatName) - \(chat.1)"
                } else {
                    lastNotification.body = "You have new messages from \(chatName) - \(chat.1)"
                }
            } else {
                lastNotification.body = "You have new messages."
            }
            context.saveContext()
        }
    }
    
    func mapNotificationToChat(notificationUserInfo : [String: AnyObject]) -> (Chat, String)? {
        if let encryptedChild = getEncryptedIndexFrom(notification: notificationUserInfo),
           let chat = findChatForNotification(child: encryptedChild)
        {
            return (chat, encryptedChild)
        }
        
        return nil
    }
    
    func getEncryptedIndexFrom(
        notification: [String: AnyObject]?
    ) -> String? {
        if
            let notification = notification,
            let aps = notification["aps"] as? [String: AnyObject],
            let customData = aps["custom_data"] as? [String: AnyObject]
        {
            if let chatId = customData["child"] as? String {
                return chatId
            }
        }
        return nil
    }
}
