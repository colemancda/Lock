//
//  HMAC.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CryptoSwift

/// Performs HMAC with the specified key and message.
public func HMAC(key: Key, message: Nonce) -> Data {
    
    let hmac = try! Authenticator.HMAC(key: key.data.byteValue, variant: .sha512).authenticate(message.data.byteValue)
    
    return Data(byteValue: hmac)
}