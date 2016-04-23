//
//  Store.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/22/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock

/// Store for saving and retrieving lock keys.
final class Store {
    
    static let sharedStore = Store()
    
    private(set) var keys = [SwiftFoundation.UUID: ]()
    
    private init() {
        
        
    }
    
    
}

struct KeyInfo