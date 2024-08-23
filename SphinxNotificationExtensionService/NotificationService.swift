import UserNotifications
import CoreData
import UIKit

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    let kSharedGroupName = "group.com.gl.sphinx.v2"
    let kPushTokenKey = "pushToken"
    
    var pushToken: String? {
        get {
            if let pushToken: String = UserDefaults(suiteName: kSharedGroupName)?.string(forKey: kPushTokenKey) {
                return pushToken
            }
            return nil
        }
    }
    
    override init() {
        super.init()
    }
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        bestAttemptContent?.title = "Sphinx"
        bestAttemptContent?.body = "You have new messages"
        
        var decryptedChildIndex: UInt64? = nil
        
        if
            let pushToken = pushToken,
            let userInfo = bestAttemptContent?.userInfo as? [String:AnyObject],
            let child = getEncryptedIndexFrom(notification: userInfo)
        {
            do {
                decryptedChildIndex = try decryptChildIndex(
                    encryptedChild: child,
                    pushKey: pushToken
                )
            } catch {
                print("error decrypting child index")
            }
        }
        
        if let decryptedChildIndex = decryptedChildIndex {
            let shareableUserDefaults = UserDefaults(suiteName: kSharedGroupName)
            if let contactName = shareableUserDefaults?.string(forKey: "contact-\(decryptedChildIndex)") {
                bestAttemptContent?.body = "You have new messages from \(contactName)"
            } else if let tribeName = shareableUserDefaults?.string(forKey: "tribe-\(decryptedChildIndex)") {
                bestAttemptContent?.body = "You have new messages in \(tribeName)"
            }
        }
        
        if let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
            self.resetAfterSend()
        }
    }
    
    func getEncryptedIndexFrom(
        notification: [String: AnyObject]?
    ) -> String? {
        if
            let notification = notification,
            let customData = notification["custom_data"] as? [String: AnyObject]
        {
            if let chatId = customData["child"] as? String {
                return chatId
            }
        }
        return nil
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
            
            self.resetAfterSend()
        }
    }
    
    func resetAfterSend() {
        self.bestAttemptContent = nil
        self.contentHandler = nil
    }
}
