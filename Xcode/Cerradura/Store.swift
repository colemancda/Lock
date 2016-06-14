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
import KeychainAccess

/// Store for saving and retrieving lock keys.
final class Store {
    
    static let shared = Store()
    
    /// The managed object context used for caching.
    let managedObjectContext: NSManagedObjectContext
    
    /// A convenience variable for the managed object model.
    let managedObjectModel: NSManagedObjectModel
    
    private let keychain = Keychain(accessGroup: AppGroup)
    
    private init() {
        
        self.managedObjectModel = LoadManagedObjectModel()
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.managedObjectContext.name = "\(self.dynamicType) Managed Object Context"
        self.managedObjectContext.undoManager = nil
        self.managedObjectContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
    }
    
    /// Remove the specified key / lock pair from the database, along with its cached info.
    func remove(_ UUID: SwiftFoundation.UUID) {
        
        // remove from CoreData
        let entity = managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName[LockCache.entityName]!
        
        guard let managedObject = try! managedObjectContext.find(entity: entity, resourceID: UUID.rawValue, identifierProperty: LockCache.Property.identifier.rawValue)
            else { fatalError("Tried to remove nonexistent lock \(UUID)") }
        
        managedObjectContext.delete(managedObject)
        
        try! managedObjectContext.save()
        
        // remove from Keychain
        try! keychain.remove(key: UUID.rawValue)
    }
    
    /// Get the key data and cached lock info for the specified lock.
    subscript (UUID: SwiftFoundation.UUID) -> Lock? {
        
        get {
            
            let entity = managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName[LockCache.entityName]!
            
            guard let keyData = try! keychain.getData(key: UUID.rawValue),
                let key = KeyData(data: Data(foundation: keyData)),
                let managedObject = try! managedObjectContext.find(entity: entity, resourceID: UUID.rawValue, identifierProperty: LockCache.Property.identifier.rawValue)
                else { return nil }
            
            let lockCache = LockCache(managedObject: managedObject)
            
            return Lock(keyData: key, lockCache: lockCache)
        }
        
        set {
            
            guard let lock = newValue
                else { remove(UUID); return }
            
            let lockCache = LockCache(lock)
            
            let _ = try! lockCache.save(context: managedObjectContext)
            
            try! keychain.set(value: lock.key.data.data.toFoundation(), key: UUID.rawValue)
        }
    }
    
    /// Subscript to get key.
    subscript (key UUID:  SwiftFoundation.UUID) -> KeyData? {
        
        guard let data = try! keychain.getData(key: UUID.rawValue)
            else { return nil }
        
        return KeyData(data: Data(foundation: data))
    }
    
    subscript (cache UUID: SwiftFoundation.UUID) -> LockCache? {
        
        let entity = managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName[LockCache.entityName]!
        
        guard let managedObject = try! managedObjectContext.find(entity: entity, resourceID: UUID.rawValue, identifierProperty: LockCache.Property.identifier.rawValue)
            else { return nil }
        
        let lockCache = LockCache(managedObject: managedObject)
        
        return lockCache
    }

    /// Returns the entire cache.
    var cache: [LockCache] {
        
        let entity = managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName[LockCache.entityName]!
        
        let fetchRequest = NSFetchRequest(entityName: entity.name!)
        
        fetchRequest.includesSubentities = false
        
        fetchRequest.returnsObjectsAsFaults = false
        
        fetchRequest.sortDescriptors = [NSSortDescriptor.init(key: LockCache.Property.identifier.rawValue, ascending: true)]
        
        var cache: [LockCache]!
        
        NSOperationQueue.main().addOperations([NSBlockOperation(block: {
            
            cache = try! self.managedObjectContext.fetch(fetchRequest)
            
        })], waitUntilFinished: true)
        
        return cache
    }
}

// MARK: - Supporting Types

struct Lock {
    
    let identifier: UUID
    
    var name: String
    
    let model: Model
    
    let version: UInt64
    
    let key: Key
    
    private init(keyData: KeyData, lockCache: LockCache) {
        
        self.key = Key(data: keyData, permission: lockCache.permission)
        self.identifier = lockCache.identifier
        self.name = lockCache.name
        self.version = lockCache.version
        self.model = lockCache.model
    }
    
    init(identifier: UUID, name: String, model: Model, version: UInt64, key: Key) {
        
        self.identifier = identifier
        self.name = name
        self.model = model
        self.version = version
        self.key = key
    }
}

private extension LockCache {
    
    init(_ lock: Lock) {
        
        self.identifier = lock.identifier
        self.name = lock.name
        self.model = lock.model
        self.version = lock.version
        self.permission = lock.key.permission
    }
}

// MARK: - Persistance

private func LoadManagedObjectModel() -> NSManagedObjectModel {
    
    let bundle = NSBundle(for: Store.self)
    
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
    
    if NSFileManager.default().fileExists(atPath: url.path!) {
        
        // delete file
        
        try NSFileManager.default().removeItem(at: url)
    }
    
    if let store = PersistentStore {
        
        guard let psc = Store.shared.managedObjectContext.persistentStoreCoordinator
            else { fatalError() }
        
        try psc.remove(store)
        
        PersistentStore = nil
    }
}

let SQLiteStoreFileURL: NSURL = {
    
    guard let cacheURL = NSFileManager.default().containerURLForSecurityApplicationGroupIdentifier(AppGroup)
        else { fatalError("Could not get URL for Core Data cache: App Group Error") }
    
    let fileURL = cacheURL.appendingPathComponent("cache.sqlite")
    
    return fileURL
}()
