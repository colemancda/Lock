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
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        let serialPort = "/dev/tty.usbmodem1421"
        
        let fd = open(serialPort, O_RDWR | O_NONBLOCK )
        
        assert(fd != -1)
        
        var bytes: [UInt8] = [1]
        
        let writtenBytes = write(fd, &bytes, bytes.count)
        
        assert(writtenBytes != -1)
        
        print("Starting Lock Daemon...")
        
        //LockController.shared
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        
        
    }


}

