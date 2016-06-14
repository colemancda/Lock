//
//  IndexRequestHandler.swift
//  CerraduraSpotlightIndex
//
//  Created by Alsey Coleman Miller on 6/13/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import CoreSpotlight
import SwiftFoundation
import CoreLock

final class IndexRequestHandler: CSIndexExtensionRequestHandler {

    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: () -> ()) {
        
        // Reindex all data with the provided index
        
        // fetch cache
        let cache = Store.shared.cache
        
        let items = cache.map { $0.toSearchableItem() }
        
        searchableIndex.indexSearchableItems(items) { (error) in
            
            print("Indexed all searchable items")
            
            if let error = error { print("\(error)") }
            
            acknowledgementHandler()
        }
    }

    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: () -> ()) {
        // Reindex any items with the given identifiers and the provided index
        
        let UUIDs = identifiers.map({ UUID(rawValue: $0)! })
        
        var cache = [LockCache]()
        
        for identifier in UUIDs {
            
            guard let lock = Store.shared[cache: identifier]
                else { continue }
            
            cache.append(lock)
        }
        
         let items = cache.map { $0.toSearchableItem() }
        
        searchableIndex.indexSearchableItems(items) { (error) in
            
            print("Reindexed \(identifiers.count) items")
            
            if let error = error { print("\(error)") }
            
            acknowledgementHandler()
        }
    }

}
