//
//  Bool.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

public enum BluetoothBool: UInt8 {
    
    case False  = 0x00
    
    case True   = 0x01
    
    public init(_ bool: Bool) {
        
        if bool {
            
            self = .True
            
        } else {
            
            self = .False
        }
    }
}

extension BluetoothBool: DataConvertible {
    
    public init?(data: Data) {
        
        guard data.byteValue.count == 1
            else { return nil }
        
        self.init(rawValue: data.byteValue[0])
    }
    
    public func toData() -> Data {
        
        return Data(byteValue: [rawValue])
    }
}