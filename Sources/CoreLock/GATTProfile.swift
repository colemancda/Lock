//
//  GATTProfile.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
    import Glibc
#endif

import SwiftFoundation
import Bluetooth

public protocol GATTProfileService {
    
    static var UUID: Bluetooth.UUID { get }
}

public protocol GATTProfileCharacteristic {
    
    static var UUID: Bluetooth.UUID { get }
    
    //init?(bigEndian: Data)
    
    //func toBigEndian() -> Data
}

public protocol AuthenticatedCharacteristic: GATTProfileCharacteristic {
    
    var nonce: Nonce { get }
    
    /// HMAC of key and nonce
    var authentication: Data { get }
}

public extension AuthenticatedCharacteristic {
    
    func authenticated(with key: KeyData) -> Bool {
        
        let hmac = HMAC(key: key, message: nonce)
        
        return hmac == authentication
    }
}

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
        
        public var value: UInt64
        
        public init(value: UInt64) {
            
            self.value = value
        }
        
        public init?(bigEndian: Data) {
            
            let length = Version.length
            
            guard bigEndian.byteValue.count == length
                else { return nil }
            
            var value: UInt64 = 0
            
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
    public struct Action: AuthenticatedCharacteristic {
        
        public static let length = 1 + Nonce.length + 64
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "FF0E91BE-044C-11E6-97B4-09AB70D5A8C7")!)
        
        public let action: CoreLock.Action
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public init(action: CoreLock.Action, nonce: Nonce = Nonce(), key: KeyData) {
            
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
    }
    
    /// nonce + IV + encrypt(salt, iv, newKey) + HMAC(salt, nonce) (write-only)
    public struct Setup: AuthenticatedCharacteristic {
        
        public static let length = Nonce.length + IVSize + 48 + HMACSize
        
        /// The private key used to encrypt and decrypt new keys.
        private static let salt = KeyData(data: "p3R1pf9AmQxYlVAixSh6Yr0DRGSc4xST".toUTF8Data())!
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "129E401C-044D-11E6-8FA9-09AB70D5A8C7")!)
        
        public let value: KeyData
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public init(value: KeyData, nonce: Nonce = Nonce()) {
            
            self.value = value
            self.nonce = nonce
            self.authentication = HMAC(key: Setup.salt, message: nonce)
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.byteValue
            
            guard bytes.count == self.dynamicType.length
                else { return nil }
            
            let nonceBytes = Array(bytes[0 ..< Nonce.length])
            
            self.nonce = Nonce(data: Data(byteValue: nonceBytes))!
            
            let ivBytes = Array(bytes[Nonce.length ..< Nonce.length + IVSize])
            
            let iv = InitializationVector(data: Data(byteValue: ivBytes))!
            
            let encryptedBytes = Array(bytes[Nonce.length + IVSize ..< Nonce.length + IVSize + 48])
            
            let decryptedData = decrypt(key: Setup.salt.data, iv: iv, data: Data(byteValue: encryptedBytes))
            
            assert(decryptedData.byteValue.count == KeyData.length)
            
            self.value = KeyData(data: decryptedData)!
            
            let hmac = Array(bytes.suffix(from: Nonce.length + IVSize + 48))
            
            assert(hmac.count == HMACSize)
            
            self.authentication = Data(byteValue: hmac)
        }
        
        public func toBigEndian() -> Data {
            
            let (encryptedKey, iv) = encrypt(key: Setup.salt.data, data: value.data)
            
            let bytes = nonce.data.byteValue + iv.data.byteValue + encryptedKey.byteValue + authentication.byteValue
            
            return Data(byteValue: bytes)
        }
        
        public func authenticatedWithSalt() -> Bool {
            
            return authenticated(with: Setup.salt)
        }
    }
    
    /// Used to unlock door.
    ///
    /// nonce + HMAC(key, nonce) (16 + 64 bytes) (write-only)
    public struct Unlock: AuthenticatedCharacteristic {
        
        public static let length = Nonce.length + HMACSize
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "265B3EC0-044D-11E6-90F2-09AB70D5A8C7")!)
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public init(nonce: Nonce = Nonce(), key: KeyData) {
            
            self.nonce = nonce
            self.authentication = HMAC(key: key, message: nonce)
            
            assert(authentication.byteValue.count == HMACSize)
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.byteValue
            
            guard bytes.count == self.dynamicType.length
                else { return nil }
            
            let nonceBytes = Array(bytes[0 ..< Nonce.length])
            
            assert(nonceBytes.count == Nonce.length)
            
            let hmac = Array(bytes.suffix(from: Nonce.length))
            
            assert(hmac.count == HMACSize)
            
            self.nonce = Nonce(data: Data(byteValue: nonceBytes))!
            self.authentication =  Data(byteValue: hmac)
        }
        
        public func toBigEndian() -> Data {
            
            let bytes = nonce.data.byteValue + authentication.byteValue
            
            assert(bytes.count == self.dynamicType.length)
            
            return Data(byteValue: bytes)
        }
    }
    
    /// Parent Shared Secret (write-only)
    ///
    /// nonce + IV + encrypt(parentKey, iv, sharedSecret) + HMAC(parentKey, nonce)
    public struct NewKeyParentSharedSecret: GATTProfileCharacteristic {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "3A9EE5A8-044D-11E6-90F2-09AB70D5A8C7")!)
    }
    
    /// Child Shared Secret (read-only)
    ///
    /// nonce + IV + encrypt(sharedSecret, iv, childKey) + HMAC(sharedSecret, nonce)
    public struct NewKeyChildKey: GATTProfileCharacteristic {
        
        public static let UUID = Bluetooth.UUID.Bit128(SwiftFoundation.UUID(rawValue: "4CC3B5BA-044D-11E6-A956-09AB70D5A8C7")!)
    }
}

