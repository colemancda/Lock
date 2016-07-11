//
//  CryptoTests.swift
//  CoreLockTests
//
//  Created by Alsey Coleman Miller on 4/17/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import XCTest
import SwiftFoundation
import CoreLock

final class CryptoTests: XCTestCase {
    
    static let allTests: [(String, (CryptoTests) -> () throws -> Void)] = [("testHMAC", testHMAC), ("testEncrypt", testEncrypt), ("testFailEncrypt", testFailEncrypt), ("testEncryptKeyData", testEncryptKeyData)]
    
    func testHMAC() {
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let hmac = HMAC(key: key, message: nonce)
        
        XCTAssert(hmac == HMAC(key: key, message: nonce))
    }
    
    func testEncrypt() {
        
        let key = KeyData()
        
        let nonce = Nonce()
        
        let (encryptedData, iv) = encrypt(key: key.data, data: nonce.data)
        
        let decryptedData = decrypt(key: key.data, iv: iv, data: encryptedData)
        
        XCTAssert(nonce.data == decryptedData)
    }
    
    func testFailEncrypt() {
        
        let key = KeyData()
        
        let key2 = KeyData()
        
        let nonce = Nonce()
        
        let (encryptedData, iv) = encrypt(key: key.data, data: nonce.data)
        
        let decryptedData = decrypt(key: key2.data, iv: iv, data: encryptedData)
        
        XCTAssert(nonce.data != decryptedData)
    }
    
    func testEncryptKeyData() {
        
        let key = KeyData()
        
        let salt = KeyData()
        
        let (encryptedData, iv) = encrypt(key: salt.data, data: key.data)
        
        print("Encrypted key is \(encryptedData.bytes.count) bytes")
        
        let decryptedData = decrypt(key: salt.data, iv: iv, data: encryptedData)
        
        XCTAssert(decryptedData == key.data)
    }
}
