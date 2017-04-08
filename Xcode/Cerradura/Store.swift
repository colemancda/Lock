//
//  Store.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/22/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import CoreLock
import CoreData
import KeychainAccess

/// Store for saving and retrieving lock keys.
final class Store {
    
    // MARK: - Singleton
    
    static let shared = Store()
    
    // MARK: - Properties
    
    /// The managed object context used for caching.
    let managedObjectContext: NSManagedObjectContext
    
    /// A convenience variable for the managed object model.
    let managedObjectModel: NSManagedObjectModel
    
    let keychain = Keychain(accessGroup: AppGroup)
    
    // MARK: - Private Properties
    
    private lazy var lockCacheEntity: NSEntityDescription = self.managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName[LockCache.entityName]!
    
    // MARK: - Initialization
    
    private init() {
        
        self.managedObjectModel = LoadManagedObjectModel()
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.managedObjectContext.name = "\(type(of: self)) Managed Object Context"
        self.managedObjectContext.undoManager = nil
        self.managedObjectContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
    }
    
    // MARK: - Methods
    
    /// Remove the specified key / lock pair from the database, along with its cached info.
    func remove(_ identifier: UUID) {
        
        // remove from CoreData
        guard let managedObject = try! managedObjectContext.find(entity: lockCacheEntity, resourceID: identifier.rawValue, identifierProperty: LockCache.Property.identifier.rawValue)
            else { fatalError("Tried to remove nonexistent lock \(identifier)") }
        
        managedObjectContext.delete(managedObject)
        
        try! managedObjectContext.save()
        
        // remove from Keychain
        try! keychain.remove(identifier.rawValue)
    }
    
    var locks: [LockCache] {
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: LockCache.entityName)
        fetchRequest.includesSubentities = false
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: LockCache.Property.identifier.rawValue, ascending: true)]
        
        let results = try! managedObjectContext.fetch(fetchRequest)
        
        return LockCache.from(managedObjects: results)
    }
    
    // MARK: - Subscripting
    
    /// Get the cached lock info for the specified lock.
    subscript (identifier: UUID) -> (LockCache, KeyData)? {
        
        get {
            
            guard let keyData = try! keychain.getData(identifier.rawValue),
                let key = KeyData(data: keyData as Data),
                let managedObject = try! managedObjectContext.find(entity: lockCacheEntity, resourceID: identifier.rawValue, identifierProperty: LockCache.Property.identifier.rawValue)
                else { return nil }
            
            let lockCache = LockCache(managedObject: managedObject)
            
            return (lockCache, key)
        }
        
        set {
            
            guard let (lockCache, key) = newValue
                else { remove(identifier); return }
            
            let _ = try! lockCache.save(context: managedObjectContext)
            
            try! keychain.set(key.data, key: identifier.rawValue)
        }
    }
    
    /// Subscript to get key with the lock identifier.
    subscript (key lockIdentifier: UUID) -> KeyData? {
        
        guard let data = try! keychain.getData(lockIdentifier.rawValue)
            else { return nil }
        
        return KeyData(data: data as Data)
    }
    
    subscript (cache identifier: UUID) -> LockCache? {
        
        get {
            
            guard let managedObject = try! managedObjectContext.find(entity: lockCacheEntity, resourceID: identifier.rawValue, identifierProperty: LockCache.Property.identifier.rawValue)
                else { return nil }
            
            return LockCache(managedObject: managedObject)
        }
        
        set {
            
            guard let lockCache = newValue
                else { remove(identifier); return }
            
            let _ = try! lockCache.save(context: managedObjectContext)
        }
    }
}

// MARK: - Persistance

private func LoadManagedObjectModel() -> NSManagedObjectModel {
    
    let bundle = Bundle(for: Store.self)
    
    let modelURL = bundle.url(forResource: "Model", withExtension: "momd")!
    
    guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Could not load managed object model") }
    
    return managedObjectModel
}

private var PersistentStore: NSPersistentStore?

/// Loads the persistent store.
func LoadPersistentStore() throws {
    
    let url = SQLiteStoreFileURL
    
    // load SQLite store
    
    PersistentStore = try Store.shared.managedObjectContext
        .persistentStoreCoordinator!
        .addPersistentStore(ofType:NSSQLiteStoreType,
                            configurationName: nil,
                            at: url,
                            options: nil)
}

func RemovePersistentStore() throws {
    
    let url = SQLiteStoreFileURL
    
    if FileManager.default.fileExists(atPath: url.path) {
        
        // delete file
        
        try FileManager.default.removeItem(at: url)
    }
    
    if let store = PersistentStore {
        
        guard let psc = Store.shared.managedObjectContext.persistentStoreCoordinator
            else { fatalError() }
        
        try psc.remove(store)
        
        PersistentStore = nil
    }
}

let SQLiteStoreFileURL: URL = {
    
    guard let cacheURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup)
        else { fatalError("Could not get URL for Core Data cache: App Group Error") }
    
    let fileURL = cacheURL.appendingPathComponent("cache.sqlite")
    
    return fileURL
}()
