//
//  AppDelegate.swift
//  Cerradura
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import WatchConnectivity
import CoreSpotlight
import SwiftFoundation
import CoreLock

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let shared = UIApplication.shared().delegate as! AppDelegate

    var window: UIWindow?
    
    var active = true
        
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
                
                //WatchController.shared.log = { print("WatchController: " + $0) }
                
                //WatchController.shared.activate()
            }
        }
        
        // iBeacon
        BeaconController.shared.log = { print("BeaconController: " + $0) }
        BeaconController.shared.start()
        
        // Core Spotlight
        if #available(iOS 9.0, *) {
            
            if CSSearchableIndex.isIndexingAvailable() {
                
                UpdateSpotlight() { (error) in
                    
                    print("Updated SpotLight index")
                    
                    if let error = error { print("Spotlight Error: ", error) }
                }
                
                SpotlightController.shared.log = { print("SpotlightController: " + $0) }
                
                try! SpotlightController.shared.startObserving()
            }
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
        active = false
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        //state = .background
        active = false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        //state = .foreground
        active = true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        active = true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        //BeaconController.shared.stop()
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> ()) -> Bool {
        
        print("Continue activity \(userActivity.activityType)")
        
        if #available(iOS 9.0, *) {
            
            guard userActivity.activityType == CSSearchableItemActionType
                else { return false }
            
            guard let identifierString = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                let identifier = SwiftFoundation.UUID(rawValue: identifierString)
                else { return false }
            
            guard let lock = Store.shared[identifier]
                else { return false }
            
            print("Selected lock \(lock.identifier) from CoreSpotlight")
            
            async {
                
                do {
                    var foundLock = LockManager.shared[lock.identifier]
                    
                    // scan if not prevously found
                    if foundLock == nil {
                        
                        try LockManager.shared.scan()
                        
                        foundLock = LockManager.shared[lock.identifier]
                    }
                    
                    guard foundLock != nil else { mainQueue { self.window?.rootViewController?.showErrorAlert("Could not unlock. Not in range.") }; return }
                    
                    // wait until other scanning completes
                    while LockManager.shared.scanning.value {
                        
                        sleep(1)
                    }
                    
                    try LockManager.shared.unlock(lock.identifier, key: lock.key.data)
                }
                
                catch { mainQueue { self.window?.rootViewController?.showErrorAlert("Could not unlock. \(error)") }; return }
            }
            
            return true
            
        } else {
            
            return false
        }
    }
}

/** Version of the app. */
public let AppVersion = NSBundle.main().infoDictionary!["CFBundleShortVersionString"] as! String

/** Build of the app. */
public let AppBuild = NSBundle.main().infoDictionary!["CFBundleVersion"] as! String

