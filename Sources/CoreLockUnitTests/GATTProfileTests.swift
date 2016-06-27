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
        }
        
        if isBigEndian {
            
            XCTAssert(LockService.Identifier.init(bigEndian: UUID.toData())?.value == UUID)
            
        } else {
            
            XCTAssert(LockService.Identifier.init(bigEndian: UUID.toData())?.value != UUID)
            
            /// correct data on little endian
            let correctedData = Data(byteValue: UUID.toData().byteValue.reversed())
            
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
        
        let parentKey = KeyData()
        
        let parentNonce = Nonce()
        
        let parentRequest = LockService.NewKeyParentSharedSecret.init(nonce: parentNonce, sharedSecret: sharedSecret, parentKey: parentKey, permission: permission)
        
        let parentRequestData = parentRequest.toBigEndian()
        
        guard let parentDeserialized = LockService.NewKeyParentSharedSecret.init(bigEndian: parentRequestData)
            else { XCTFail(); return }
        
        guard let decryptedSharedSecret = parentDeserialized.decrypt(key: parentKey)
            else { XCTFail(); return }
        
        XCTAssert(parentDeserialized.nonce == parentNonce)
        XCTAssert(parentDeserialized.authenticated(with: parentKey))
        XCTAssert(parentDeserialized.authenticated(with: KeyData()) == false)
        XCTAssert(parentDeserialized.permission == permission, "\(parentDeserialized.permission) == \(permission)")
        XCTAssert(decryptedSharedSecret == sharedSecret)
        
        let childRequestType = LockService.NewKeyChildSharedSecret.self
        
        let childNonce = Nonce()
        
        let newKey = Key(data: KeyData(), permission: permission)
        
        let childRequest = childRequestType.init(nonce: childNonce, sharedSecret: sharedSecret, newKey: newKey)
        
        let childRequestData = childRequest.toBigEndian()
        
        guard let childDeserialized = childRequestType.init(bigEndian: childRequestData)
            else { XCTFail(); return }
        
        guard let decryptedNewKey = childDeserialized.decrypt(sharedSecret: sharedSecret)
            else { XCTFail(); return }
        
        XCTAssert(childDeserialized.nonce == childNonce)
        XCTAssert(childDeserialized.authenticated(with: sharedSecret.toKeyData()))
        XCTAssert(childDeserialized.authenticated(with: KeyData()) == false)
        XCTAssert(childDeserialized.permission == permission)
        XCTAssert(decryptedNewKey == newKey)
    }
}
