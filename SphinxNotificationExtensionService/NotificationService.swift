import UserNotifications
import CoreData
import UIKit

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var notificationsResultsController: NSFetchedResultsController<NotificationData>!
    var timestamp: Date? = nil
    
    override init() {
        super.init()
        
        observeRemoteChanges()
    }
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        bestAttemptContent?.title = "Sphinx"
        bestAttemptContent?.body = "You have new messages!"
        
        if let bestAttemptContent = bestAttemptContent, let userInfo = bestAttemptContent.userInfo as? [String: AnyObject] {
            
            let context = SharedPushNotificationContainerManager.shared.viewContext
                    
            let date = Date()
            self.timestamp = date
            
            let notificationData = NotificationData(context: context)
            notificationData.timestamp = date
            notificationData.userInfo = userInfo
            notificationData.title = nil
            notificationData.body = nil
                
            do {
                try context.save()
            } catch {
                print("Failed to save context in extension: \(error)")
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
            
            self.resetAfterSend()
        }
    }
    
    func observeRemoteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange(notification:)),
            name: .NSPersistentStoreRemoteChange,
            object: SharedPushNotificationContainerManager.shared.persistentContainer.persistentStoreCoordinator
        )
    }
    
    @objc func storeRemoteChange(notification: Notification) {
        guard let timestamp = self.timestamp else {
            return
        }
        
        let context = SharedPushNotificationContainerManager.shared.viewContext
        
        if let processedNotification = NotificationData.getLastProcessedNotificationWith(
            timestamp: timestamp,
            context: context
        ) {
            bestAttemptContent?.title = processedNotification.title ?? "Sphinx"
            bestAttemptContent?.body = processedNotification.body ?? ""

            // Call the content handler with the modified content
            if let bestAttemptContent = bestAttemptContent {
                contentHandler?(bestAttemptContent)
            }
            
            resetAfterSend()
        }
    }
    
    func resetAfterSend() {
        self.bestAttemptContent = nil
        self.contentHandler = nil
        self.deleteAllNotifications()
    }
    
    func deleteAllNotifications() {
        let context = SharedPushNotificationContainerManager.shared.viewContext
        let notifications = NotificationData.getAll(context: context)
        for notification in notifications {
            context.performAndWait {
                context.delete(notification)
            }
        }
        do {
            try context.save()
        } catch {
            print("Failed to delete notifications")
        }
    }
}
