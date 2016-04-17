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
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "D5373D28-044C-11E6-B3C2-09AB70D5A8C7")!)
        
        /// The UUID lock identifier (16 bytes) (read-only)
        public struct Identifier: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "EB1BA354-044C-11E6-BDFD-09AB70D5A8C7")!)
        }
        
        /// The lock software version. (Variable size String) (read-only)
        public struct Version: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "F28A0E1E-044C-11E6-9032-09AB70D5A8C7")!)
        }
        
        /// The lock's current status (1 byte) (read-only)
        public struct Status: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "F868B290-044C-11E6-BD3B-09AB70D5A8C7")!)
        }
        
        /// Used to change lock's mode. 
        ///
        /// nonce + HMAC(key, nonce) (16 + 64 bytes) (write-only)
        public struct Action: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "FF0E91BE-044C-11E6-97B4-09AB70D5A8C7")!)
        }
    }
    
    public struct SetupService: GATTProfileService {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "04A51B0C-044D-11E6-B449-09AB70D5A8C7")!)
        
        /// Nonce, only retrievable by one peer (16 bytes) (read-only)
        public struct Nonce: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "09CDA3BA-044D-11E6-B15B-09AB70D5A8C7")!)
        }
        
        /// Key encrypted by nonce (write-only)
        public struct Key: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "129E401C-044D-11E6-8FA9-09AB70D5A8C7")!)
        }
        
        /// Boolean indicating end of operation (1 byte) (write-only)
        public struct Finished: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "1B338D86-044D-11E6-B3C2-09AB70D5A8C7")!)
        }
    }
    
    public struct UnlockService: GATTProfileService {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "20385B5E-044D-11E6-8E62-09AB70D5A8C7")!)
        
        /// Used to unlock door.
        ///
        /// message(date, nonce) + HMAC(key, message) (16 + 64 bytes) (write-only)
        public struct Unlock: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "265B3EC0-044D-11E6-90F2-09AB70D5A8C7")!)
        }
    }
    
    public struct NewKeyService: GATTProfileService {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "2C12F862-044D-11E6-9032-09AB70D5A8C7")!)
        
        /// Nonce, only retrievable by parent peer (16 bytes) (read-only)
        public struct ParentNonce: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "3280D052-044D-11E6-8535-09AB70D5A8C7")!)
        }
        
        /// Parent Shared Secret confirmation (write-only)
        ///
        /// encrypt(nonce, shared secret) + HMac(parentKey, parentNonce)
        public struct ParentSharedSecret: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "3A9EE5A8-044D-11E6-90F2-09AB70D5A8C7")!)
        }
        
        /// Boolean indicating end of parent operation (1 byte) (write-only)
        public struct ParentFinished: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "404BB300-044D-11E6-BDFD-09AB70D5A8C7")!)
        }
        
        /// Nonce, only retrievable by child peer (16 bytes) (read-only)
        public struct ChildNonce: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "465DDCFA-044D-11E6-B8D9-09AB70D5A8C7")!)
        }
        
        /// Child Shared Secret confirmation (read-only)
        ///
        /// encrypt(child nonce + shared secret, childKey)
        public struct ChildKey: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "4CC3B5BA-044D-11E6-A956-09AB70D5A8C7")!)
        }
        
        /// Boolean indicating end of child operation (1 byte) (write-only)
        public struct ChildFinished: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "506494FA-044D-11E6-9F11-09AB70D5A8C7")!)
        }
    }
}
