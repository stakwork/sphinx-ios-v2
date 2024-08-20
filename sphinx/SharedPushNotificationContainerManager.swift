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
        print("Initializing persistent container")
        let container = NSPersistentContainer(name: "sphinx")
        
        // Use the App Group's container for the shared store
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gl.sphinx.v2") {
            let storeURL = appGroupURL.appendingPathComponent("NotificationData.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
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

    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("Successfully saved context!")
                fetchAndPrintAllNotificationData()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func fetchAndPrintAllNotificationData() {
        let fetchRequest: NSFetchRequest<NotificationData> = NotificationData.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            print("Fetched \(results.count) NotificationData entries:")
            for data in results {
                print("Title: \(data.title ?? "No Title"), Body: \(data.body ?? "No Body"), Timestamp: \(data.timestamp ?? Date()), UserInfo: \(String(describing: data.userInfo))")
            }
        } catch {
            print("Failed to fetch NotificationData: \(error)")
        }
    }
    
    func printAllNotificationData() {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<NotificationData> = NotificationData.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            print("Fetched \(results.count) NotificationData entries:")
            for notificationData in results {
                print("Title: \(notificationData.title ?? "No Title"), Body: \(notificationData.body ?? "No Body"), Timestamp: \(notificationData.timestamp ?? Date()), UserInfo: \(notificationData.userInfo?.description ?? "nil")")
            }
        } catch let error {
            print("Error fetching NotificationData: \(error)")
        }
    }
}


