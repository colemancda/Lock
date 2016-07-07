//
//  Status.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

/// Lock status
public enum Status: UInt8 {
    
    /// Initial Status
    case setup
    
    /// Idle / Unlock Mode
    case unlock
    
    /// New Key being added to database.
    case newKey
    
    /// The lock is being updated.
    case update
}

// MARK: - Accessors

public extension Status {
    
    var canUnlock: Bool {
        
        switch self {
            
        case .setup: return false
            
        case .unlock, .newKey, .update: return true
        }
    }
    
    var canUpdate: Bool {
        
        switch self {
            
        case .setup, .unlock: return true
            
        case .newKey, .update: return false
        }
    }
    
    var canCreateNewKey: Bool {
        
        switch self {
            
        case .setup, .unlock: return true
            
        case .newKey, .update: return false
        }
    }
    
    var canEnableHomeKit: Bool {
        
        switch self {
            
        case .setup, .unlock: return true
            
        case .newKey, .update: return false
        }
    }
}

// MARK: - DataConvertible

extension Status: DataConvertible {
    
    public init?(data: Data) {
        
        guard data.bytes.count == 1
            else { return nil }
        
        self.init(rawValue: data.bytes[0])
    }
    
    public func toData() -> Data {
        
        return Data(bytes: [rawValue])
    }
}
