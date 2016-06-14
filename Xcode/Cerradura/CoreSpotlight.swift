//
//  CoreSpotlight.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 6/13/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock
import CoreSpotlight
import CoreData
import MobileCoreServices
import UIKit

@available(iOS 9.0, *)
extension LockCache {
    
    static var itemContentType: String { return kUTTypeText as String }
    
    func toSearchableItem() -> CSSearchableItem {
        
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: self.dynamicType.itemContentType)
        
        let permissionImage: UIImage
        
        let permissionText: String
        
        switch permission {
            
        case .owner:
            
            permissionImage = UIImage(named: "permissionBadgeOwner")!
            
            permissionText = "Owner"
            
        case .admin:
            
            permissionImage = UIImage(named: "permissionBadgeAdmin")!
            
            permissionText = "Admin"
            
        case .anytime:
            
            permissionImage = UIImage(named: "permissionBadgeAnytime")!
            
            permissionText = "Anytime"
            
        case let .scheduled(schedule):
            
            permissionImage = UIImage(named: "permissionBadgeScheduled")!
            
            permissionText = "Scheduled" // FIXME
        }
        
        attributeSet.displayName = name
        attributeSet.contentDescription = permissionText
        attributeSet.thumbnailData = UIImagePNGRepresentation(permissionImage)!
        
        return CSSearchableItem(uniqueIdentifier: identifier.rawValue, domainIdentifier: nil, attributeSet: attributeSet)
    }
}

@available(iOS 9.0, *)
func UpdateSpotlight(_ index: CSSearchableIndex = CSSearchableIndex.default(), completionHandler: ((NSError?) -> Void)? = nil) {
    
    print(kUTTypeText as String)
    
    index.deleteAllSearchableItems { (deleteError) in
        
        if let error = deleteError {
            
            completionHandler?(error)
            return
        }
        
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.name = "Cerradura Spotlight Managed Object Context"
        managedObjectContext.undoManager = nil
        managedObjectContext.persistentStoreCoordinator = Store.shared.managedObjectContext.persistentStoreCoordinator!
        
        let entity = managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName[LockCache.entityName]!
        let fetchRequest = NSFetchRequest(entityName: entity.name!)
        fetchRequest.includesSubentities = false
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor.init(key: LockCache.Property.identifier.rawValue, ascending: true)]
        
        managedObjectContext.perform {
            
            let cache: [LockCache] = try! managedObjectContext.fetch(fetchRequest)
            
            let items = cache.map { $0.toSearchableItem() }
            
            index.indexSearchableItems(items, completionHandler: completionHandler)
        }
    }
}
