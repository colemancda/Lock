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
        
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: Self.itemContentType)
        
        let permissionImage: UIImage
        
        let permissionText: String
        
        switch permission {
            
        case .owner:
            
            permissionImage = #imageLiteral(resourceName: "permissionBadgeOwner")
            
            permissionText = "Owner"
            
        case .admin:
            
            permissionImage = #imageLiteral(resourceName: "permissionBadgeAdmin")
            
            permissionText = "Admin"
            
        case .anytime:
            
            permissionImage = #imageLiteral(resourceName: "permissionBadgeAnytime")
            
            permissionText = "Anytime"
            
        case .scheduled:
            
            permissionImage = #imageLiteral(resourceName: "permissionBadgeScheduled")
            
            permissionText = "Scheduled" // FIXME
        }
        
        attributeSet.displayName = name
        attributeSet.contentDescription = permissionText
        attributeSet.thumbnailData = UIImagePNGRepresentation(permissionImage)!
        
        return CSSearchableItem(uniqueIdentifier: identifier.rawValue, domainIdentifier: nil, attributeSet: attributeSet)
    }
}

@available(iOS 9.0, *)
func UpdateSpotlight(_ index: CSSearchableIndex = CSSearchableIndex.default(), completionHandler: ((NSError?) -> ())? = nil) {
    
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
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity.name!)
        fetchRequest.includesSubentities = false
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [SortDescriptor(key: LockCache.Property.identifier.rawValue, ascending: true)]
        
        managedObjectContext.perform {
            
            let cache: [LockCache] = try! managedObjectContext.fetch(fetchRequest)
            
            let items = cache.map { $0.toSearchableItem() }
            
            index.indexSearchableItems(items, completionHandler: completionHandler)
        }
    }
}

/// Updates the CoreSpotlight index from CoreData changes.
@available(iOS 9.0, *)
final class SpotlightController: NSObject, NSFetchedResultsControllerDelegate {
    
    static let shared = SpotlightController()
    
    let spotlightIndex = CSSearchableIndex.default()
    
    var log: ((String) -> ())?
    
    private lazy var fetchedResultsController: NSFetchedResultsController<NSManagedObject> = {
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: LockCache.entityName)
        
        fetchRequest.sortDescriptors = [SortDescriptor(key: LockCache.Property.name.rawValue, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: Store.shared.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    private override init() {
        
        super.init()
    }
    
    // MARK: - Methods
    
    func startObserving() throws {
        
        try self.fetchedResultsController.performFetch()
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    @objc private func controller(_ controller: NSFetchedResultsController<NSManagedObject>, didChange anObject: AnyObject, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        let lockCache = LockCache(managedObject: anObject as! NSManagedObject)
        
        switch type {
            
        case .move: break // ignore
            
        case .insert, .update:
            
            let item = lockCache.toSearchableItem()
            
            spotlightIndex.indexSearchableItems([item])  { (error) in
                
                if let error = error {
                    
                    self.log?("Error adding lock \(lockCache.identifier) to SpotLight index: \(error)")
                    
                } else {
                    
                    self.log?("Added lock \(lockCache.identifier) to SpotLight index")
                }
            }
            
        case .delete:
            
            spotlightIndex.deleteSearchableItems(withIdentifiers: [lockCache.identifier.rawValue]) { (error) in
                
                if let error = error {
                    
                    self.log?("Error Deleting lock \(lockCache.identifier) from SpotLight index: \(error)")
                    
                } else {
                    
                    self.log?("Deleted lock \(lockCache.identifier) from SpotLight index")
                }
            }
        }
    }
}
