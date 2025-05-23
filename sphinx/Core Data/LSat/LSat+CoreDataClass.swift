//
//  LSat+CoreDataClass.swift
//  sphinx
//
//  Created by Tomas Timinskas on 22/07/2024.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

@objc(LSat)
public class LSat: NSManagedObject {
    
    enum LSatStatus: Int {
        case expired = 0
        case active = 1
        
        public init(fromRawValue: Int){
            self = LSatStatus(rawValue: fromRawValue) ?? .active
        }
    }
    
    public static func getAllLSat(context: NSManagedObjectContext) -> [LSat] {
        let fetchRequest = NSFetchRequest<LSat>(entityName: "LSat")
        
        do {
            let LSats = try context.fetch(fetchRequest)
            return LSats
        } catch let error as NSError {
            print("Error fetching servers: \(error.localizedDescription)")
            return []
        }
    }
    
    static func getLSatWith(
        identifier: String,
        managedContext: NSManagedObjectContext? = nil
    ) -> LSat? {
        let predicate = NSPredicate(format: "identifier == %@", identifier)
        
        let LSat: LSat? = CoreDataManager.sharedManager.getObjectOfTypeWith(
            predicate: predicate,
            sortDescriptors: [],
            entityName: "LSat",
            managedContext: managedContext
        )
        
        return LSat
    }
    
    static func getActiveLSat(
        issuer: String? = nil,
        managedContext: NSManagedObjectContext? = nil
    ) -> LSat? {
        var predicate: NSPredicate!
        
        if let issuer = issuer {
            predicate = NSPredicate(format: "issuer == %@ AND status = %d", issuer, LSatStatus.active.rawValue)
        } else {
            predicate = NSPredicate(format: "status = %d", LSatStatus.active.rawValue)
        }
        
        let LSat: LSat? = CoreDataManager.sharedManager.getObjectOfTypeWith(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            entityName: "LSat",
            managedContext: managedContext
        )
        
        return LSat
    }
    
    static func saveObjectFrom(
        lsatIP: LSatInProgress
    ) {
        
        let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext
        
        let lsat = LSat(context: managedContext) as LSat
        lsat.paymentRequest = lsatIP.paymentRequest
        lsat.macaroon = lsatIP.macaroon
        lsat.issuer = lsatIP.issuer
        lsat.identifier = lsatIP.identifier!
        lsat.preimage = lsatIP.preimage!
        lsat.status = LSatStatus.active.rawValue
        lsat.createdAt = Date()
        
        managedContext.saveContext()
    }
    
}
