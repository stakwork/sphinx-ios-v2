//
//  NotificationData+CoreDataProperties.swift
//  sphinx
//
//  Created by James Carucci on 8/19/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import CoreData

extension NotificationData {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NotificationData> {
        return NSFetchRequest<NotificationData>(entityName: "NotificationData")
    }

    @NSManaged public var title: String?
    @NSManaged public var body: String?
    @NSManaged public var userInfo: [String: Any]?
    @NSManaged public var timestamp: Date?
    
    // Add other attributes if there are any more in your Core Data model
}

