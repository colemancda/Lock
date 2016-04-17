//
//  SecureData.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

/// Secure Data Protocol. 
public protocol SecureData: Equatable {
    
    /// The data length. 
    static var length: Int { get }
    
    /// The data.
    var data: Data { get }
    
    /// Initialize with data.
    init?(data: Data)
    
    /// Initialize with random value.
    init()
}

public func == <T: SecureData> (lhs: T, rhs: T) -> Bool {
    
    return lhs.data == rhs.data
}


