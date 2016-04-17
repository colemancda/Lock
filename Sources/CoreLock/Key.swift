//
//  Key.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

public struct Key: RawRepresentable {
    
    public static let length = 256
    
    public let rawValue: String
    
    public init?(rawValue: String) {
        
        guard rawValue.utf8.count == Key.length
            else { return nil }
        
        self.rawValue = rawValue
    }
    
    /// Initializes a `Key` with a random value.
    public init() {
        
        let string = UUID().rawValue + String(UTF8Data: Data(byteValue: UUID().rawValue.utf8.reversed()))!
        
        assert(string.toUTF8Data().byteValue.count == Key.length)
        
        self.rawValue = string
    }
}

extension Key: DataConvertible {
    
    public init?(data: Data) {
        
        guard let string = String(UTF8Data: data) where data.byteValue.count == Key.length
            else { return nil }
        
        self.rawValue = string
    }
    
    public func toData() -> Data {
        
        return rawValue.toUTF8Data()
    }
}