//
//  BeaconController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 6/12/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock
import CoreLocation
import UIKit

final class BeaconController: NSObject, CLLocationManagerDelegate {
    
    static let shared = BeaconController()
    
    static let region: CLBeaconRegion = {
        
        let region = CLBeaconRegion(proximityUUID: LockBeaconUUID.toFoundation(), major: 0, minor: 0, identifier: BeaconIdentifier)
        
        region.notifyEntryStateOnDisplay = true
        
        return region
    }()
    
    var log: ((String) -> ())?
    
    var regionState: CLRegionState = .unknown
    
    var beaconLockScreenNotification: UILocalNotification?
    
    private lazy var locationManager: CLLocationManager = {
        
        let location = CLLocationManager()
        
        location.delegate = self
        
        return location
    }()
    
    // MARK: - Methods
    
    /// Starts monitoring.
    func start() {
        
        locationManager.requestAlwaysAuthorization()
        
        locationManager.startMonitoring(for: BeaconController.region)
    }
    
    func stop() {
        
        locationManager.stopMonitoring(for: BeaconController.region)
    }
    
    func unlockFromNotification() {
        
        self.beaconLockScreenNotification = nil
        
        var foundLock: LockManager.Lock!
        
        // scan for current lock
        do {
            guard let lock = try LockManager.shared.scan()
                else { print("Could not find lock"); return }
            
            foundLock = lock
        }
            
        catch { print("Error connecting to current lock: \(error)"); return }
        
        // make sure you can unlock
        guard let lockCache = Store.shared[foundLock.UUID]
            else { print("Cannot unlock, permission denied") ;return }
        
        if case let .scheduled(schedule) = lockCache.key.permission {
            
            guard schedule.valid() else { return }
        }
        
        do { try LockManager.shared.unlock(lock: foundLock, key: lockCache.key.data) }
            
        catch { print("Could not unlock: \(error)") }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        
        log?("Started iBeacon monitoring")
        
        
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: NSError) {
        
        log?("Could not start iBeacon monitoring. (\(error))")
    }
    
    func locationManager(_ manager: CLLocationManager, didEnter region: CLRegion) {
        
        log?("Did enter region")
        
        
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        
        log?("Did exit region")
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        
        log?("State \(state.rawValue) for region")
        
        regionState = state
        
        switch state {
            
        case .inside:
            
            if let previousNotification = beaconLockScreenNotification {
                
                UIApplication.shared().cancel(previousNotification)
                
                beaconLockScreenNotification = nil
            }
            
            // show unlock notification if in background
            
            guard AppDelegate.shared.active == false
                else { return }
            
            // show notification on user screen
            
            let notification = UILocalNotification()
            
            notification.alertBody = "Unlock Door"
            
            notification.category = LockCategory
            
            UIApplication.shared().presentLocalNotificationNow(notification)
            
            beaconLockScreenNotification = notification
            
        case .outside, .unknown:
            
            if let previousNotification = beaconLockScreenNotification {
                
                UIApplication.shared().cancel(previousNotification)
                
                beaconLockScreenNotification = nil
            }
        }
    }
}

// MARK: - Private 

let BeaconIdentifier = "LockBeacon"

let UnlockActionIdentifier = "UnlockAction"

let UnlockNotification = "UnlockNotification"

let LockCategory = "LockCategory"
