//
//  Model.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/17/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

/// Lock hardware model. 
public enum Model: UInt8 {
    
    case orangePiOne = 1
}

public extension Model {
    
    var name: String {
        
        switch self {
        case .orangePiOne: return "Classic"
        }
    }
}
