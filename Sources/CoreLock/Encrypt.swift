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
public func Encrypt(key: Data, data: Data) -> Data {
    
    let crypto = try! AES(key: key.byteValue)
    
    let byteValue = try! crypto.encrypt(data.byteValue)
    
    return Data(byteValue: byteValue)
}

/// Decrypt data
public func Decrypt(key: Data, data: Data) -> Data {
    
    let crypto = try! AES(key: key.byteValue)
    
    let byteValue = try! crypto.decrypt(data.byteValue)
    
    return Data(byteValue: byteValue)
}