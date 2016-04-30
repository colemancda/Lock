//
//  Central.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(OSX) || os(iOS) || os(watchOS)
    
    import SwiftFoundation
    import GATT
    import CoreBluetooth
    
    public final class Central {
        
        // MARK: - Initialization
        
        public static let shared: Central = {
            
            let central = Central()
            
            // initialize lazy value
            let _ = central.internalManager.state
            
            // start scanning
            central.startScan()
            
            return central
        }()
        
        // MARK: - Properties
        
        public var log: (String -> ())? {
            
            get { return internalManager.log }
            
            set { internalManager.log = newValue }
        }
        
        public let scanDuration = 2
        
        public let foundLock = Observable<(peripheral: Peripheral, UUID: SwiftFoundation.UUID, status: Status, model: Model, version: UInt64)?>()
        
        public let state = Observable(CBCentralManagerState.unknown)
        
        // MARK: - Private Properties
        
        private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
        
        private lazy var internalManager: CentralManager = CentralManager()
        
        // MARK: - Methods
        
        /// Setup the connected lock
        func setup() {
            
            guard let lock = self.foundLock.value
                else { return }
            
            
        }
        
        // MARK: - Private Methods
        
        /// Perform a task on the internal queue.
        private func async(_ block: () -> ()) {
            
            dispatch_async(queue) { block() }
        }
        
        private func stateChanged(state: CBCentralManagerState) {
            
            if foundLock.value != nil { foundLock.value = nil }
            
            if state == .poweredOn {
                
                self.startScan()
            }
        }
        
        /// Internal method to be called to start the scanning.
        private func startScan() {
            
            log?("Scanning...")
            
            if foundLock.value != nil { foundLock.value = nil }
            
            async {
                
                while self.internalManager.state == .poweredOn && self.foundLock.value == nil {
                    
                    let foundDevices = self.internalManager.scan(duration: self.scanDuration)
                    
                    if foundDevices.count > 0 { self.log?("Found \(foundDevices.count) peripherals") }
                    
                    for peripheral in foundDevices {
                        
                        do { try self.internalManager.connect(to: peripheral) }
                            
                        catch { print("Cound not connect to \(peripheral.identifier) (\(error))"); continue }
                        
                        guard let services = try? self.internalManager.discoverServices(for: peripheral)
                            else { continue }
                        
                        // found lock
                        if services.contains({ $0.UUID == LockService.UUID }) {
                            
                            self.foundLock(peripheral: peripheral)
                            return
                        }
                    }
                }
            }
        }
        
        private func foundLock(peripheral: Peripheral) {
            
            log?("Found lock peripheral \(peripheral.identifier)")
            
            func foundLockError(_ error: String) {
                
                log?(error)
                
                startScan()
            }
            
            async { [weak self] in
                
                guard let controller = self else { return }
                
                do {
                    
                    // get lock status
                    
                    let characteristics = try controller.internalManager.discoverCharacteristics(for: LockService.UUID, peripheral: peripheral)
                    
                    guard characteristics.contains({ $0.UUID == LockService.Status.UUID })
                        else { foundLockError("Status characteristic not found"); return }
                    
                    let statusValue = try controller.internalManager.read(characteristic: LockService.Status.UUID, service: LockService.UUID, peripheral: peripheral)
                    
                    guard let status = LockService.Status.init(bigEndian: statusValue)
                        else { foundLockError("Invalid data for Lock status"); return }
                    
                    // get lock UUID
                    
                    guard characteristics.contains({ $0.UUID == LockService.Identifier.UUID })
                        else { foundLockError("Identifier characteristic not found"); return }
                    
                    let identifierValue = try controller.internalManager.read(characteristic: LockService.Identifier.UUID, service: LockService.UUID, peripheral: peripheral)
                    
                    guard let identifier = LockService.Identifier.init(bigEndian: identifierValue)
                        else { foundLockError("Invalid data for Lock identifier"); return }
                    
                    // get model
                    
                    let modelValue = try controller.internalManager.read(characteristic: LockService.Model.UUID, service: LockService.UUID, peripheral: peripheral)
                    
                    guard let model = LockService.Model.init(bigEndian: modelValue)
                        else { foundLockError("Invalid Model value"); return }
                    
                    // get version
                    
                    let versionValue = try controller.internalManager.read(characteristic: LockService.Version.UUID, service: LockService.UUID, peripheral: peripheral)
                    
                    guard let version = LockService.Version.init(bigEndian: versionValue)
                        else { foundLockError("Invalid Version value"); return }
                    
                    // validate other characteristics
                    
                    guard characteristics.contains({ $0.UUID == LockService.Setup.UUID })
                        else { foundLockError("Setup characteristic not found"); return }
                    
                    guard characteristics.contains({ $0.UUID == LockService.Unlock.UUID })
                        else { foundLockError("Unlock characteristic not found"); return }
                    
                    guard characteristics.contains({ $0.UUID == LockService.NewKeyParentSharedSecret.UUID })
                        else { foundLockError("New Key Parent characteristic not found"); return }
                    
                    guard characteristics.contains({ $0.UUID == LockService.NewKeyChildSharedSecret.UUID })
                        else { foundLockError("New Key Child characteristic not found"); return }
                    
                    guard characteristics.contains({ $0.UUID == LockService.NewKeyFinish.UUID })
                        else { foundLockError("New Key Confirmation characteristic not found"); return }
                    
                    controller.log?("Lock \((peripheral, identifier.value, status.value, model.value, version.value))")
                    
                    controller.foundLock.value = (peripheral, identifier.value, status.value, model.value, version.value)
                }
                    
                catch { foundLockError("\(error)"); return }
            }
        }
    }
    
#endif