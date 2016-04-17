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
public protocol GATTProfile { }

public protocol GATTProfileService {
    
    static var UUID: Bluetooth.UUID { get }
}

public protocol GATTProfileCharacteristic {
    
    static var UUID: Bluetooth.UUID { get }
}

public struct LockProfile: GATTProfile {
    
    public struct LockService: GATTProfileService {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "5DD45496-042E-11E6-BEBD-79ED61A5198D")!)
        
        public struct Identifier: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "40A2203C-041B-11E6-B64E-79ED61A5198D")!)
        }
        
        public struct Status: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "98DD5380-042E-11E6-8139-79ED61A5198D")!)
        }
    }
    
    public struct SetupService: GATTProfileService {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "BE7CE5FC-0428-11E6-83A0-A0B770D5A8C7")!)
        
        public struct Key: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "242296CC-0429-11E6-99F3-A0B770D5A8C7")!)
        }
        
        public struct Claimed: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "F6FAD362-042D-11E6-9104-79ED61A5198D")!)
        }
    }
    
    public struct UnlockService: GATTProfileService {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "D00EBFA6-041A-11E6-B1B0-79ED61A5198D")!)
        
        public struct Unlock: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "011E87F6-041C-11E6-B530-79ED61A5198D")!)
        }
    }
}
