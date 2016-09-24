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
    
    // MARK: - Properties
    
    static let region: CLBeaconRegion = {
        
        let region = CLBeaconRegion(proximityUUID: LockBeaconUUID, major: 0, minor: 0, identifier: BeaconIdentifier)
        
        region.notifyEntryStateOnDisplay = true
        
        return region
    }()
    
    var log: ((String) -> ())?
    
    private(set) var regionState: CLRegionState = .unknown
    
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
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        
        log?("Started iBeacon monitoring")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        
        log?("Could not start iBeacon monitoring. (\(error))")
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        
        guard regionState != state else {
            
            log?("Region state: \(state.rawValue)")
            
            return
        }
        
        log?("Region state changed: \(state.rawValue)")
        
        // state changed
        regionState = state
        
        /*
        if state == .inside {
            
            // dont scan if already scanning
            guard LockManager.shared.scanning.value == false
                && LockManager.shared.state.value == .poweredOn
                else { return }
            
            async {
                
                do { try LockManager.shared.scan(duration: 2) }
                
                catch { self.log?("Scan failed: \(error)") }
            }
            
        } else {
            
            LockManager.shared.clear()
        }
        */
    }
    
    /*
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        
        log?("Did enter region")
        
        
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        
        log?("Did exit region")
    }*/
    
}

// MARK: - Private

let BeaconIdentifier = "LockBeacon"

let UnlockActionIdentifier = "UnlockAction"

let UnlockNotification = "UnlockNotification"

let LockCategory = "LockCategory"
