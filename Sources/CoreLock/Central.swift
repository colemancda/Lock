//
//  Central.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(OSX) || os(iOS) || os(watchOS)
    
    import Foundation
    import CoreBluetooth
    import SwiftFoundation
    
    public final class Central: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
        
        public static let shared: Central = {
            
            let central = Central()
            
            // initialize lazy value
            let _ = central.internalManager
            
            return central
        }()
        
        // MARK: - Properties
        
        public var log: (String -> ())?
        
        public var scanInterval: TimeInterval = 3
        
        public var connectionTimeout: TimeInterval = 5
        
        public let lock = Observable<(UUID: SwiftFoundation.UUID, status: Status, model: Model, version: UInt64)?>()
        
        public lazy var state = Observable(CBCentralManagerState.unknown)
        
        // MARK: - Private Properties
        
        private var foundLock: (peripheral: CBPeripheral, UUID: SwiftFoundation.UUID, status: Status, model: Model, version: UInt64)? {
            
            didSet {
                
                guard let foundLock = self.foundLock
                    else { lock.value = nil; return }
                
                lock.value = (UUID: foundLock.UUID, status: foundLock.status, foundLock.model, foundLock.version)
            }
        }
        
        private lazy var internalManager: CBCentralManager = CBCentralManager(delegate: self, queue: self.queue)
        
        private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
        
        private var finishScanTimer: NSTimer?
        
        private var connectTimer: NSTimer?
        
        private var scanPeripherals = [CBPeripheral]()
        
        // MARK: - Methods
        
        
        
        // MARK: - Private Methods
        
        @objc private func endScan() {
            
            finishScanTimer = nil
            
            internalManager.stopScan()
            
            log?("Scanned peripherals \(scanPeripherals.map({ $0.identifier.uuidString }))")
            
            for peripheral in scanPeripherals {
                
                peripheral.delegate = self
                
                internalManager.connect(peripheral, options: nil)
            }
            
            connectTimer = NSTimer.scheduledTimer(timeInterval: scanInterval, target: self, selector: #selector(endConnect), userInfo: nil, repeats: false)
        }
        
        @objc private func endConnect() {
            
            connectTimer = nil
            
            /// scan again
            guard scanPeripherals.contains({ $0.state == .connected }) else {
                
                internalManager.scanForPeripherals(withServices: nil, options: nil)
                
                finishScanTimer = NSTimer.scheduledTimer(timeInterval: scanInterval, target: self, selector: #selector(endScan), userInfo: nil, repeats: false)
                
                return
            }
            
            /// discover services of connected peripherals
            
            for peripheral in scanPeripherals {
                
                guard peripheral.state == .connected else { continue }
                
                peripheral.discoverServices(nil)
            }
        }
        
        // MARK: - CBCentralManagerDelegate
        
        public func centralManagerDidUpdateState(_ central: CBCentralManager) {
            
            log?("Did update state (\(central.state == .poweredOn ? "Powered On" : "\(central.state.rawValue)"))")
            
            /// reset found lock
            if foundLock != nil { foundLock = nil }
            
            state.value = central.state
            
            if central.state == .poweredOn {
                
                central.scanForPeripherals(withServices: nil, options: nil)
                
                finishScanTimer = NSTimer.scheduledTimer(timeInterval: scanInterval, target: self, selector: #selector(endScan), userInfo: nil, repeats: false)
            }
        }
        
        @objc(centralManager:didDiscoverPeripheral:advertisementData:RSSI:)
        public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : AnyObject], rssi RSSI: NSNumber) {
            
            log?("Discovered peripheral \(peripheral.identifier.uuidString) (\(RSSI))")
            
            scanPeripherals.append(peripheral)
        }
        
        @objc(centralManager:didConnectPeripheral:)
        public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            
            log?("Connected to peripheral \(peripheral.identifier.uuidString)")
        }
        
        // MARK: - CBPeripheralDelegate
        
        public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
            
            if let error = error {
                
                log?("Error discovering services (\(error))")
                
            } else {
                
                log?("Peripheral \(peripheral.identifier.uuidString) did discover \(peripheral.services?.count ?? 0) services")
            }
            
            guard let lockService = (peripheral.services ?? []).filter({ $0.uuid == LockService.UUID.toFoundation() }).first
                else { return }
            
            peripheral.discoverCharacteristics(nil, for: lockService)
        }
        
        @objc(peripheral:didDiscoverCharacteristicsForService:error:)
        public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: NSError?) {
            
            if let error = error {
                
                log?("Error discovering characteristics (\(error))")
                
            } else {
                
                log?("Peripheral \(peripheral.identifier.uuidString) did discover \(service.characteristics?.count ?? 0) characteristics for service \(service.uuid.uuidString)")
            }
            
            
        }
    }
    
#endif