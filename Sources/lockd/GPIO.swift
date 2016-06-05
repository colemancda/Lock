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

private let LockPin: GPIO = {
    
    let GPIOs = SwiftyGPIO.GPIOs(for: .RaspberryPi2)
    
    let gpio = GPIOs[.P4]!
    
    gpio.direction = .OUT
    
    return gpio
}()


func UnlockIO() {
    
    #if arch(arm)
    
    LockPin.value = 1
    
    usleep(150 * 1000)
    
    LockPin.value = 0
    
    #else
        
    print("No GPIO on this hardware")
    
    #endif
}