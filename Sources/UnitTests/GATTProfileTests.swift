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
    
    static let allTests: [(String, GATTProfileTests -> () throws -> Void)] = [("testLockIdentifier", testLockIdentifier), ("testLockAction", testLockAction), ("testLockSetup", testLockSetup)]
    
    func testLockIdentifier() {
        
        let UUID = SwiftFoundation.UUID()
        
        let characteristic = LockProfile.LockService.Identifier.init(value: UUID)
        
        if isBigEndian {
            
            XCTAssert(characteristic.toBigEndian() == UUID.toData(),
                      "Serialized data should be the same on Big endian machines")
            
        } else {
            
            XCTAssert(characteristic.toBigEndian() != UUID.toData(),
                      "Serialized data should not be the same on little endian machines")
        }
        
        if isBigEndian {
            
            XCTAssert(LockProfile.LockService.Identifier.init(bigEndian: UUID.toData())?.value == UUID)
            
        } else {
            
            XCTAssert(LockProfile.LockService.Identifier.init(bigEndian: UUID.toData())?.value != UUID)
            
            /// correct data on little endian
            let correctedData = Data(byteValue: UUID.toData().byteValue.reversed())
            
            XCTAssert(LockProfile.LockService.Identifier.init(bigEndian: correctedData)?.value == UUID)
        }
    }
    
    func testLockAction() {
        
        // write action
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let action = Action.NewKey
        
        let actionRequest = LockProfile.LockService.Action(action: action, nonce: nonce, key: key)
        
        let requestData = actionRequest.toBigEndian()
        
        guard let deserialized = LockProfile.LockService.Action.init(bigEndian: requestData)
            else { XCTFail(); return }
        
        XCTAssert(deserialized.action == action)
        XCTAssert(deserialized.nonce == nonce)
        XCTAssert(deserialized.authenticated(with: key))
        XCTAssert(deserialized.authenticated(with: KeyData()) == false)
    }
    
    func testLockSetup() {
        
        // lock setup
        
        let requestType = LockProfile.SetupService.Key.self
        
        let key = KeyData()
        
        let request = requestType.init(value: key)
        
        let requestData = request.toBigEndian()
        
        guard let deserialized = requestType.init(bigEndian: requestData)
            else { XCTFail(); return }
        
        XCTAssert(deserialized.value == key)
    }
}
