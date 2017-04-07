//
//  Integer.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 8/24/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

public extension UInt16 {
    
    /// Initializes value from two bytes.
    public init(bytes: (UInt8, UInt8)) {
        
        self = unsafeBitCast(bytes, to: UInt16.self)
    }
    
    /// Converts to two bytes. 
    public var bytes: (UInt8, UInt8) {
        
        return unsafeBitCast(self, to: (UInt8, UInt8).self)
    }
}

