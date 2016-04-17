//
//  Key.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

public struct Key {
    
    public static let length = 256
    
    public let data: Data
    
    public init?(string: String) {
        
        let data = string.toUTF8Data()
        
        guard data.byteValue.count == Key.length
            else { return nil }
        
        self.data = data
    }
    
    public init?(data: Data) {
        
        guard data.byteValue.count == Key.length
            else { return nil }
        
        self.data = data
    }
    
    /// Initializes a `Key` with a random value.
    public init() {
        
        let bytes = UUID().toData().byteValue + UUID().toData().byteValue.reversed()
        
        self.data = Data(byteValue: bytes)
        
        assert(self.data.byteValue.count == Key.length)
    }
}