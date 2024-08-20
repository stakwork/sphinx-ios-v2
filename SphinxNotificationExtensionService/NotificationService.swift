import UserNotifications
import CoreData

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    let sharedPushNotificationContainerManager = SharedPushNotificationContainerManager.shared
    
    var timer: Timer?
    var startTime: Date?
    
    override init() {
        super.init()
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        print("NotificationService: Received notification")
        
        if let bestAttemptContent = bestAttemptContent,
           let userInfo = bestAttemptContent.userInfo as? [String: AnyObject] {
            
            // Save the notification data to CoreData
            let context = sharedPushNotificationContainerManager.context
            print("Setting up insertNewObject in NotificationService")
            if let notificationData = NSEntityDescription.insertNewObject(forEntityName: "NotificationData", into: context) as? NotificationData {
                print("Done setting up insertNewObject in NotificationService")
                notificationData.title = bestAttemptContent.title
                notificationData.body = bestAttemptContent.body
                notificationData.timestamp = Date()
                notificationData.userInfo = userInfo
                
                sharedPushNotificationContainerManager.saveContext()
                
                // Start a timer to periodically check for any new data added after this point
                startTimer()
            }
        }
    }
    
    func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(checkForNewNotifications), userInfo: nil, repeats: true)
    }
    
    @objc func checkForNewNotifications() {
        guard let startTime = startTime else { return }
        
        let context = sharedPushNotificationContainerManager.context
        let fetchRequest: NSFetchRequest<NotificationData> = NotificationData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "timestamp > %@", startTime as NSDate)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let latestNotification = results.last {
                print("New notification found: \(latestNotification.title ?? "")")
                
                // Update the notification content with the latest data
                bestAttemptContent?.title = latestNotification.title ?? ""
                bestAttemptContent?.body = latestNotification.body ?? ""
                
                // Call the content handler with the modified content
                if let bestAttemptContent = bestAttemptContent {
                    contentHandler?(bestAttemptContent)
                }
                
                // Invalidate the timer since we found the data we were looking for
                timer?.invalidate()
                timer = nil
            }
        } catch let error {
            print("Error fetching new notifications: \(error)")
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Invalidate the timer if the extension is about to expire
        timer?.invalidate()
        
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
