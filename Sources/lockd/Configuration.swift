//
//  Configuration.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock

struct Configuration {
    
    let identifier: UUID
    
    let model: Model
    
    init() {
        
        self.identifier = SwiftFoundation.UUID()
        
        self.model = Model.orangePi
    }
}