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
import CoreLock
import GATT

final class NearLockViewController: UIViewController {
    
    // MARK: - Properties
    
    private lazy var central: CBCentralManager = CBCentralManager(delegate: unsafeBitCast(self, to: CBCentralManagerDelegate.self), queue: self.queue)
    
    private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", nil)
    
    private var scanResults = [CBPeripheral]()
    
    private var discoveredLockPeripheral: CBPeripheral?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central.state
    }
    
    // MARK: - Methods
    
    private func bluetoothDisabled() {
        
        print("Bluetooth disabled")
        
        // update UI
    }
    
    private func startScan() {
        
        print("Starting scan")
        
        discoveredLockPeripheral = nil
        
        scanResults = []
        
        central.scanForPeripherals(withServices: nil, options: nil)
        
        dispatch_async(queue) {
            
            sleep(5)
            
            self.central.stopScan()
            
            print("Stopped scanning")
            
            for peripheral in self.scanResults {
                
                self.central.connect(peripheral, options: nil)
            }
        }
        
        // update UI
    }
    
    private func foundLock(peripheral: CBPeripheral) {
        
        print("Found lock peripheral \(peripheral.identifier.uuidString)")
        
        self.discoveredLockPeripheral = peripheral
        
        // update UI
    }
    
    // MARK: - CBCentralManagerDelegate
    
    @objc func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        print("Central State: \(central.state == .poweredOn ? "Powered On" : "\(central.state.rawValue)")")
        
        switch central.state {
            
        case .poweredOff, .unknown, .resetting, .unsupported, .unauthorized:
            
            bluetoothDisabled()
            
        case .poweredOn:
            
            startScan()
        }
    }
    
    @objc func centralManager(_ central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        print("Discovered peripheral \(peripheral.identifier.uuidString)")
        
        scanResults.append(peripheral)
    }
    
    @objc func centralManager(_ central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
        print("Connected to peripheral \(peripheral.identifier.uuidString)")
        
        peripheral.delegate = unsafeBitCast(self, to: CBPeripheralDelegate.self)
        
        peripheral.discoverServices(nil)
    }
    
    // MARK: - CBPeripheralDelegate
    
    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        guard discoveredLockPeripheral == nil else { return }
        
        if let error = error {
            
            print("\(error.localizedDescription)")
            return
        }
        
        print("Discovered services of peripheral \(peripheral.identifier.uuidString)")
        
        let services: [CBService] = peripheral.services ?? []
        
        if services.contains({ $0.uuid == LockProfile.LockService.UUID.toFoundation() }) {
            
            foundLock(peripheral: peripheral)
            return
        }
    }
}
