//
//  NearLockViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/20/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth
import SwiftFoundation
import Bluetooth
import GATT
import CoreLock

final class NearLockViewController: UIViewController {
    
    // MARK: - Properties
    
    let scanDuration = 5
    
    var central: CentralManager!
    
    private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    private var discoveredLockPeripheral: Peripheral?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central = CentralManager()
        
        central.log = { print("Central: " + $0) }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        central.stateChanged = stateChanged
        
        if central.state == .poweredOn {
            
            startScan()
            
        } else {
            
            bluetoothDisabled()
        }
    }
    
    // MARK: - Private Methods
    
    /// Perform a task on the internal queue.
    private func async(_ block: () -> ()) {
        
        dispatch_async(queue) { block() }
    }
    
    private func stateChanged(state: CBCentralManagerState) {
        
        if state == .poweredOn {
            
            startScan()
            
        } else {
            
            bluetoothDisabled()
        }
    }
    
    private func bluetoothDisabled() {
        
        print("Bluetooth disabled")
        
        // update UI
    }
    
    private func startScan() {
        
        print("Starting scan")
        
        // update UI
        
        async { [weak self] in
            
            while self?.central.state == .poweredOn {
                
                guard let controller = self else { return }
                
                print("Scanning for \(controller.scanDuration) seconds")
                
                let foundDevices = controller.central.scan(duration: controller.scanDuration)
                
                print("Found \(foundDevices.count) peripherals")
                
                for peripheral in foundDevices {
                    
                    do { try controller.central.connect(peripheral) }
                        
                    catch { print("Cound not connect to \(peripheral.identifier) (\(error))"); continue }
                    
                    guard let services = try? controller.central.discover(services: peripheral)
                        else { continue }
                    
                    // found lock
                    if services.contains({ $0.UUID == LockProfile.LockService.UUID }) {
                        
                        print("Found lock peripheral \(peripheral.identifier)")
                        
                        return
                    }
                }
            }
        }
    }
}
