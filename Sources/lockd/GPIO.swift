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

private let UnlockGPIO: GPIO = {
    
    let gpio = GPIO(sunXi: SunXiGPIO(letter: .A, pin: 6))
    
    gpio.direction = .OUT
    
    gpio.value = 1
    
    return gpio
}()

func UnlockIO() {
    
    #if arch(arm)
        
    UnlockGPIO.value = 0
        
    sleep(1)
        
    UnlockGPIO.value = 1
    
    #else
        
    print("No GPIO on this hardware")
    
    #endif
}
