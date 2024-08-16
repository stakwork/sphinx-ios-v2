import UserNotifications
import UIKit

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override init() {
        super.init()
        // Add a simple log to confirm initialization
        print("NotificationService initialized!")

    }

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        print("NotificationService: Received notification")
        print("Notification content: \(request.content)")
        
//        PushNotificationProcessManager.shared.sharedFunctionality()
        
        if let bestAttemptContent = bestAttemptContent {
            // Perform your computations here
            bestAttemptContent.title = "The Times 03/Jan/2009 [Modified]"
            bestAttemptContent.body = "CHANCELLOR ON BRINK  [Modified]"
            bestAttemptContent.userInfo["processedData"] = "abc123"
//            if let encryptedChild = getEncryptedIndexFrom(notification: bestAttemptContent.userInfo) {
//                // Decrypt or process the encryptedChild
//                let processedData = processEncryptedChild(encryptedChild)
//                
//                // Modify the notification content
//                bestAttemptContent.title = "CHANCELLOR ON BRINK [Modified]"
//                bestAttemptContent.body = "You have a new message"
//                bestAttemptContent.userInfo["processedData"] = processedData
//            }
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func getEncryptedIndexFrom(notification: [AnyHashable: Any]) -> String? {
        if let aps = notification["aps"] as? [String: Any],
           let customData = aps["custom_data"] as? [String: Any],
           let child = customData["child"] as? String {
            return child
        }
        return nil
    }
    
    private func processEncryptedChild(_ encryptedChild: String) -> String {
        // Implement your decryption or processing logic here
        // This is just a placeholder implementation
        return "Processed: \(encryptedChild)"
    }
}
