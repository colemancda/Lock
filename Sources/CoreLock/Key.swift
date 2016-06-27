//
//  Key.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/22/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

public struct Key: Equatable {
    
    public let identifier: SwiftFoundation.UUID
    
    public let data: KeyData
    
    public let permission: Permission
    
    public init(identifier: SwiftFoundation.UUID = SwiftFoundation.UUID(), data: KeyData = KeyData(), permission: Permission = .owner) {
        
        self.identifier = identifier
        self.data = data
        self.permission = permission
    }
}

public func == (lhs: Key, rhs: Key) -> Bool {
    
    return lhs.identifier == rhs.identifier
        && lhs.data == rhs.data
        && lhs.permission == rhs.permission
}
