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
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [description]
        } else {
            fatalError("Failed to find app group URL")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("Persistent store loaded successfully")
            }
        })
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
}


