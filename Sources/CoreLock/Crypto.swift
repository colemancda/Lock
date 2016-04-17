//
//  Crypto.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/17/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CryptoSwift

/// Generate random data with the specified size.
public func random(_ size: Int) -> Data {
    
    let bytes = AES.randomIV(size)
    
    return Data(byteValue: bytes)
}

public let HMACSize = 64

/// Performs HMAC with the specified key and message.
public func HMAC(key: Key, message: Nonce) -> Data {
    
    let hmac = try! Authenticator.HMAC(key: key.data.byteValue, variant: .sha512).authenticate(message.data.byteValue)
    
    assert(hmac.count == HMACSize)
    
    return Data(byteValue: hmac)
}

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
