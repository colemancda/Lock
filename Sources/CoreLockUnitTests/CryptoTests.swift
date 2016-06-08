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
    
    static let allTests: [(String, (CryptoTests) -> () throws -> Void)] = [("testHMAC", testHMAC), ("testEncrypt", testEncrypt), ("testFailEncrypt", testFailEncrypt), ("testEncryptKeyData", testEncryptKeyData), ("testEncryptChildKeyData", testEncryptChildKeyData)]
    
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
        
        print("Encrypted key is \(encryptedData.byteValue.count) bytes")
        
        let decryptedData = decrypt(key: salt.data, iv: iv, data: encryptedData)
        
        XCTAssert(decryptedData == key.data)
    }
    
    func testEncryptSharedSecret() {
        
        let parentKey = KeyData()
        
        let sharedSecret = SharedSecret()
        
        print("Shared Secret: \(sharedSecret.toData().byteValue)")
        
        let (encryptedData, iv) = encrypt(key: parentKey.data, data: sharedSecret.toData())
        
        print("Encrypted shared secret is \(encryptedData.byteValue.count) bytes")
        
        let decryptedData = decrypt(key: parentKey.data, iv: iv, data: encryptedData)
        
        XCTAssert(decryptedData == sharedSecret.toData())
    }
    
    func testEncryptChildKeyData() {
        
        let childKey = KeyData()
        
        let sharedSecret = SharedSecret()
        
        let sharedSecretKey = sharedSecret.toKeyData()
        
        let (encryptedData, iv) = encrypt(key: sharedSecretKey.data, data: childKey.data)
        
        print("Encrypted Child Key (4 repetitions) is \(encryptedData.byteValue.count) bytes")
        
        let decryptedData = decrypt(key: sharedSecretKey.data, iv: iv, data: encryptedData)
        
        XCTAssert(decryptedData == childKey.data)
    }
}
