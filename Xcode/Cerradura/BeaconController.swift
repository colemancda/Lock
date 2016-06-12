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
    
    private lazy var locationManager: CLLocationManager = {
        
        let location = CLLocationManager()
        
        location.delegate = self
        
        return location
    }()
    
    /// Starts monitoring.
    func start() {
        
        locationManager.requestAlwaysAuthorization()
        
        locationManager.startMonitoring(for: BeaconController.region)
    }
    
    func stop() {
        
        locationManager.stopMonitoring(for: BeaconController.region)
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
        
        if state == .inside {
            
            // show notification on user screen
            
            let notification = UILocalNotification()
            
            notification.alertTitle = "Unlock Door"
            
            notification.category = LockCategory
            
            UIApplication.shared().presentLocalNotificationNow(notification)
        }
    }
}

// MARK: - Private 

let BeaconIdentifier = "LockBeacon"

let UnlockActionIdentifier = "UnlockAction"

let UnlockNotification = "UnlockNotification"

let LockCategory = "LockCategory"
