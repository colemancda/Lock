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

@available(iOS 9.0, *)
extension LockCache {
    
    static var itemContentType: String { return kUTTypeText as String }
    
    func toSearchableItem() -> CSSearchableItem {
        
        let item = CSSearchableItem()
        
        item.uniqueIdentifier = identifier.rawValue
        
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: self.dynamicType.itemContentType)
        
        attributeSet.displayName = name
        
        return item
    }
}

@available(iOS 9.0, *)
func UpdateSpotlight(_ index: CSSearchableIndex = CSSearchableIndex.default(), completionHandler: ((NSError?) -> Void)? = nil) {
    
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
