//
//  Key.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

/// A lock's key used for unlocking and actions.
public struct Key: SecureData {
    
    public static let length = 512 / 8 // 64
    
    public let data: Data
    
    public init?(data: Data) {
        
        guard data.byteValue.count == self.dynamicType.length
            else { return nil }
        
        self.data = data
    }
    
    /// Initializes a `Key` with a random value.
    public init() {
        
        self.data = random(self.dynamicType.length)
    }
}