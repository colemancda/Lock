//
//  Context.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/9/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

final class LockContext {
    
    let lock: LockCache
    
    init(lock: LockCache) {
        
        self.lock = lock
    }
}
