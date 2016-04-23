//
//  Key.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/22/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

public struct Key {
    
    public let data: KeyData
    
    public let permission: Permission
    
    public init(data: KeyData = KeyData(), permission: Permission = .owner) {
        
        self.data = data
        self.permission = permission
    }
}
