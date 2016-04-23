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
struct Lock {
    
    let identifier: UUID
    
    let name: String
    
    let model: Model
    
    let version: Int64
    
    let permission: Permission
}

// MARK: - CoreData

extension Lock {
    
    static var CoreDataEntity: String { return "Lock" }
    
    enum CoreDataProperty: String {
        
        case identifier, name, model, version, permission
    }
    
    
}