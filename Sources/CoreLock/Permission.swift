//
//  Permission.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/20/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

/// A Key's permission level.
public enum Permission {
    
    /// This key belongs to the owner of the lock and has unlimited rights.
    case Owner
    
    /// This key can create new keys, and has anytime access. 
    case Admin
    
    /// This key has anytime access.
    case Anytime
    
    /// This key has scheduled access.
    case Limited
}