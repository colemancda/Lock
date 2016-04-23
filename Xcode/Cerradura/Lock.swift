//
//  Lock.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/22/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock
import CoreData

/// Cached lock information.
struct Lock: CoreDataEncodable, CoreDataDecodable {
    
    let identifier: UUID
    
    let name: String
    
    let model: Model
    
    let version: Int64
    
    let permission: Permission
}

// MARK: - CoreData

extension Lock {
    
    static var entityName: String { return "Lock" }
    
    enum Property: String {
        
        case identifier, name, model, version, permission
    }
    
    func save(context: NSManagedObjectContext) throws -> NSManagedObject {
        
        let entity = context.persistentStoreCoordinator!.managedObjectModel.entitiesByName[Lock.entityName]!
        
        let managedObject = try context.findOrCreate(entity: entity, resourceID: self.identifier.rawValue, identifierProperty: Property.identifier.rawValue)
        
        managedObject.setValue(name, forKey: Property.name.rawValue)
        managedObject.setValue(NSNumber(value: Int16(model.rawValue)), forKey: Property.model.rawValue)
        managedObject.setValue(NSNumber(value: version), forKey: Property.version.rawValue)
        managedObject.setValue(permission.toBigEndian().toFoundation(), forKey: Property.permission.rawValue)
        
        try context.save()
        
        return managedObject
    }
    
    init(managedObject: NSManagedObject) {
        
        guard managedObject.entity.name == Lock.entityName else { fatalError("Invalid Entity") }
        
        let identifierString = managedObject.value(forKey: Property.identifier.rawValue) as! String
        self.identifier = UUID(rawValue: identifierString)!
        
        self.name = managedObject.value(forKey: Property.name.rawValue) as! NSString as String
        
        let modelValue = managedObject.value(forKey: Property.identifier.rawValue) as! NSNumber
        self.model = Model(rawValue: modelValue.uint8Value)!
        
        self.version = (managedObject.value(forKey: Property.version.rawValue) as! NSNumber).int64Value
        
        let permissionData = managedObject.value(forKey: Property.permission.rawValue) as! NSData
        self.permission = Permission(bigEndian: Data(foundation: permissionData))!
    }
}
