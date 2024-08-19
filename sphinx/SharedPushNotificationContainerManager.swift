//
//  PushNotificationProcessManager.swift
//  sphinx
//
//  Created by James Carucci on 8/16/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import CoreData

//MARK: creates a shared store that can communicate between the SphinxNotificationExtensionService target and the main Sphinx application
class SharedPushNotificationContainerManager {

    static let shared = SharedPushNotificationContainerManager()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "sphinx")
        
        // Use the App Group's container for the shared store
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gl.sphinx.v2") {
            let storeURL = appGroupURL.appendingPathComponent("NotificationData.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}


