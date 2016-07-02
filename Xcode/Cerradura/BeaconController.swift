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
        
        let region = CLBeaconRegion(proximityUUID: LockBeaconUUID, major: 0, minor: 0, identifier: BeaconIdentifier)
        
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
    
    @objc(locationManager:didStartMonitoringForRegion:)
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        
        log?("Started iBeacon monitoring")
        
        
    }
    
    @objc(locationManager:monitoringDidFailForRegion:withError:)
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: NSError) {
        
        log?("Could not start iBeacon monitoring. (\(error))")
    }
    
    @objc(locationManager:didEnterRegion:)
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        
        log?("Did enter region")
        
        
    }
    
    @objc(locationManager:didExitRegion:)
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        
        log?("Did exit region")
    }
    
    @objc(locationManager:didDetermineState:forRegion:)
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        
        log?("State \(state.rawValue) for region")
        
        regionState = state
        
        
        // do { try LockManager.shared.scan() }
        // catch { print("Error scanning: \(error)") }
        
    }
}

// MARK: - Private

let BeaconIdentifier = "LockBeacon"

let UnlockActionIdentifier = "UnlockAction"

let UnlockNotification = "UnlockNotification"

let LockCategory = "LockCategory"
