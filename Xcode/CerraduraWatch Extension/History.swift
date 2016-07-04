//
//  History.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 5/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation

final class History {
    
    static let shared = History()
    
    private(set) var events = [(date: Date, event: Event)]()
    
    func add(event: Event) {
        
        events.append((date: Date(), event: event))
    }
}

enum Event {
    
    case foundLock(PermissionType?)
    
    case unlock(PermissionType)
}
