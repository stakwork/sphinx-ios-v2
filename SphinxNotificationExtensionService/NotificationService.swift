import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Perform your computations here
            if let encryptedChild = getEncryptedIndexFrom(notification: bestAttemptContent.userInfo) {
                // Decrypt or process the encryptedChild
                let processedData = processEncryptedChild(encryptedChild)
                
                // Modify the notification content
                bestAttemptContent.title = "CHANCELLOR ON BRINK"
                bestAttemptContent.body = "You have a new message"
                bestAttemptContent.userInfo["processedData"] = processedData
            }
            
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
