//
//  CoreDataExtensions.swift
//  CoreVistage
//
//  Created by Alsey Coleman Miller on 10/6/15.
//  Copyright © 2015 Vistage. All rights reserved.
//

import Foundation
import CoreData

public extension NSManagedObjectContext {
    
    /// Wraps the block to allow for error throwing.
    @available(OSX 10.7, *)
    func performErrorBlockAndWait(_ block: () throws -> ()) throws {
        
        var blockError: ErrorProtocol?
        
        self.performAndWait {
            
            do { try block() }
            
            catch { blockError = error }
            
            return
        }
        
        if let error = blockError {
            
            throw error
        }
        
        return
    }
    
    func findOrCreate<T: NSManagedObject>(entity: NSEntityDescription, resourceID: String, identifierProperty: String) throws -> T {
        
        // get cached resource...
        
        let fetchRequest = NSFetchRequest<T>(entityName: entity.name!)
        
        fetchRequest.fetchLimit = 1
        
        fetchRequest.includesSubentities = false
        
        // create predicate
        
        fetchRequest.predicate = ComparisonPredicate(leftExpression: NSExpression(forKeyPath: identifierProperty), rightExpression: NSExpression(forConstantValue: resourceID), modifier: ComparisonPredicate.Modifier.directPredicateModifier, type: PredicateOperatorType.equalToPredicateOperatorType, options: NSComparisonPredicateOptions.normalizedPredicateOption)
        
        fetchRequest.returnsObjectsAsFaults = false
        
        // fetch
        
        let results = try self.fetch(fetchRequest) as! [T]
        
        let resource: T
        
        if let firstResult = results.first {
            
            resource = firstResult
        }
            
        // create cached resource if not found
        else {
            
            // create a new entity
            let newManagedObject = NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: self)
            
            // set resource ID
            (newManagedObject).setValue(resourceID, forKey: identifierProperty)
            
            resource = newManagedObject as! T
        }
        
        return resource
    }
    
    func find<T: NSManagedObject>(entity: NSEntityDescription, resourceID: String, identifierProperty: String) throws -> T? {
        
        // get cached resource...
        
        let fetchRequest = NSFetchRequest<T>(entityName: entity.name!)
        
        fetchRequest.fetchLimit = 1
        
        fetchRequest.includesSubentities = false
        
        // create predicate
        
        fetchRequest.predicate = ComparisonPredicate(leftExpression: NSExpression(forKeyPath: identifierProperty), rightExpression: NSExpression(forConstantValue: resourceID), modifier: ComparisonPredicateModifier.directPredicateModifier, type: NSPredicateOperatorType.equalToPredicateOperatorType, options: NSComparisonPredicateOptions.normalizedPredicateOption)
        
        fetchRequest.returnsObjectsAsFaults = false
        
        // fetch
        
        return (try self.fetch(fetchRequest) as! [T]).first
    }
}
