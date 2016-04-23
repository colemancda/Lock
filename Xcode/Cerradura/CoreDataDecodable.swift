//
//  Decode.swift
//  CoreDataStruct
//
//  Created by Alsey Coleman Miller on 11/5/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import Foundation
import CoreData

/// Specifies how a type can be decoded from Core Data.
public protocol CoreDataDecodable {
    
    init(managedObject: NSManagedObject)
}

public extension NSManagedObjectContext {
    
    /// Executes a fetch request and returns ```CoreDataDecodable``` types.
    func executeFetchRequest<T: CoreDataDecodable>(fetchRequest: NSFetchRequest) throws -> [T] {
        
        guard fetchRequest.resultType == NSFetchRequestResultType(rawValue: 0x00)
            else { fatalError("Method only supports fetch requests with NSFetchRequestManagedObjectResultType") }
        
        let managedObjects = try self.fetch(fetchRequest) as! [NSManagedObject]
        
        let decodables = managedObjects.map { (element) -> T in T.init(managedObject: element) }
        
        return decodables
    }
}

public extension CoreDataDecodable {
    
    static func from(managedObjects: [NSManagedObject]) -> [Self] {
        
        return managedObjects.map { (managedObject) in return self.init(managedObject: managedObject) }
    }
}