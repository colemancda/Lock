//
//  AppDelegate.swift
//  Cerradura
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreLock
import WatchConnectivity

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    @objc(application:didFinishLaunchingWithOptions:)
    func application(_ application: UIApplication, didFinishLaunchingWithOptions didFinishLaunchingWithLaunchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        // print app info
        print("Launching Cerradura v\(AppVersion) Build \(AppBuild)")
        
        // add NSPersistentStore to Cerradura.Store
        try! LoadPersistentStore()
        
        LockManager.shared.log = { print("LockManager: " + $0) }
        
        // Apple Watch support
        if #available(iOS 9.3, *) {
            
            if WCSession.isSupported() {
                
                WatchController.shared.activate()
            }
        }
                        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

func mainQueue(_ block: () -> ()) {
    
    NSOperationQueue.main().addOperation(block)
}

/** Version of the app. */
public let AppVersion = NSBundle.main().infoDictionary!["CFBundleShortVersionString"] as! String

/** Build of the app. */
public let AppBuild = NSBundle.main().infoDictionary!["CFBundleVersion"] as! String
