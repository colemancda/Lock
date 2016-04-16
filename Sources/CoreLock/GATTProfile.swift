//
//  GATTProfile.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import Bluetooth

/// A GATT Profile
public protocol GATTProfile {
    
    static var services: [GATTProfileService.Type] { get }
}

public protocol GATTProfileService {
    
    static var UUID: Bluetooth.UUID { get }
    
    static var characteristics: [GATTProfileCharacteristic.Type] { get }
}

public protocol GATTProfileCharacteristic {
    
    static var UUID: Bluetooth.UUID { get }
}

public struct LockProfile: GATTProfile {
    
    public static let services: [GATTProfileService.Type] = [LockService.self]
    
    /// The Lock's main GATT Service
    public struct LockService: GATTProfileService {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "D00EBFA6-041A-11E6-B1B0-79ED61A5198D")!)
        
        public static let characteristics: [GATTProfileCharacteristic.Type] = [Identifier.self, Unlock.self]
        
        public struct Identifier: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "40A2203C-041B-11E6-B64E-79ED61A5198D")!)
        }
        
        public struct Unlock: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "011E87F6-041C-11E6-B530-79ED61A5198D")!)
        }
    }
}
