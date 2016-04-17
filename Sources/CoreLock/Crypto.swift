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
public func HMAC(key: KeyData, message: Nonce) -> Data {
    
    let hmac = try! Authenticator.HMAC(key: key.data.byteValue, variant: .sha512).authenticate(message.data.byteValue)
    
    assert(hmac.count == HMACSize)
    
    return Data(byteValue: hmac)
}

let IVSize = AES.blockSize

/// Encrypt data
public func encrypt(key: Data, data: Data) -> (encrypted: Data, iv: InitializationVector) {
    
    let iv = InitializationVector()
    
    let crypto = try! AES(key: key.byteValue, iv: iv.data.byteValue)
    
    let byteValue = try! crypto.encrypt(data.byteValue)
    
    return (Data(byteValue: byteValue), iv)
}

/// Decrypt data
public func decrypt(key: Data, iv: InitializationVector, data: Data) -> Data {
    
    assert(iv.data.byteValue.count == IVSize)
    
    let crypto = try! AES(key: key.byteValue, iv: iv.data.byteValue)
    
    let byteValue = try! crypto.decrypt(data.byteValue)
    
    return Data(byteValue: byteValue)
}
