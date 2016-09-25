//
//  LockCache.swift
//  LockCache
//
//  Created by Alsey Coleman Miller on 4/22/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import CoreLock
import CoreData

/// Cached lock information.
struct LockCache: CoreDataEncodable, CoreDataDecodable {
    
    let identifier: UUID
    
    var name: String
    
    let model: Model
    
    let version: UInt64
    
    let packageVersion: (UInt16, UInt16, UInt16)?
    
    let permission: Permission
    
    let keyIdentifier: UUID
}

// MARK: - CoreData

extension LockCache {
    
    static var entityName: String { return "Lock" }
    
    enum Property: String {
        
        case identifier, name, model, version, packageVersion, permission, keyIdentifier
    }
    
    func save(context: NSManagedObjectContext) throws -> NSManagedObject {
        
        let entity = context.persistentStoreCoordinator!.managedObjectModel.entitiesByName[LockCache.entityName]!
        
        let managedObject = try context.findOrCreate(entity: entity, resourceID: self.identifier.rawValue, identifierProperty: Property.identifier.rawValue)
        
        managedObject.setValue(name, forKey: Property.name.rawValue)
        managedObject.setValue(NSNumber(value: model.rawValue), forKey: Property.model.rawValue)
        managedObject.setValue(NSNumber(value: version), forKey: Property.version.rawValue)
        managedObject.setValue(permission.toBigEndian(), forKey: Property.permission.rawValue)
        managedObject.setValue(keyIdentifier.rawValue, forKey: Property.keyIdentifier.rawValue)
        
        let packageVersionData: Data?
        
        if let packageVersion = self.packageVersion {
            
            packageVersionData = LockService.PackageVersion(value: packageVersion).toBigEndian()
            
        } else {
            
            packageVersionData = nil
        }
        
        managedObject.setValue(packageVersionData, forKey: Property.packageVersion.rawValue)
        
        try context.save()
        
        return managedObject
    }
    
    init(managedObject: NSManagedObject) {
        
        guard managedObject.entity.name == LockCache.entityName else { fatalError("Invalid Entity") }
        
        let identifierString = managedObject.value(forKey: Property.identifier.rawValue) as! String
        self.identifier = UUID(rawValue: identifierString)!
        
        self.name = managedObject.value(forKey: Property.name.rawValue) as! String
        
        let modelValue = managedObject.value(forKey: Property.model.rawValue) as! NSNumber
        self.model = Model(rawValue: modelValue.uint8Value)!
        
        self.version = (managedObject.value(forKey: Property.version.rawValue) as! NSNumber).uint64Value
        
        if let packageVersionData = managedObject.value(forKey: Property.packageVersion.rawValue) as? Data {
            
            self.packageVersion = LockService.PackageVersion(bigEndian: packageVersionData)!.value
            
        } else {
            
            self.packageVersion = nil
        }
        
        let permissionData = managedObject.value(forKey: Property.permission.rawValue) as! Data
        self.permission = Permission(bigEndian: permissionData)!
        
        let keyIdentifierString = managedObject.value(forKey: Property.keyIdentifier.rawValue) as! String
        self.keyIdentifier = UUID(rawValue: keyIdentifierString)!
    }
}
