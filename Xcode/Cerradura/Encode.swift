//
//  Encode.swift
//  CoreDataStruct
//
//  Created by Alsey Coleman Miller on 11/5/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import Foundation
import CoreData

/// Specifies how a type can be encoded to be stored with Core Data.
public protocol CoreDataEncodable {
    
    func save(context: NSManagedObjectContext) throws -> NSManagedObject
}

public extension Collection where Iterator.Element: CoreDataEncodable {
    
    func save(context: NSManagedObjectContext) throws -> [NSManagedObject] {
        
        var managedObjects = [NSManagedObject]()
        
        for element in self {
            
            let managedObject = try element.save(context: context)
            
            managedObjects.append(managedObject)
        }
        
        return managedObjects
    }
}