//
//  Nonce.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

/// Cryptographic nonce
public struct Nonce: SecureData {
    
    public static let length = 16
    
    public let data: Data
    
    public init?(data: Data) {
        
        guard data.byteValue.count == self.dynamicType.length
            else { return nil }
        
        self.data = data
    }
    
    public init() {
        
        self.data = random(self.dynamicType.length)
    }
}