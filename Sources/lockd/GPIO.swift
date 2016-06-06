//
//  GPIO.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 6/5/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
    import Glibc
#elseif os(OSX)
    import Darwin.C
#endif

private let LockPin: Int = {
    
    let gpio = 6
    
    system("echo \"\(6)\" > /sys/class/gpio/export")
    system("echo \"out\" > /sys/class/gpio/gpio\(gpio)/direction")
    
    return gpio
}()


func UnlockIO() {
    
    #if arch(arm)
        
    system("echo \"\(1)\" > /sys/class/gpio/gpio\(LockPin)/value")
        
    sleep(1)
        
    system("echo \"\(0)\" > /sys/class/gpio/gpio\(LockPin)/value")
    
    #else
        
    print("No GPIO on this hardware")
    
    #endif
}
