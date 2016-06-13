//
//  Store.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 6/13/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock
import KeychainAccess

/// Store for saving and retrieving lock keys.
final class Store {
    
    static let shared = Store()
    
    private let keychain = Keychain(accessGroup: AppGroup)
    
    /// Remove the specified key / lock pair from the database, along with its cached info.
    func remove(_ UUID: SwiftFoundation.UUID) {
        
        // remove from Keychain
        try! keychain.remove(key: UUID.rawValue)
    }
    
    /// Subscript to get key.
    subscript (key UUID:  SwiftFoundation.UUID) -> KeyData? {
        
        guard let data = try! keychain.getData(key: UUID.rawValue)
            else { return nil }
        
        return KeyData(data: Data(foundation: data))
    }
}