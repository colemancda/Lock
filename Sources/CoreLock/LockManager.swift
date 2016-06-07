//
//  LockManager.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(OSX) || os(iOS)
    
    import SwiftFoundation
    import Bluetooth
    import GATT
    import CoreBluetooth
    
    public final class LockManager {
        
        public typealias Error = LockManagerError
        
        // MARK: - Initialization
        
        public static let shared: LockManager = LockManager()
        
        // MARK: - Properties
        
        public var log: ((String) -> ())? {
            
            get { return internalManager.log }
            
            set { internalManager.log = newValue }
        }
        
        public let scanDuration = 2
        
        public let foundLock = Observable<(peripheral: Peripheral, UUID: SwiftFoundation.UUID, status: Status, model: Model, version: UInt64)?>()
        
        public lazy var state: Observable<CBCentralManagerState> = Observable(self.internalManager.state)
        
        // MARK: - Private Properties
        
        private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
        
        private lazy var internalManager: CentralManager = {
            
            let central = CentralManager()
            
            // lazy initialization for CBCentralManager
            let _ = central.state
            
            central.stateChanged = self.stateChanged
            central.didDisconnect = self.didDisconnect
            
            return central
        }()
        
        // MARK: - Methods
        
        /// Disconnnect from current lock (if any) and start scanning. (Asyncronous)
        public func startScan() {
            
            log?("Scanning...")
            
            internalManager.disconnectAll()
            
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
        
        /// Setup the connected lock
        public func setup(name: String) throws -> Key {
            
            guard let foundLock = self.foundLock.value
                else { throw Error.NoLock }
            
            // write to setup characteristic
            
            let key = Key(data: KeyData(), permission: .owner)
            
            let setup = LockService.Setup.init(value: key.data)
            
            try internalManager.write(data: setup.toBigEndian(), response: true, characteristic: LockService.Setup.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
            
            // read lock service values
            
            let statusValue = try internalManager.read(characteristic: LockService.Status.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
            
            guard let status = LockService.Status.init(bigEndian: statusValue)
                else { throw LockManagerError.InvalidCharacteristicValue(LockService.Status.UUID) }
            
            guard status.value == .unlock
                else { throw LockManagerError.InvalidStatus(status.value) }
            
            // update cached status
            if self.foundLock.value?.UUID == foundLock.UUID {
                
                self.foundLock.value!.status = status.value
            }
            
            return key
        }
        
        /// Unlock the connected lock
        public func unlock(key: KeyData) throws {
            
            guard let foundLock = self.foundLock.value
                else { throw Error.NoLock }
            
            let unlock = LockService.Unlock.init(key: key)
            
            try internalManager.write(data: unlock.toBigEndian(), response: true, characteristic: LockService.Unlock.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
        }
        
        public func createNewKey(permission: Permission, parentKey: KeyData, sharedSecret: SharedSecret = SharedSecret()) throws {
            
            assert(permission != .owner, "Cannot create owner keys")
            
            guard let foundLock = self.foundLock.value
                else { throw Error.NoLock }
            
            let parentNewKey = LockService.NewKeyParentSharedSecret.init(sharedSecret: sharedSecret, parentKey: parentKey, permission: permission)
            
            try internalManager.write(data: parentNewKey.toBigEndian(), response: true, characteristic: LockService.NewKeyParentSharedSecret.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
            
            // update cached status
            if self.foundLock.value?.UUID == foundLock.UUID {
                
                self.foundLock.value!.status = .newKey
            }
        }
        
        public func recieveNewKey(sharedSecret: SharedSecret) throws -> Key {
            
            guard let foundLock = self.foundLock.value
                else { throw Error.NoLock }
            
            // read new key child characteristic
            
            let newKeyChildValue = try internalManager.read(characteristic: LockService.NewKeyChildSharedSecret.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
            
            guard let newKeyChild = LockService.NewKeyChildSharedSecret.init(bigEndian: newKeyChildValue)
                else { throw Error.InvalidCharacteristicValue(LockService.NewKeyChildSharedSecret.UUID) }
            
            guard let key = newKeyChild.decrypt(sharedSecret: sharedSecret)
                else { throw Error.InvalidSharedSecret }
            
            // write confirmation value
            
            let newKeyFinish = LockService.NewKeyFinish.init(key: key.data)
            
            try internalManager.write(data: newKeyFinish.toBigEndian(), response: true, characteristic: LockService.NewKeyFinish.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
            
            // update cached status
            if self.foundLock.value?.UUID == foundLock.UUID {
                
                self.foundLock.value!.status = .unlock
            }
            
            return key
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
            
            self.state.value = state
        }
        
        private func didDisconnect(peripheral: Peripheral) {
            
            guard let foundLock = self.foundLock.value else { return }
            
            if peripheral.identifier == foundLock.peripheral.identifier {
                
                self.foundLock.value = nil
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
    
    public enum LockManagerError: ErrorProtocol {
        
        case NoLock
        case InvalidStatus(Status)
        case InvalidSharedSecret
        case CharacteristicNotFound(Bluetooth.UUID)
        case InvalidCharacteristicValue(Bluetooth.UUID)
    }
    
#endif