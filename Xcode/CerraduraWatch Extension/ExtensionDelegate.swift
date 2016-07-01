//
//  ExtensionDelegate.swift
//  CerraduraWatch Extension
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import WatchKit

final class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        
        // print app info
        print("Launching Cerradura Watch v\(AppVersion) Build \(AppBuild)")
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

}

@inline(__always)
func mainQueue(_ block: () -> ()) {
    
    OperationQueue.main().addOperation(block)
}

/** Version of the app. */
public let AppVersion = Bundle.main().infoDictionary!["CFBundleShortVersionString"] as! String

/** Build of the app. */
public let AppBuild = Bundle.main().infoDictionary!["CFBundleVersion"] as! String


