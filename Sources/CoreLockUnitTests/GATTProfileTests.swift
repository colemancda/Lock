//
//  GATTProfileTests.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/17/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import XCTest
import SwiftFoundation
import CoreLock

final class GATTProfileTests: XCTestCase {
    
    static let allTests: [(String, (GATTProfileTests) -> () throws -> Void)] = [("testLockIdentifier", testLockIdentifier), ("testLockSetup", testLockSetup), ("testUnlock", testUnlock), ("testNewChildKey", testNewChildKey)]
    
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
    
    func testLockSetup() {
        
        // lock setup
        
        let requestType = LockService.Setup.self
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let identifier = SwiftFoundation.UUID()
        
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
        
        // lock setup
        
        let requestType = LockService.Unlock.self
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let identifier = SwiftFoundation.UUID()
        
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
        
        let expiry = Date(sinceReferenceDate: TimeInterval(Int(TimeIntervalSinceReferenceDate() + (60 * 60))))
        
        let schedule = Permission.Schedule(expiry: expiry, weekdays: weekdays)
        
        let permission = Permission.scheduled(schedule)
        
        let sharedSecret = SharedSecret()
        
        let parentKeyIdentifier = SwiftFoundation.UUID()
        
        let parentKeyData = KeyData()
        
        let parentNonce = Nonce()
        
        let parentRequest = LockService.NewKeyParent.init(nonce: parentNonce, sharedSecret: sharedSecret, parentKey: (parentKeyIdentifier, parentKeyData), permission: permission)
        
        let parentRequestData = parentRequest.toBigEndian()
        
        guard let parentDeserialized = LockService.NewKeyParent.init(bigEndian: parentRequestData)
            else { XCTFail(); return }
        
        guard let decryptedSharedSecret = parentDeserialized.decrypt(key: parentKeyData)
            else { XCTFail(); return }
        
        XCTAssert(parentDeserialized.identifier == parentKeyIdentifier)
        XCTAssert(parentDeserialized.nonce == parentNonce)
        XCTAssert(parentDeserialized.authenticated(with: parentKeyData))
        XCTAssert(parentDeserialized.authenticated(with: KeyData()) == false)
        XCTAssert(parentDeserialized.permission == permission, "\(parentDeserialized.permission) == \(permission)")
        XCTAssert(decryptedSharedSecret == sharedSecret)
        
        // child
        
        let childNonce = Nonce()
        
        let newKey = Key(data: KeyData(), permission: permission)
        
        let childRequest = LockService.NewKeyChild.init(nonce: childNonce, sharedSecret: sharedSecret, newKey: newKey)
        
        let childRequestData = childRequest.toBigEndian()
        
        guard let childDeserialized = LockService.NewKeyChild.init(bigEndian: childRequestData)
            else { XCTFail(); return }
        
        guard let decryptedNewKey = childDeserialized.decrypt(sharedSecret: sharedSecret)
            else { XCTFail(); return }
        
        XCTAssert(childDeserialized.nonce == childNonce)
        XCTAssert(childDeserialized.authenticated(with: sharedSecret.toKeyData()))
        XCTAssert(childDeserialized.authenticated(with: KeyData()) == false)
        XCTAssert(childDeserialized.permission == permission)
        XCTAssert(decryptedNewKey.data == newKey.data)
        XCTAssert(decryptedNewKey.permission == newKey.permission)
        XCTAssert(decryptedNewKey.identifier == newKey.identifier)
        XCTAssert(decryptedNewKey == newKey)
        
        // finish
        
        let childKeyName = Key.Name(rawValue: "New Key")!
        
        let newKeyFinish = LockService.NewKeyFinish.init(name: childKeyName, key: newKey.data)
        
        let newKeyFinishData = newKeyFinish.toBigEndian()
        
        guard let newKeyFinishDeserialzed = LockService.NewKeyFinish.init(bigEndian: childRequestData)
            else { XCTFail(); return }
        
        
    }
}
