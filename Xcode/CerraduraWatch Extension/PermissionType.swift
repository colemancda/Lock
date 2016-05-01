//
//  PermissionType.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 5/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

/// A key's permission type. 
public enum PermissionType: UInt8 {
    
    case owner
    case admin
    case anytime
    case scheduled
}