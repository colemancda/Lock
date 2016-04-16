//
//  AppDelegate.swift
//  LockDaemon
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Cocoa
import GATT

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        let peripheral = PeripheralManager()
        
        
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        
        
    }


}

