//
//  Store.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/22/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock
import CoreData

/// Store for saving and retrieving lock keys.
final class Store {
    
    static let shared = Store()
    
    /// The managed object context used for caching.
    let managedObjectContext: NSManagedObjectContext
    
    /// A convenience variable for the managed object model.
    let managedObjectModel: NSManagedObjectModel
    
    private init() {
        
        self.managedObjectModel = LoadManagedObjectModel()
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.managedObjectContext.name = "\(self.dynamicType) Managed Object Context"
        self.managedObjectContext.undoManager = nil
        self.managedObjectContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        
        
    }
    
    /// Add a new key / lock pair to the database, along with its cached info.
    func add(key: Key, lock: (UUID: UUID, name: String, model: Model, version: UInt64)) {
        
        
    }
    
    func update(name: String) {
        
        
    }
    
    /// Remove the specified key / lock pair from the database, along with its cached info.
    func remove(_ UUID: SwiftFoundation.UUID) {
        
        
    }
    
    /// Get the cached lock info.
    subscript (lock UUID: SwiftFoundation.UUID) -> Lock {
        
        
    }
    
    /// Get the key data for the specified lock.
    subscript (key UUID: SwiftFoundation.UUID) -> KeyData {
        
        
    }
}

private func LoadManagedObjectModel() -> NSManagedObjectModel {
    
    guard let bundle = NSBundle(identifier: "com.colemancda.Cerradura")
        else { fatalError("Could not load Cerradura bundle") }
    
    let modelURL = bundle.urlForResource("Model", withExtension: "momd")!
    
    guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Could not load managed object model") }
    
    return managedObjectModel
}

private var PersistentStore: NSPersistentStore?

/// Loads the persistent store.
func LoadPersistentStore() throws {
    
    let url = SQLiteStoreFileURL
    
    // load SQLite store
    
    PersistentStore = try Store.shared.managedObjectContext.persistentStoreCoordinator!.addPersistentStore(ofType:NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
}

func RemovePersistentStore() throws {
    
    let url = SQLiteStoreFileURL
    
    if NSFileManager.defaultManager().fileExists(atPath: url.path!) {
        
        // delete file
        
        try NSFileManager.defaultManager().removeItem(at: url)
    }
    
    if let store = PersistentStore {
        
        guard let psc = Store.shared.managedObjectContext.persistentStoreCoordinator
            else { fatalError() }
        
        try psc.remove(store)
        
        PersistentStore = nil
    }
}

let SQLiteStoreFileURL: NSURL = {
    
    let cacheURL = try! NSFileManager.defaultManager().urlForDirectory(NSSearchPathDirectory.cachesDirectory,
                                                                       in: NSSearchPathDomainMask.userDomainMask,
                                                                       appropriateFor: nil,
                                                                       create: false)
    
    let fileURL = cacheURL.appendingPathComponent("cache.sqlite")
    
    return fileURL
}()
