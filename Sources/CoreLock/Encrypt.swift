//
//  Encrypt.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CryptoSwift

/// Encrypt data
public func encrypt(key: Data, data: Data) -> (encrypted: Data, IV: Data) {
    
    let iv = random(AES.blockSize)
    
    let crypto = try! AES(key: key.byteValue, iv: iv.byteValue)
    
    let byteValue = try! crypto.encrypt(data.byteValue)
    
    return (Data(byteValue: byteValue), iv)
}

/// Decrypt data
public func decrypt(key: Data, IV: Data, data: Data) -> Data {
    
    assert(IV.byteValue.count == AES.blockSize)
    
    let crypto = try! AES(key: key.byteValue, iv: IV.byteValue)
    
    let byteValue = try! crypto.decrypt(data.byteValue)
    
    return Data(byteValue: byteValue)
}