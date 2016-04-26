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
    
    static let allTests: [(String, GATTProfileTests -> () throws -> Void)] = [("testLockIdentifier", testLockIdentifier), ("testLockSetup", testLockSetup), ("testUnlock", testUnlock)]
    
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
        
        let request = requestType.init(value: key, nonce: nonce)
        
        let requestData = request.toBigEndian()
        
        guard let deserialized = requestType.init(bigEndian: requestData)
            else { XCTFail(); return }
        
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
        
        let request = requestType.init(nonce: nonce, key: key)
        
        let requestData = request.toBigEndian()
        
        guard let deserialized = requestType.init(bigEndian: requestData)
            else { XCTFail(); return }
        
        XCTAssert(deserialized.nonce == nonce)
        XCTAssert(deserialized.authenticated(with: key))
        XCTAssert(deserialized.authenticated(with: KeyData()) == false)
    }
    
    func testShareKey() {
        
        let parentRequestType = LockService.NewKeyParentSharedSecret.self
        
        let weekdays = Permission.Schedule.Weekdays.init(sunday: false,
                                                         monday: true,
                                                         tuesday: true,
                                                         wednesday: true,
                                                         thursday: true,
                                                         friday: true,
                                                         saturday: false)
        
        let date = Date(sinceReferenceDate: TimeInterval(Int(TimeIntervalSinceReferenceDate() + (60 * 60))))
        
        let schedule = Permission.Schedule(expiry: date, weekdays: weekdays)
        
        let permission = Permission.scheduled(schedule)
        
        let sharedSecret = SharedSecret()
        
        let parentKey = KeyData()
        
        let parentNonce = Nonce()
        
        let parentRequest = parentRequestType.init(nonce: parentNonce, sharedSecret: sharedSecret, parentKey: parentKey, permission: permission)
        
        let parentRequestData = parentRequest.toBigEndian()
        
        guard let parentDeserialized = parentRequestType.init(bigEndian: parentRequestData, parentKey: parentKey)
            else { XCTFail(); return }
        
        XCTAssert(parentDeserialized.nonce == parentNonce)
        XCTAssert(parentDeserialized.authenticated(with: parentKey))
        XCTAssert(parentDeserialized.authenticated(with: KeyData()) == false)
        XCTAssert(parentDeserialized.permission == permission, "\(parentDeserialized.permission) == \(permission)")
        XCTAssert(parentDeserialized.parentKey == parentKey)
        XCTAssert(parentDeserialized.sharedSecret == sharedSecret, "\(parentDeserialized.sharedSecret.toData().byteValue) == \(sharedSecret.toData().byteValue)")
        
    }
}
