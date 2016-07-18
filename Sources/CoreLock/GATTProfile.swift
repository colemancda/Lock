//
//  GATTProfile.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

import SwiftFoundation
import Bluetooth
import BSON

public protocol GATTProfileService {
    
    static var UUID: BluetoothUUID { get }
}

public protocol GATTProfileCharacteristic {
    
    static var UUID: BluetoothUUID { get }
    
    init?(bigEndian: Data)
    
    func toBigEndian() -> Data
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
    
    public static let UUID = BluetoothUUID(rawValue: "D5373D28-044C-11E6-B3C2-09AB70D5A8C7")!
    
    /// The UUID lock identifier (16 bytes) (read-only)
    public struct Identifier: GATTProfileCharacteristic {
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "EB1BA354-044C-11E6-BDFD-09AB70D5A8C7")!)
        
        public var value: SwiftFoundation.UUID
        
        public init(value: SwiftFoundation.UUID) {
            
            self.value = value
        }
        
        public init?(bigEndian: Data) {
            
            let byteValue = isBigEndian ? bigEndian.bytes : bigEndian.bytes.reversed()
            
            guard let value = SwiftFoundation.UUID(data: Data(bytes: byteValue))
                else { return nil }
            
            self.value = value
        }
        
        public func toBigEndian() -> Data {
            
            let bytes = isBigEndian ? value.toData().bytes : value.toData().bytes.reversed()
            
            return Data(bytes: bytes)
        }
    }
    
    /// The lock model. (1 byte) (read-only)
    public struct Model: GATTProfileCharacteristic {
        
        public static let length = 1
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "AD96F330-0497-11E6-9EB3-E72D62A5198D")!)
        
        public var value: CoreLock.Model
        
        public init(value: CoreLock.Model) {
            
            self.value = value
        }
        
        public init?(bigEndian: Data) {
            
            guard let byte = bigEndian.bytes.first where bigEndian.bytes.count == 1,
                let value = CoreLock.Model(rawValue: byte)
                else { return nil }
            
            self.value = value
        }
        
        public func toBigEndian() -> Data {
            
            return Data(bytes: [value.rawValue])
        }
    }
    
    /// The lock software version. (64 bits / 8 byte) (read-only)
    public struct Version: GATTProfileCharacteristic {
        
        public static let length = sizeof(Int64.self)
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "F28A0E1E-044C-11E6-9032-09AB70D5A8C7")!)
        
        public var value: UInt64
        
        public init(value: UInt64) {
            
            self.value = value
        }
        
        public init?(bigEndian: Data) {
            
            let length = Version.length
            
            guard bigEndian.bytes.count == length
                else { return nil }
            
            var value: UInt64 = 0
            
            var dataCopy = bigEndian
            
            withUnsafeMutablePointer(&value) { let _ = memcpy($0, &dataCopy, length) }
            
            self.value = value.bigEndian
        }
        
        public func toBigEndian() -> Data {
            
            let length = Version.length
            
            var bigEndianValue = value.bigEndian
            
            var bytes = [UInt8](repeating: 0, count: length)
            
            withUnsafePointer(&bigEndianValue) {let _ = memcpy(&bytes, $0, length) }
            
            return Data(bytes: bytes)
        }
    }
    
    /// The lock's current status (1 byte) (read-only)
    public struct Status: GATTProfileCharacteristic {
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "F868B290-044C-11E6-BD3B-09AB70D5A8C7")!)
        
        public var value: CoreLock.Status
        
        public init(value: CoreLock.Status) {
            
            self.value = value
        }
        
        public init?(bigEndian: Data) {
            
            guard let byte = bigEndian.bytes.first where bigEndian.bytes.count == 1,
                let value = CoreLock.Status(rawValue: byte)
                else { return nil }
            
            self.value = value
        }
        
        public func toBigEndian() -> Data {
            
            return Data(bytes: [value.rawValue])
        }
    }
    
    /// Key UUID + nonce + IV + encrypt(salt, iv, newKey) + HMAC(salt, nonce) (write-only)
    public struct Setup: AuthenticatedCharacteristic {
        
        public static let length = SwiftFoundation.UUID.length + Nonce.length + IVSize + 48 + HMACSize
        
        /// The private key used to encrypt and decrypt new keys.
        private static let salt = KeyData(data: "p3R1pf9AmQxYlVAixSh6Yr0DRGSc4xST".toUTF8Data())!
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "129E401C-044D-11E6-8FA9-09AB70D5A8C7")!)
        
        public let identifier: SwiftFoundation.UUID
        
        public let value: KeyData
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public init(identifier: SwiftFoundation.UUID, value: KeyData, nonce: Nonce = Nonce()) {
            
            self.identifier = identifier
            self.value = value
            self.nonce = nonce
            self.authentication = HMAC(key: Setup.salt, message: nonce)
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.bytes
            
            guard bytes.count == self.dynamicType.length
                else { return nil }
            
            self.identifier = SwiftFoundation.UUID(bigEndian: Data(bytes: Array(bytes[0 ..< 16])))!
            
            let nonceBytes = Array(bytes[16 ..< 16 + Nonce.length])
            
            self.nonce = Nonce(data: Data(bytes: nonceBytes))!
            
            let ivBytes = Array(bytes[16 + Nonce.length ..< 16 + Nonce.length + IVSize])
            
            let iv = InitializationVector(data: Data(bytes: ivBytes))!
            
            let encryptedBytes = Array(bytes[16 + Nonce.length + IVSize ..< 16 + Nonce.length + IVSize + 48])
            
            let decryptedData = decrypt(key: Setup.salt.data, iv: iv, data: Data(bytes: encryptedBytes))
            
            assert(decryptedData.bytes.count == KeyData.length)
            
            self.value = KeyData(data: decryptedData)!
            
            let hmac = Array(bytes.suffix(from: 16 + Nonce.length + IVSize + 48))
            
            assert(hmac.count == HMACSize)
            
            self.authentication = Data(bytes: hmac)
        }
        
        public func toBigEndian() -> Data {
            
            let (encryptedKey, iv) = encrypt(key: Setup.salt.data, data: value.data)
            
            let bytes = identifier.toBigEndian().bytes + nonce.data.bytes + iv.data.bytes + encryptedKey.bytes + authentication.bytes
            
            assert(bytes.count == Setup.length)
            
            return Data(bytes: bytes)
        }
        
        public func authenticatedWithSalt() -> Bool {
            
            return authenticated(with: Setup.salt)
        }
    }
    
    /// Used to unlock door.
    ///
    /// Key UUID + nonce + HMAC(key, nonce) (16 + 16 + 64 bytes) (write-only)
    public struct Unlock: AuthenticatedCharacteristic {
        
        public static let length = SwiftFoundation.UUID.length + Nonce.length + HMACSize
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "265B3EC0-044D-11E6-90F2-09AB70D5A8C7")!)
        
        public let identifier: SwiftFoundation.UUID
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public init(identifier: SwiftFoundation.UUID, nonce: Nonce = Nonce(), key: KeyData) {
            
            self.identifier = identifier
            self.nonce = nonce
            self.authentication = HMAC(key: key, message: nonce)
            
            assert(authentication.bytes.count == HMACSize)
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.bytes
            
            guard bytes.count == self.dynamicType.length
                else { return nil }
            
            let identifier = SwiftFoundation.UUID(bigEndian: Data(bytes: Array(bytes[0 ..< 16])))!
            
            let nonceBytes = Array(bytes[16 ..< 16 + Nonce.length])
            
            assert(nonceBytes.count == Nonce.length)
            
            let hmac = Array(bytes.suffix(from: 16 + Nonce.length))
            
            assert(hmac.count == HMACSize)
            
            self.identifier = identifier
            self.nonce = Nonce(data: Data(bytes: nonceBytes))!
            self.authentication =  Data(bytes: hmac)
        }
        
        public func toBigEndian() -> Data {
            
            return identifier.toBigEndian() + nonce.data + authentication
        }
    }
    
    /// New Key Parent Shared Secret (write-only)
    ///
    /// parent key UUID + nonce + IV + encrypt(parentKey, iv, sharedSecret) + HMAC(parentKey, nonce) + permission + child key UUID + name
    public struct NewKeyParent: AuthenticatedCharacteristic {
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "3A9EE5A8-044D-11E6-90F2-09AB70D5A8C7")!)
        
        public static let length = (min: SwiftFoundation.UUID.length + Nonce.length + IVSize + 48 + HMACSize + Permission.length + SwiftFoundation.UUID.length + 1, max: SwiftFoundation.UUID.length + Nonce.length + IVSize + 48 + HMACSize + Permission.length + SwiftFoundation.UUID.length + Key.Name.maxLength)
        
        /// The parent key identifier.
        public let parent: SwiftFoundation.UUID
        
        /// The child key identifier.
        public let child: SwiftFoundation.UUID
        
        /// The name of the new key.
        public let name: Key.Name
        
        /// The permission of the new key.
        public let permission: Permission
        
        /// The nonce of the shared secret.
        public let nonce: Nonce
        
        /// HMAC of parent key and nonce
        public let authentication: Data
        
        public let encryptedSharedSecret: Data
        
        public let initializationVector: InitializationVector
        
        public init(nonce: Nonce = Nonce(),
                    sharedSecret: KeyData = KeyData(),
                    parentKey: (identifier: SwiftFoundation.UUID, data: KeyData),
                    childKey: (identifier: SwiftFoundation.UUID, permission: Permission, name: Key.Name)) {
            
            self.parent = parentKey.identifier
            self.child = childKey.identifier
            self.permission = childKey.permission
            self.name = childKey.name
            self.nonce = nonce
            self.authentication = HMAC(key: parentKey.data, message: nonce)
            
            let (encryptedSharedSecret, iv) = encrypt(key: parentKey.data.data, data: sharedSecret.data)
            
            self.initializationVector = iv
            self.encryptedSharedSecret = encryptedSharedSecret
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.bytes
            
            guard bytes.count >= NewKeyParent.length.min
                && bytes.count <= NewKeyParent.length.max
                else { return nil }
            
            self.parent = SwiftFoundation.UUID(bigEndian: Data(bytes: Array(bytes[0 ..< 16])))!
            
            let nonceBytes = Array(bytes[16 ..< 16 + Nonce.length])
            
            self.nonce = Nonce(data: Data(bytes: nonceBytes))!
            
            let ivBytes = Array(bytes[16 + Nonce.length ..< 16 + Nonce.length + IVSize])
            
            self.initializationVector = InitializationVector(data: Data(bytes: ivBytes))!
            
            self.encryptedSharedSecret = Data(bytes: Array(bytes[16 + Nonce.length + IVSize ..< 16 + Nonce.length + IVSize + 48]))
                        
            let hmac = Array(bytes[16 + Nonce.length + IVSize + 48 ..< 16 + Nonce.length + IVSize + 48 + HMACSize])
            
            assert(hmac.count == HMACSize)
            
            self.authentication = Data(bytes: hmac)
            
            let permissionBytes = Array(bytes[16 + Nonce.length + IVSize + 48 + HMACSize ..< 16 + Nonce.length + IVSize + 48 + HMACSize + Permission.length])
            
            guard let permission = Permission(bigEndian: Data(bytes: permissionBytes))
                else { return nil }
            
            self.permission = permission
            
            self.child = SwiftFoundation.UUID(bigEndian: Data(bytes: Array(bytes[16 + Nonce.length + IVSize + 48 + HMACSize + Permission.length ..< 16 + Nonce.length + IVSize + 48 + HMACSize + Permission.length + 16])))!
            
            self.name = Key.Name(data: Data(bytes: bytes.suffix(from: SwiftFoundation.UUID.length + Nonce.length + IVSize + 48 + HMACSize + Permission.length + SwiftFoundation.UUID.length)))!
        }
        
        public func toBigEndian() -> Data {
            
            return parent.toBigEndian() + nonce.data + initializationVector.data + encryptedSharedSecret + authentication + permission.toBigEndian() + child.toBigEndian() + name.toData()
        }
        
        public func decrypt(key parentKey: KeyData) -> KeyData? {
            
            // make sure its authenticated
            guard authenticated(with: parentKey)
                else { return nil }
            
            let decryptedData = CoreLock.decrypt(key: parentKey.data, iv: initializationVector, data: encryptedSharedSecret)
            
            assert(decryptedData.bytes.count == KeyData.length)
            
            guard let sharedSecret = KeyData(data: decryptedData)
                else { return nil }
            
            return sharedSecret
        }
    }
    
    /// New Key Child Shared Secret (write-only)
    ///
    /// new key UUID + nonce + IV + encrypt(sharedSecret, iv, childKey) + HMAC(sharedSecret, nonce)
    public struct NewKeyChild: AuthenticatedCharacteristic {
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "4CC3B5BA-044D-11E6-A956-09AB70D5A8C7")!)
        
        public static let length = SwiftFoundation.UUID.length + Nonce.length + IVSize + 48 + HMACSize
        
        public let identifier: SwiftFoundation.UUID
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public let encryptedNewKey: Data
        
        public let initializationVector: InitializationVector
        
        public init(nonce: Nonce = Nonce(), sharedSecret: KeyData, newKey: (identifier: SwiftFoundation.UUID, data: KeyData)) {
            
            self.identifier = newKey.identifier
            self.nonce = nonce
            self.authentication = HMAC(key: sharedSecret, message: nonce)
            
            let (encryptedNewKey, iv) = encrypt(key: sharedSecret.data, data: newKey.data.data)
            
            self.initializationVector = iv
            self.encryptedNewKey = encryptedNewKey
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.bytes
            
            guard bytes.count == self.dynamicType.length
                else { return nil }
            
            self.identifier = SwiftFoundation.UUID(bigEndian: Data(bytes: Array(bytes[0 ..< 16])))!
            
            let nonceBytes = Array(bytes[16 ..< 16 + Nonce.length])
            
            self.nonce = Nonce(data: Data(bytes: nonceBytes))!
            
            let ivBytes = Array(bytes[16 + Nonce.length ..< 16 + Nonce.length + IVSize])
            
            self.initializationVector = InitializationVector(data: Data(bytes: ivBytes))!
            
            self.encryptedNewKey = Data(bytes: Array(bytes[16 + Nonce.length + IVSize ..< 16 + Nonce.length + IVSize + 48]))
            
            let hmac = Array(bytes[16 + Nonce.length + IVSize + 48 ..< 16 + Nonce.length + IVSize + 48 + HMACSize])
            
            assert(hmac.count == HMACSize)
            
            self.authentication = Data(bytes: hmac)
        }
        
        public func toBigEndian() -> Data {
            
            let bytes = identifier.toBigEndian().bytes + nonce.data.bytes + initializationVector.data.bytes + encryptedNewKey.bytes + authentication.bytes
            
            assert(bytes.count == self.dynamicType.length)
            
            return Data(bytes: bytes)
        }
        
        public func decrypt(sharedSecret: KeyData) -> KeyData? {
            
            // make sure its authenticated
            guard authenticated(with: sharedSecret)
                else { return nil }
            
            let decryptedData = CoreLock.decrypt(key: sharedSecret.data, iv: initializationVector, data: encryptedNewKey)
            
            assert(decryptedData.bytes.count == KeyData.length)
            
            return KeyData(data: decryptedData)!
        }
    }
    
    /// Used enable / disable HomeKit.
    ///
    /// Key UUID + nonce + HMAC(key, nonce) + enable (16 + 16 + 64 + 1 bytes) (write-only)
    public struct HomeKitEnable: AuthenticatedCharacteristic {
        
        public static let length = SwiftFoundation.UUID.length + Nonce.length + HMACSize + 1
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "A187317C-6DE5-4842-800A-0D7C7529B4E7")!)
        
        public let identifier: SwiftFoundation.UUID
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public let enable: Bool
        
        public init(identifier: SwiftFoundation.UUID, nonce: Nonce = Nonce(), key: KeyData, enable: Bool = true) {
            
            self.identifier = identifier
            self.nonce = nonce
            self.authentication = HMAC(key: key, message: nonce)
            self.enable = enable
            
            assert(authentication.bytes.count == HMACSize)
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.bytes
            
            guard bytes.count == self.dynamicType.length
                else { return nil }
            
            let UUIDLength = SwiftFoundation.UUID.length
            
            let identifier = SwiftFoundation.UUID(bigEndian: Data(bytes: Array(bytes[0 ..< UUIDLength])))!
            
            let nonceBytes = Array(bytes[UUIDLength ..< UUIDLength + Nonce.length])
            
            assert(nonceBytes.count == Nonce.length)
            
            let hmac = Array(bytes[UUIDLength + Nonce.length ..< UUIDLength + Nonce.length + HMACSize])
            
            assert(hmac.count == HMACSize)
            
            self.identifier = identifier
            self.nonce = Nonce(data: Data(bytes: nonceBytes))!
            self.authentication =  Data(bytes: hmac)
            self.enable = BluetoothBool(rawValue: bytes[UUIDLength + Nonce.length + HMACSize])!.boolValue
        }
        
        public func toBigEndian() -> Data {
            
            let data = identifier.toBigEndian() + nonce.data + authentication + BluetoothBool(enable).toData()
            
            assert(data.count == self.dynamicType.length)
            
            return data
        }
    }
    
    /// Used to update device. (Should only be sent by lock owner)
    ///
    /// Key UUID + nonce + HMAC(key, nonce) (16 + 16 + 64 bytes) (write-only)
    public struct Update: AuthenticatedCharacteristic {
        
        public static let length = SwiftFoundation.UUID.length + Nonce.length + HMACSize
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "17CA5159-1DAF-431A-8CF0-A9CAD500BD96")!)
        
        public let identifier: SwiftFoundation.UUID
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public init(identifier: SwiftFoundation.UUID, nonce: Nonce = Nonce(), key: KeyData) {
            
            self.identifier = identifier
            self.nonce = nonce
            self.authentication = HMAC(key: key, message: nonce)
            
            assert(authentication.bytes.count == HMACSize)
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.bytes
            
            guard bytes.count == self.dynamicType.length
                else { return nil }
            
            let identifier = SwiftFoundation.UUID(bigEndian: Data(bytes: Array(bytes[0 ..< 16])))!
            
            let nonceBytes = Array(bytes[16 ..< 16 + Nonce.length])
            
            assert(nonceBytes.count == Nonce.length)
            
            let hmac = Array(bytes.suffix(from: 16 + Nonce.length))
            
            assert(hmac.count == HMACSize)
            
            self.identifier = identifier
            self.nonce = Nonce(data: Data(bytes: nonceBytes))!
            self.authentication =  Data(bytes: hmac)
        }
        
        public func toBigEndian() -> Data {
            
            let bytes = identifier.toBigEndian().bytes + nonce.data.bytes + authentication.bytes
            
            assert(bytes.count == self.dynamicType.length)
            
            return Data(bytes: bytes)
        }
    }
    
    /// Used to encrypt and publish the list of keys on the device.
    ///
    /// - Note: Only owner and admin have access to key list.
    ///
    /// Key UUID + nonce + HMAC(key, nonce) (16 + 16 + 64 bytes) (write-only)
    public struct ListKeysCommand: AuthenticatedCharacteristic {
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "CF1F3211-8D4E-4717-B31A-2A100ABEF700")!)
        
        public static let length = SwiftFoundation.UUID.length + Nonce.length + HMACSize
        
        public let identifier: SwiftFoundation.UUID
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public init(identifier: SwiftFoundation.UUID, nonce: Nonce = Nonce(), key: KeyData) {
            
            self.identifier = identifier
            self.nonce = nonce
            self.authentication = HMAC(key: key, message: nonce)
            
            assert(authentication.bytes.count == HMACSize)
        }
        
        public init?(bigEndian: Data) {
            
            let bytes = bigEndian.bytes
            
            guard bytes.count == self.dynamicType.length
                else { return nil }
            
            let identifier = SwiftFoundation.UUID(bigEndian: Data(bytes: Array(bytes[0 ..< 16])))!
            
            let nonceBytes = Array(bytes[16 ..< 16 + Nonce.length])
            
            assert(nonceBytes.count == Nonce.length)
            
            let hmac = Array(bytes.suffix(from: 16 + Nonce.length))
            
            assert(hmac.count == HMACSize)
            
            self.identifier = identifier
            self.nonce = Nonce(data: Data(bytes: nonceBytes))!
            self.authentication =  Data(bytes: hmac)
        }
        
        public func toBigEndian() -> Data {
            
            let bytes = identifier.toBigEndian().bytes + nonce.data.bytes + authentication.bytes
            
            assert(bytes.count == self.dynamicType.length)
            
            return Data(bytes: bytes)
        }
    }
    
    /// Encrypted BSON of keys (e.g. `[UUID: String]`) (read-only)
    ///
    /// nonce + IV + HMAC(sharedSecret, nonce) + encrypt(sharedSecret, iv, childKey)
    public struct ListKeysValue: AuthenticatedCharacteristic {
        
        public static let UUID = BluetoothUUID.bit128(SwiftFoundation.UUID(rawValue: "D2F5F81C-C3DF-4626-9207-212029EA2F6F")!)
        
        public static let minimumLength = Nonce.length + IVSize + HMACSize + 1
        
        public let nonce: Nonce
        
        /// HMAC of key and nonce
        public let authentication: Data
        
        public let encryptedKeys: Data
        
        public let initializationVector: InitializationVector
        
        public init(nonce: Nonce = Nonce(), keys: [ListKeysValue.KeyEntry], key: KeyData) {
            
            // convert keys to BSON data
            let keysBSONArray = keys.map { $0.toBSON() }
            let document = BSON.Document(array: keysBSONArray)
            let bsonData = Data(bytes: document.bytes)
            
            // set authentication
            self.nonce = nonce
            self.authentication = HMAC(key: key, message: nonce)
            
            // encrypt
            let (encryptedKeys, iv) = encrypt(key: key.data, data: bsonData)
            
            self.initializationVector = iv
            self.encryptedKeys = encryptedKeys
        }
        
        public init?(bigEndian data: Data) {
            
            guard data.count >= ListKeysValue.minimumLength
                else { return nil }
            
            let nonceData = data[0 ..< Nonce.length]
            let ivData = data[Nonce.length ..< Nonce.length + IVSize]
            let authentication = data[Nonce.length + IVSize ..< Nonce.length + IVSize + HMACSize]
            let encryptedKeys = data.suffix(from: Nonce.length + IVSize + HMACSize)
            
            
        }
        
        public func toBigEndian() -> Data {
            
            return nonce.data + initializationVector.data + authentication + encryptedKeys
        }
        
        public func decrypt(key: KeyData) -> [KeyEntry]? {
            
            // make sure its authenticated
            guard authenticated(with: key)
                else { return nil }
            
            let decryptedData = CoreLock.decrypt(key: key.data, iv: initializationVector, data: encryptedKeys)
            
            let bson = BSON.Document(data: decryptedData.bytes)
            
            var keys = [KeyEntry]()
            
            for bsonValue in bson.arrayValue {
                
                guard let key = KeyEntry(BSONValue: bsonValue)
                    else { return nil }
                
                keys.append(key)
            }
            
            return keys
        }
        
        public struct KeyEntry {
            
            private enum DocumentIndex: Int {
                
                static let count = 3
                
                case identifier, name, date
            }
            
            public let identifier: UUID
            
            public let name: Key.Name
            
            public let date: Date
            
            public init?(BSONValue: BSON.Value) {
                
                guard let array = BSONValue.documentValue?.arrayValue
                    where array.count == DocumentIndex.count
                    else { return nil }
                
                let identifierBSON = array[DocumentIndex.identifier.rawValue]
                let nameBSON = array[DocumentIndex.name.rawValue]
                let dateBSON = array[DocumentIndex.date.rawValue]
                
                guard case let .binary(.generic, uuidData) = identifierBSON,
                    let identifier = SwiftFoundation.UUID(bigEndian: Data(bytes: uuidData)),
                    let nameString = nameBSON.stringValue,
                    let name = Key.Name(rawValue: nameString),
                    let dateDouble = dateBSON.doubleValue
                    else { return nil }
                
                self.identifier = identifier
                self.name = name
                self.date = Date(timeIntervalSince1970: dateDouble)
            }
            
            public func toBSON() -> BSON.Value {
                
                let bsonArray = [BSON.Value.binary(subtype: .generic, data: identifier.toBigEndian().bytes),
                                 BSON.Value.string(name.rawValue),
                                 BSON.Value.double(date.timeIntervalSince1970)]
                
                return .array(BSON.Document(array: bsonArray))
            }
        }
    }
    
    public struct RemoveKey {
        
        
    }
}

// MARK: - Extension

public extension SwiftFoundation.UUID {
    
    static var length: Int { return 16 }
    
    init?(bigEndian: Data) {
        
        var bytes = bigEndian.bytes
        
        guard bytes.count == SwiftFoundation.UUID.length
            else { return nil }
        
        if isBigEndian == false {
            
            bytes.reverse()
        }
        
        self.init(data: Data(bytes: bytes))
    }
    
    func toBigEndian() -> Data {
        
        let bigEndianUUIDBytes = isBigEndian ? self.toData().bytes : self.toData().bytes.reversed()
        
        return Data(bytes: bigEndianUUIDBytes)
    }
}
