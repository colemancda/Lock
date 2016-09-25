//
//  GATTProfileTests.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/17/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
import Glibc
import SwiftShims
#endif

import XCTest
import SwiftFoundation
import CoreLock

final class GATTProfileTests: XCTestCase {
    
    static let allTests: [(String, (GATTProfileTests) -> () throws -> Void)] = [("testLockIdentifier", testLockIdentifier), ("testVersion", testVersion), ("testPackageVersion", testPackageVersion), ("testLockSetup", testLockSetup), ("testUnlock", testUnlock), ("testNewChildKey", testNewChildKey), ("testHomeKitEnable", testHomeKitEnable), ("testUpdate", testUpdate), ("testListKeys", testListKeys), ("testRemoveKey", testRemoveKey)]
    
    func testLockIdentifier() {
        
        let UUID = SwiftFoundation.UUID()
        
        let characteristic = LockService.Identifier.init(value: UUID)
        
        if isBigEndian {
            
            XCTAssert(characteristic.toBigEndian() == UUID.toData(),
                      "Serialized data should be the same on Big endian machines")
            
        } else {
            
            XCTAssert(characteristic.toBigEndian() != UUID.toData(),
                      "Serialized data should not be the same on little endian machines")
            
            XCTAssert(characteristic.toBigEndian() == Data(bytes: UUID.toData().bytes.reversed()),
                      "Serialized data should not be the same on little endian machines")
        }
        
        if isBigEndian {
            
            XCTAssert(LockService.Identifier.init(bigEndian: UUID.toData())?.value == UUID)
            
        } else {
            
            XCTAssert(LockService.Identifier.init(bigEndian: UUID.toData())?.value != UUID)
            
            /// correct data on little endian
            let correctedData = Data(bytes: UUID.toData().bytes.reversed())
            
            XCTAssert(LockService.Identifier.init(bigEndian: correctedData)?.value == UUID)
        }
    }
    
    func testVersion() {
        
        #if os(macOS) || os(iOS)
        let random = arc4random()
        #elseif os(Linux)
        let random = _swift_stdlib_cxx11_mt19937()
        #endif
        
        let version = UInt64(random)
        
        let characteristic = LockService.Version.init(value: version)
        
        let data = characteristic.toBigEndian()
        
        guard let deserialized = LockService.Version.init(bigEndian: data)
            else { XCTFail(); return }
        
        XCTAssert(version == deserialized.value, "\(version) == \(deserialized.value)")
    }
    
    func testPackageVersion() {
        
        let version: (UInt16, UInt16, UInt16) = (1, 0, 0)
        
        let characteristic = LockService.PackageVersion.init(value: version)
        
        let data = characteristic.toBigEndian()
        
        guard let deserialized = LockService.PackageVersion.init(bigEndian: data)
            else { XCTFail(); return }
        
        XCTAssert(version == deserialized.value, "\(version) == \(deserialized.value)")
    }
    
    func testLockSetup() {
        
        // lock setup
        
        let requestType = LockService.Setup.self
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let identifier = UUID()
        
        let request = requestType.init(identifier: identifier, value: key, nonce: nonce)
        
        let requestData = request.toBigEndian()
        
        guard let deserialized = requestType.init(bigEndian: requestData)
            else { XCTFail(); return }
        
        XCTAssert(deserialized.identifier == identifier)
        XCTAssert(deserialized.value == key)
        XCTAssert(deserialized.nonce == nonce)
        XCTAssert(deserialized.authenticatedWithSalt())
        XCTAssert(deserialized.authenticated(with: KeyData()) == false)
    }
    
    func testUnlock() {
        
        // unlock command
        
        let requestType = LockService.Unlock.self
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let identifier = UUID()
        
        let request = requestType.init(identifier: identifier, nonce: nonce, key: key)
        
        let requestData = request.toBigEndian()
        
        guard let deserialized = requestType.init(bigEndian: requestData)
            else { XCTFail(); return }
        
        XCTAssert(deserialized.identifier == identifier)
        XCTAssert(deserialized.nonce == nonce)
        XCTAssert(deserialized.authenticated(with: key))
        XCTAssert(deserialized.authenticated(with: KeyData()) == false)
    }
    
    func testNewChildKey() {
        
        // parent
        
        let weekdays = Permission.Schedule.Weekdays.init(sunday: false,
                                                         monday: true,
                                                         tuesday: true,
                                                         wednesday: true,
                                                         thursday: true,
                                                         friday: true,
                                                         saturday: false)
        
        // expires in an hour
        let normalizedTimeInterval = TimeInterval(Int(Date.timeIntervalSinceReferenceDate))
        let expiry = Date(timeIntervalSinceReferenceDate: normalizedTimeInterval) + (60 * 60)
        
        let schedule = Permission.Schedule(expiry: expiry, weekdays: weekdays)
        
        let sharedSecret = KeyData()
        
        let parentKey = Key(identifier: UUID(), data: KeyData(), permission: .owner)
        
        let newKey = Key(identifier: UUID(), name: Key.Name(rawValue: "New Key")!, data: KeyData(), permission: Permission.scheduled(schedule))
        
        let parentRequest = LockService.NewKeyParent.init(sharedSecret: sharedSecret, parentKey: (parentKey.identifier, parentKey.data), childKey: (newKey.identifier, newKey.permission, newKey.name!))
        
        let parentRequestData = parentRequest.toBigEndian()
        
        let expectedSize = 16 + Nonce.length + IVSize + 48 + HMACSize + Permission.length + 16 + "New Key".toUTF8Data().count
        
        XCTAssert(parentRequestData.count == expectedSize, "\(parentRequestData.count) == \(expectedSize)")
        
        guard let parentDeserialized = LockService.NewKeyParent.init(bigEndian: parentRequestData)
            else { XCTFail(); return }
        
        guard let decryptedSharedSecret = parentDeserialized.decrypt(key: parentKey.data)
            else { XCTFail(); return }
        
        XCTAssert(parentDeserialized.parent == parentKey.identifier)
        XCTAssert(parentDeserialized.child == newKey.identifier)
        XCTAssert(parentDeserialized.name == newKey.name)
        XCTAssert(parentDeserialized.nonce == parentRequest.nonce)
        XCTAssert(parentDeserialized.permission == newKey.permission)
        XCTAssert(parentDeserialized.authenticated(with: parentKey.data))
        XCTAssert(parentDeserialized.authenticated(with: KeyData()) == false)
        XCTAssert(decryptedSharedSecret == sharedSecret)
        
        // child
        
        let childRequest = LockService.NewKeyChild.init(sharedSecret: sharedSecret, newKey: (newKey.identifier, newKey.data))
        
        let childRequestData = childRequest.toBigEndian()
        
        guard let childDeserialized = LockService.NewKeyChild.init(bigEndian: childRequestData)
            else { XCTFail(); return }
        
        guard let decryptedNewKey = childDeserialized.decrypt(sharedSecret: sharedSecret)
            else { XCTFail(); return }
        
        XCTAssert(childDeserialized.identifier == childRequest.identifier)
        XCTAssert(childDeserialized.nonce == childRequest.nonce)
        XCTAssert(childDeserialized.authenticated(with: sharedSecret))
        XCTAssert(childDeserialized.authenticated(with: KeyData()) == false)
        XCTAssert(decryptedNewKey == newKey.data)
    }
    
    func testHomeKitEnable() {
        
        // enable HomeKit
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let identifier = UUID()
        
        let request = LockService.HomeKitEnable.init(identifier: identifier, nonce: nonce, key: key)
        
        let requestData = request.toBigEndian()
        
        guard let deserialized = LockService.HomeKitEnable.init(bigEndian: requestData)
            else { XCTFail(); return }
        
        XCTAssert(deserialized.identifier == identifier)
        XCTAssert(deserialized.nonce == nonce)
        XCTAssert(deserialized.authenticated(with: key))
        XCTAssert(deserialized.authenticated(with: KeyData()) == false)
        XCTAssert(deserialized.enable == request.enable)
    }
    
    func testUpdate() {
        
        // lock update
        
        let requestType = LockService.Update.self
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let identifier = UUID()
        
        let request = requestType.init(identifier: identifier, nonce: nonce, key: key)
        
        let requestData = request.toBigEndian()
        
        guard let deserialized = requestType.init(bigEndian: requestData)
            else { XCTFail(); return }
        
        XCTAssert(deserialized.identifier == identifier)
        XCTAssert(deserialized.nonce == nonce)
        XCTAssert(deserialized.authenticated(with: key))
        XCTAssert(deserialized.authenticated(with: KeyData()) == false)
    }
    
    func testListKeys() {
        
        let key = KeyData()
        
        // list keys command
        
        let command = LockService.ListKeysCommand.init(identifier: UUID(), nonce: Nonce(), key: key)
        
        guard let deserializedCommand = LockService.ListKeysCommand.init(bigEndian: command.toBigEndian())
            else { XCTFail(); return }
        
        XCTAssert(deserializedCommand.identifier == command.identifier)
        XCTAssert(deserializedCommand.nonce == command.nonce)
        XCTAssert(deserializedCommand.authenticated(with: key))
        XCTAssert(deserializedCommand.authenticated(with: KeyData()) == false)
        
        // list keys value
        
        let keys = [LockService.ListKeysValue.KeyEntry.init(identifier: UUID(), name: Key.Name(rawValue: "My Key")!, date: Date(timeIntervalSinceReferenceDate: TimeInterval(Int(Date.timeIntervalSinceReferenceDate))), permission: .admin)]
        
        let keysValue = LockService.ListKeysValue.init(keys: keys, key: key)
        
        guard let deserializedValue = LockService.ListKeysValue.init(bigEndian: keysValue.toBigEndian())
            else { XCTFail(); return }
        
        guard let decryptedKeys = deserializedValue.decrypt(key: key)
            else { XCTFail(); return }
        
        XCTAssert(deserializedValue.nonce == keysValue.nonce)
        XCTAssert(deserializedValue.authenticated(with: key))
        XCTAssert(deserializedValue.authenticated(with: KeyData()) == false)
        XCTAssert(decryptedKeys == keys, "\(decryptedKeys) == \(keys)")
    }
    
    func testRemoveKey() {
        
        // lock setup
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let identifier = UUID()
        
        let removedKey = UUID()
        
        let request = LockService.RemoveKey.init(identifier: identifier, nonce: nonce, key: key, removedKey: removedKey)
        
        let requestData = request.toBigEndian()
        
        guard let deserialized = LockService.RemoveKey.init(bigEndian: requestData)
            else { XCTFail(); return }
        
        XCTAssert(deserialized.identifier == identifier)
        XCTAssert(deserialized.nonce == nonce)
        XCTAssert(deserialized.authenticated(with: key))
        XCTAssert(deserialized.authenticated(with: KeyData()) == false)
        XCTAssert(deserialized.removedKey == removedKey)
    }
}
