//
//  CryptoMessage.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

/// HMAC Message
public struct CryptoMessage {
    
    public let length = Nonce.length + 64
    
    public let nonce: Nonce
    
    public let timestamp: Int64
    
    public init(nonce: Nonce = Nonce(), timestamp: Int64 = Int64(Date().since1970)) {
        
        self.nonce = nonce
        self.timestamp = timestamp
    }
}