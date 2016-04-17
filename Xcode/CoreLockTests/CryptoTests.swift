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
    
    func testEncrypt() {
        
        let key = Key()
        
        let nonce = Nonce()
        
        let (encryptedData, iv) = encrypt(key: key.data, data: nonce.data)
        
        let decryptedData = decrypt(key: key.data, IV: iv, data: encryptedData)
        
        XCTAssert(nonce.data == decryptedData)
    }
    
    func testFailEncrypt() {
        
        let key = Key()
        
        let key2 = Key()
        
        let nonce = Nonce()
        
        let (encryptedData, iv) = encrypt(key: key.data, data: nonce.data)
        
        let decryptedData = decrypt(key: key2.data, IV: iv, data: encryptedData)
        
        XCTAssert(nonce.data != decryptedData)
    }
}
