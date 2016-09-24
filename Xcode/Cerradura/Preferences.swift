//
//  Preferences.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/3/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation

final class Preferences {
    
    static let shared = Preferences()
    
    let userDefaults = UserDefaults.standard
    
    // MARK: 
    
    var isAppInstalled: Bool {
        
        get { return userDefaults.bool(forKey: Key.isAppInstalled.rawValue) }
        
        set { userDefaults.set(newValue, forKey: Key.isAppInstalled.rawValue) }
    }
}

// MARK: - Keys

extension Preferences {
    
    enum Key: String {
        
        case isAppInstalled
    }
}
