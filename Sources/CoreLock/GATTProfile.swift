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
    
    //init?(bigEndian: Data)
    
    //func toBigEndian() -> Data
}

public struct LockProfile: GATTProfile {
    
    public struct LockService: GATTProfileService {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "D5373D28-044C-11E6-B3C2-09AB70D5A8C7")!)
        
        /// The UUID lock identifier (16 bytes) (read-only)
        public struct Identifier: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "EB1BA354-044C-11E6-BDFD-09AB70D5A8C7")!)
            
            public var value: SwiftFoundation.UUID
            
            public init(value: SwiftFoundation.UUID) {
                
                self.value = value
            }
            
            public init?(bigEndian: Data) {
                
                let bytes = isBigEndian ? bigEndian.byteValue : bigEndian.byteValue.reversed()
                
                guard let value = SwiftFoundation.UUID(data: Data(byteValue: bytes))
                    else { return nil }
                
                self.value = value
            }
            
            public func toBigEndian() -> Data {
                
                let bytes = isBigEndian ? value.toData().byteValue : value.toData().byteValue.reversed()
                
                return Data(byteValue: bytes)
            }
        }
        
        /// The lock model. (1 byte) (read-only)
        public struct Model: GATTProfileCharacteristic {
            
            public static let length = 1
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "AD96F330-0497-11E6-9EB3-E72D62A5198D")!)
            
            public var value: CoreLock.Model
            
            public init(value: CoreLock.Model) {
                
                self.value = value
            }
            
            public init?(bigEndian: Data) {
                
                guard let byte = bigEndian.byteValue.first where bigEndian.byteValue.count == 1,
                    let value = CoreLock.Model(rawValue: byte)
                    else { return nil }
                
                self.value = value
            }
            
            public func toBigEndian() -> Data {
                
                return Data(byteValue: [value.rawValue])
            }
        }
        
        /// The lock software version. (64 bits / 8 byte) (read-only)
        public struct Version: GATTProfileCharacteristic {
            
            public static let length = sizeof(Int64.self)
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "F28A0E1E-044C-11E6-9032-09AB70D5A8C7")!)
            
            public var value: Int64
            
            public init(value: Int64) {
                
                self.value = value
            }
            
            public init?(bigEndian: Data) {
                
                let length = Version.length
                
                guard bigEndian.byteValue.count == length
                    else { return nil }
                
                var value: Int64 = 0
                
                var dataCopy = bigEndian
                
                withUnsafeMutablePointer(&value) { memcpy($0, &dataCopy, length) }
                
                self.value = value.bigEndian
            }
            
            public func toBigEndian() -> Data {
                
                let length = Version.length
                
                var bigEndianValue = value.bigEndian
                
                var bytes = [UInt8](repeating: 0, count: length)
                
                withUnsafePointer(&bigEndianValue) { memcpy(&bytes, $0, length) }
                
                return Data(byteValue: bytes)
            }
        }
        
        /// The lock's current status (1 byte) (read-only)
        public struct Status: GATTProfileCharacteristic {
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "F868B290-044C-11E6-BD3B-09AB70D5A8C7")!)
            
            public var value: CoreLock.Status
            
            public init(value: CoreLock.Status) {
                
                self.value = value
            }
            
            public init?(bigEndian: Data) {
                
                guard let byte = bigEndian.byteValue.first where bigEndian.byteValue.count == 1,
                    let value = CoreLock.Status(rawValue: byte)
                    else { return nil }
                
                self.value = value
            }
            
            public func toBigEndian() -> Data {
                
                return Data(byteValue: [value.rawValue])
            }
        }
        
        /// Used to change lock's mode. 
        ///
        /// action + nonce + HMAC(key, nonce) (1 + 16 + 64 bytes) (write-only)
        public struct Action: GATTProfileCharacteristic {
            
            public static let length = 1 + Nonce.length + 64
            
            public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "FF0E91BE-044C-11E6-97B4-09AB70D5A8C7")!)
            
            public let action: CoreLock.Action
            
            public let nonce: Nonce
            
            /// HMAC of key and nonce
            public let authentication: Data
            
            public init(action: CoreLock.Action, nonce: Nonce = Nonce(), key: Key) {
                
                self.action = action
                self.nonce = nonce
                self.authentication = HMAC(key: key, message: nonce)
                
                assert(authentication.byteValue.count == HMACSize)
            }
            
            public init?(bigEndian: Data) {
                
                let bytes = bigEndian.byteValue
                
                guard bytes.count == self.dynamicType.length
                    else { return nil }
                
                let actionByte = bytes[0]
                
                let nonceBytes = Array(bytes[1 ..< 1 + Nonce.length])
                
                assert(nonceBytes.count == Nonce.length)
                
                let hmac = Array(bytes.suffix(from: 1 + Nonce.length))
                
                assert(hmac.count == HMACSize)
                
                guard let action = CoreLock.Action(rawValue: actionByte)
                    else { return nil }
                
                self.action = action
                self.nonce = Nonce(data: Data(byteValue: nonceBytes))!
                self.authentication =  Data(byteValue: hmac)
            }
            
            public func toBigEndian() -> Data {
                
                let bytes = [action.rawValue] + nonce.data.byteValue + authentication.byteValue
                
                assert(bytes.count == self.dynamicType.length)
                
                return Data(byteValue: bytes)
            }
            
            public func authenticated(with key: Key) -> Bool {
                
                let hmac = HMAC(key: key, message: nonce)
                
                return hmac == authentication
            }
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
        /// nonce + HMAC(key, nonce) (16 + 64 bytes) (write-only)
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
