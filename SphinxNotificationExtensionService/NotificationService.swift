import UserNotifications
import CoreData

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    let coreDataManager = SharedPushNotificationContainerManager.shared
    
    var persistentContainer: NSPersistentContainer?

        override init() {
            super.init()
            initializeCoreDataStack()
        }

        func initializeCoreDataStack() {
            let container = NSPersistentContainer(name: "NotificationData") // Use your actual Core Data model name
            container.loadPersistentStores { storeDescription, error in
                if let error = error {
                    fatalError("Unresolved error \(error)")
                }
            }
            self.persistentContainer = container
        }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        print("NotificationService: Received notification")
        
        if let bestAttemptContent = bestAttemptContent,
           let _ = bestAttemptContent.userInfo as? [String: AnyObject] {
            
            // Save the notification data to CoreData
            let context = coreDataManager.context
            if let notificationData = NSEntityDescription.insertNewObject(forEntityName: "NotificationData", into: context) as? NotificationData{
                notificationData.title = bestAttemptContent.title
                notificationData.body = bestAttemptContent.body
                notificationData.timestamp = Date()
                //notificationData.userInfo = userInfo
                
                coreDataManager.saveContext()
                
                // Start monitoring for the processing result using file coordination
            }
        }
    }
    
    func createAndMonitorFile() {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gl.sphinx.v2") else { return }
        let fileURL = appGroupURL.appendingPathComponent("notification_trigger.txt")
        
        // Ensure the file exists before monitoring
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        
        // Start monitoring the file
        observeFileChanges(at: fileURL)
    }
    
    func observeFileChanges(at fileURL: URL) {
        // Monitor the file for changes
        let fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: DispatchQueue.global())
        
        source.setEventHandler {
            // File has changed, fetch the updated data
            self.checkForProcessingResult()
        }
        
        source.resume()
    }
    
    func checkForProcessingResult() {
        let context = coreDataManager.context
        let fetchRequest: NSFetchRequest<NotificationData> = NotificationData.fetchRequest()
        
        // Use appropriate predicate to fetch the correct data
        do{
            if let result = try context.fetch(fetchRequest).last {
                // Modify the notification with the processed data
               
                bestAttemptContent?.title = result.title ?? ""
                bestAttemptContent?.body = result.body ?? ""

                // Call the content handler with the modified content
                if let bestAttemptContent = bestAttemptContent {
                    contentHandler?(bestAttemptContent)
                }
            }
        }
        catch{
            print("")
        }
        
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
