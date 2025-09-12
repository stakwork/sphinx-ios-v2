//
//  CoreDataManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 12/09/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class CoreDataManager {
    
    static let sharedManager = CoreDataManager()
    
    private init() {}
    
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "sphinx")
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // 🔑 Ensures that the `mainContext` is aware of any changes that were made
        // to the persistent container.
        //
        // For example, when we save a background context,
        // the persistent container is automatically informed of the changes that
        // were made. And since the `mainContext` is considered to be a child of
        // the persistent container, it will receive those updates -- merging
        // any changes, as the name suggests, automatically.
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    
    func saveContext() {
        CoreDataManager.sharedManager.persistentContainer.viewContext.saveContext()
    }
    
    func save(context: NSManagedObjectContext) {
        context.saveContext()
    }
    
    func getBackgroundContext() -> NSManagedObjectContext {
        let backgroundContext = CoreDataManager.sharedManager.persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.shouldDeleteInaccessibleFaults = true
        backgroundContext.automaticallyMergesChangesFromParent = true
        
        return backgroundContext
    }
    
    func clearCoreDataStore() {
        let context = CoreDataManager.sharedManager.persistentContainer.viewContext
        
        context.deleteAllObjects()
        do {
            try context.save()
        } catch {
            print("Error on deleting CoreData entities")
        }
    }
    
    func deleteExpiredInvites() {
        for contact in UserContact.getPendingContacts() {
            if let invite = contact.invite, !contact.isOwner, !contact.isConfirmed() && invite.isExpired() {
                invite.removeFromPaymentProcessed()
                deleteContactObjectsFor(contact)
            }
        }
        saveContext()
    }
    
    func deleteContactObjectsFor(_ contact: UserContact) {
        if let chat = contact.getChat() {
            for message in chat.getAllMessages(limit: nil, forceAllMsgs: true) {
                MediaLoader.clearMessageMediaCache(message: message)
                deleteObject(object: message)
            }
            chat.deleteColor()
            deleteObject(object: chat)
        }
        
        if let subscription = contact.getCurrentSubscription() {
            deleteObject(object: subscription)
        }
        
        if let invite = contact.invite {
            invite.removeFromPaymentProcessed()
        }
        contact.deleteColor()
        deleteObject(object: contact)        
        
        saveContext()
    }
    
    func deleteChatObjectsFor(_ chat: Chat) {
        if let messagesSet = chat.messages, let groupMessages = Array<Any>(messagesSet) as? [TransactionMessage] {
            for m in groupMessages {
                MediaLoader.clearMessageMediaCache(message: m)
                deleteObject(object: m)
            }
        }
        deleteObject(object: chat)
        saveContext()
    }
    
    func getObjectWith<T>(objectId: NSManagedObjectID) -> T? {
        let managedContext = persistentContainer.viewContext
        return managedContext.object(with:objectId) as? T
    }
    
    func getAllOfType<T>(
        entityName: String,
        sortDescriptors: [NSSortDescriptor]? = nil,
        context: NSManagedObjectContext? = nil
    ) -> [T] {
        let managedContext = context ?? persistentContainer.viewContext
        var objects:[T] = [T]()
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"\(entityName)")
        fetchRequest.sortDescriptors = sortDescriptors ?? [NSSortDescriptor(key: "id", ascending: false)]
        
        do {
            try objects = managedContext.fetch(fetchRequest) as! [T]
        } catch let error as NSError {
            print("Error: " + error.localizedDescription)
        }
        
        return objects
    }
    
    func getObjectOfTypeWith<T>(id: Int, entityName: String, context: NSManagedObjectContext? = nil) -> T? {
        let managedContext = context ?? persistentContainer.viewContext
        var objects:[T] = [T]()
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"\(entityName)")
        let predicate = NSPredicate(format: "id == %ld", id)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            try objects = managedContext.fetch(fetchRequest) as! [T]
        } catch let error as NSError {
            print("Error: " + error.localizedDescription)
        }
        
        if objects.count > 0 {
            return objects[0]
        }
        return nil
    }
    
    func getObjectsOfTypeWith<T>(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        entityName: String,
        fetchLimit: Int? = nil,
        context: NSManagedObjectContext? = nil
    ) -> [T] {
        let managedContext = context ?? persistentContainer.viewContext
        var objects:[T] = [T]()
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"\(entityName)")
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        
        if let fetchLimit = fetchLimit {
            fetchRequest.fetchLimit = fetchLimit
        }
        
        do {
            try objects = managedContext.fetch(fetchRequest) as! [T]
        } catch let error as NSError {
            print("Error: " + error.localizedDescription)
        }
        
        return objects
    }
    
    func getObjectsCountOfTypeWith(predicate: NSPredicate? = nil, entityName: String) -> Int {
        let managedContext = persistentContainer.viewContext
        var count:Int = 0
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"\(entityName)")
        if let predicate = predicate {
            fetchRequest.predicate = predicate
        }
        
        do {
            try count = managedContext.count(for: fetchRequest)
        } catch let error as NSError {
            print("Error: " + error.localizedDescription)
        }
        
        return count
    }
    
    func getObjectOfTypeWith<T>(
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor],
        entityName: String,
        managedContext: NSManagedObjectContext? = nil
    ) -> T? {
        let managedContext = managedContext ?? persistentContainer.viewContext
        var objects:[T] = [T]()
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"\(entityName)")
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchLimit = 1
        
        do {
            try objects = managedContext.fetch(fetchRequest) as! [T]
        } catch let error as NSError {
            print("Error: " + error.localizedDescription)
        }
        
        if objects.count > 0 {
            return objects[0]
        }
        return nil
    }
    
    func deleteObject(object: NSManagedObject, context: NSManagedObjectContext? = nil) {
        let managedContext = context ?? persistentContainer.viewContext
        managedContext.delete(object)
    }
}

extension NSManagedObjectContext {
    func saveContext() {
        if self.hasChanges {
            do {
                try self.save()
            } catch {
                let error = error as NSError
                print("Unresolved error \(error)")
                
                print("❌ Core Data Save Error:")
                print("   Domain: \(error.domain)")
                print("   Code: \(error.code)")
                print("   Description: \(error.localizedDescription)")
                
                // Check for validation errors
                if let validationErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    print("   Validation Errors:")
                    for validationError in validationErrors {
                        print("     - \(validationError.localizedDescription)")
                        print("     - Object: \(validationError.userInfo[NSValidationObjectErrorKey] ?? "Unknown")")
                        print("     - Property: \(validationError.userInfo[NSValidationKeyErrorKey] ?? "Unknown")")
                        print("     - Value: \(validationError.userInfo[NSValidationValueErrorKey] ?? "Unknown")")
                    }
                }
                
                // Check affected objects
                if let affectedObjects = error.userInfo[NSAffectedObjectsErrorKey] as? [NSManagedObject] {
                    print("   Affected Objects: \(affectedObjects.count)")
                    for object in affectedObjects {
                        if let message = object as? TransactionMessage {
                            debugTransactionMessage(message)
                            validateTransactionMessage(message)
                        }
                    }
                }
            }
        }
    }
    
    func validateTransactionMessage(_ message: TransactionMessage) {
        print("🔍 Validating TransactionMessage \(message.id)")
        
        // ✅ Correct way to use validateValue
        do {
            var idValue: AnyObject? = NSNumber(value: message.id)
            try message.validateValue(&idValue, forKey: "id")
            print("✅ ID valid: \(message.id)")
        } catch {
            print("❌ ID validation failed: \(error)")
        }
        
        do {
            var senderIdValue: AnyObject? = NSNumber(value: message.senderId)
            try message.validateValue(&senderIdValue, forKey: "senderId")
            print("✅ SenderId valid: \(message.senderId)")
        } catch {
            print("❌ SenderId validation failed: \(error)")
        }
        
        do {
            var receiverIdValue: AnyObject? = NSNumber(value: message.receiverId)
            try message.validateValue(&receiverIdValue, forKey: "receiverId")
            print("✅ ReceiverId valid: \(message.receiverId)")
        } catch {
            print("❌ ReceiverId validation failed: \(error)")
        }
        
        do {
            var messageContentValue: AnyObject? = message.messageContent as NSString?
            try message.validateValue(&messageContentValue, forKey: "messageContent")
            print("✅ MessageContent valid")
        } catch {
            print("❌ MessageContent validation failed: \(error)")
        }
        
        do {
            var uuidValue: AnyObject? = message.uuid as NSString?
            try message.validateValue(&uuidValue, forKey: "uuid")
            print("✅ UUID valid: \(message.uuid ?? "nil")")
        } catch {
            print("❌ UUID validation failed: \(error)")
        }
        
        do {
            var chatValue: AnyObject? = message.chat
            try message.validateValue(&chatValue, forKey: "chat")
            print("✅ Chat relationship valid")
        } catch {
            print("❌ Chat relationship validation failed: \(error)")
        }
    }
    
    func debugTransactionMessage(_ message: TransactionMessage) {
        print("🔍 Debugging TransactionMessage:")
        print("   ID: \(message.id)")
        print("   Chat: \(String(describing: message.chat))")
        print("   Sender ID: \(message.senderId)")
        print("   Receiver ID: \(message.receiverId)")
        print("   Message Content: \(String(describing: message.messageContent))")
        print("   UUID: \(String(describing: message.uuid))")
        print("   Date: \(String(describing: message.date))")
        print("   Status: \(message.status)")
        print("   Type: \(message.type)")
        
        // Check for nil required fields
        if message.chat == nil {
            print("❌ Chat is nil!")
        }
        if message.uuid == nil {
            print("❌ UUID is nil!")
        }
        if message.date == nil {
            print("❌ Date is nil!")
        }
    }
}
