//
//  Random.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CryptoSwift

/// Generate random data with the specified size. 
func random(_ size: Int) -> Data {
    
    let bytes = AES.randomIV(size)
    
    return Data(byteValue: bytes)
}