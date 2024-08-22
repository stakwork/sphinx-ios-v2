//
//  NotificationData.swift
//  sphinx
//
//  Created by James Carucci on 8/19/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import CoreData

@objc(NotificationData)
public class NotificationData: NSManagedObject {
    
    static func getAllFetchRequest() -> NSFetchRequest<NotificationData> {
        let fetchRequest = fetchRequest()
        return fetchRequest
    }
    
    static func getLastNotificationFetchRequest() -> NSFetchRequest<NotificationData> {
        let fetchRequest = fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == nil AND body == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        return fetchRequest
    }
    
    static func getProcessedNotificationWith(timestamp: Date) -> NSFetchRequest<NotificationData> {
        let fetchRequest = fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND title != nil AND body != nil", timestamp as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        return fetchRequest
    }
    
    static func getLastReceivedNotification(context: NSManagedObjectContext) -> NotificationData? {
        let fetchRequest = getLastNotificationFetchRequest()
        do {
            let notifications: [NotificationData] = try context.fetch(fetchRequest)
            if let lastNotification = notifications.first {
                return lastNotification
            }
        } catch let error {
            print(error)
        }
        
        return nil
    }
    
    static func getLastProcessedNotificationWith(
        timestamp: Date,
        context: NSManagedObjectContext
    ) -> NotificationData? {
        let fetchRequest = getProcessedNotificationWith(timestamp: timestamp)
        do {
            let notifications: [NotificationData] = try context.fetch(fetchRequest)
            if let lastNotification = notifications.first {
                return lastNotification
            }
        } catch let error {
            print(error)
        }
        
        return nil
    }
    
    static func getAll(context: NSManagedObjectContext) -> [NotificationData] {
        let fetchRequest = getAllFetchRequest()
        do {
            let notifications: [NotificationData] = try context.fetch(fetchRequest)
            return notifications
        } catch let error {
            print(error)
        }
        return []
    }
}

