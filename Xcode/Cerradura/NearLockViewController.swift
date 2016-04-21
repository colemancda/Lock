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
    
    private var lockUUID: SwiftFoundation.UUID?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central = CentralManager()
        
        central.log = { print("Central: " + $0) }
        
        central.stateChanged = stateChanged
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
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
        
        discoveredLockPeripheral = nil
        
        // update UI
    }
    
    private func startScan() {
        
        print("Starting scan")
        
        self.discoveredLockPeripheral = nil
        self.lockUUID = nil
        
        // update UI
        
        
        async { [weak self] in
            
            while self?.central.state == .poweredOn && self?.discoveredLockPeripheral == nil {
                
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
                        
                        controller.foundLock(peripheral: peripheral)
                        return
                    }
                }
            }
        }
    }
    
    private func foundLock(peripheral: Peripheral) {
        
        print("Found lock peripheral \(peripheral.identifier)")
        
        self.discoveredLockPeripheral = peripheral
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            var lockStatus: CoreLock.Status!
            
            var lockUUID: SwiftFoundation.UUID!
            
            do {
                
                // get lock status
                
                let services = try controller.central.discover(services: peripheral)
                
                guard services.contains({ $0.UUID == LockProfile.LockService.UUID })
                    else { controller.foundLockError("Lock service not found"); return }
                
                let characteristics = try controller.central.discover(characteristics: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard characteristics.contains({ $0.UUID == LockProfile.LockService.Status.UUID })
                    else { controller.foundLockError("Status characteristic not found"); return }
                
                let statusValue = try controller.central.read(characteristic: LockProfile.LockService.Status.UUID, service: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard let status = LockProfile.LockService.Status.init(bigEndian: statusValue)
                    else { controller.foundLockError("Invalid data for Lock status"); return }
                
                lockStatus = status.value
                
                // get lock UUID
                
                guard characteristics.contains({ $0.UUID == LockProfile.LockService.Identifier.UUID })
                    else { controller.foundLockError("Identifier characteristic not found"); return }
                
                let identifierValue = try controller.central.read(characteristic: LockProfile.LockService.Identifier.UUID, service: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard let identifier = LockProfile.LockService.Identifier.init(bigEndian: identifierValue)
                    else { controller.foundLockError("Invalid data for Lock identifier"); return }
                
                lockUUID = identifier.value
            }
            
            catch { controller.foundLockError("\(error)"); return }
            
            print("Lock UUID: \(lockUUID)")
            print("Lock status: \(lockStatus)")
            
            mainQueue {
                
                switch lockStatus! {
                    
                case .setup:
                    
                    // setup UI
                    
                    break
                    
                case .unlock:
                    
                    // Unlock UI (if possible)
                    
                    break
                    
                case .newKey:
                    
                    // new key UI
                    
                    break
                    
                default: fatalError("not implemented")
                }
            }
        }
    }
    
    private func foundLockError(_ error: String) {
        
        print("Found lock error: " + error)
        
        // update UI
    }
}
