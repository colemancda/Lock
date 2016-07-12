//
//  Command.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/3/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

struct Command {
    
    static let reboot = "reboot"
    
    static let updatePackageList = "apt-get update"
    
    static let updateLock = "apt-get install -q -y --force-yes lockd"
}
