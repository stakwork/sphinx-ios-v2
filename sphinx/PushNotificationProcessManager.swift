//
//  PushNotificationProcessManager.swift
//  sphinx
//
//  Created by James Carucci on 8/16/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation

class PushNotificationProcessManager {
    // Static instance for singleton
    static let shared = PushNotificationProcessManager()

    // Private initializer to prevent instantiation
    private init() {}

    // Example method to be shared
    func mapNotificationToChat(notificationUserInfo : [String: AnyObject])->Chat? {
        // Your shared logic here
        if let encryptedChild = getEncryptedIndexFrom(notification: notificationUserInfo),
           let chat = SphinxOnionManager.sharedInstance.findChatForNotification(child: encryptedChild)
        {
            return chat
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
