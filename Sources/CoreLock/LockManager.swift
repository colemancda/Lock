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
        
        public var scanning = Observable(false)
        
        public var connectionTimeout: Int = 5
        
        public let foundLocks: Observable<[Lock]> = Observable([])
        
        public lazy var state: Observable<CBCentralManagerState> = Observable(self.internalManager.state)
        
        // MARK: - Private Properties
        
        private lazy var internalManager: CentralManager = {
            
            let central = CentralManager()
            
            // lazy initialization for CBCentralManager
            let _ = central.state
            
            central.stateChanged = { self.state.value = $0 }
            
            return central
        }()
        
        // MARK: - Subscripting
        
        public private(set) subscript (UUID: SwiftFoundation.UUID) -> Lock? {
            
            get {
                
                guard let index = foundLocks.value.index(where: { $0.UUID == UUID })
                    else { return nil }
                
                return foundLocks.value[index]
            }
            
            set {
                
                guard let index = foundLocks.value.index(where: { $0.UUID == UUID })
                    else { fatalError("Invalid index") }
                
                guard let newLock = newValue
                    else { foundLocks.value.remove(at: index); return }
                
                foundLocks.value[index] = newLock
            }
        }
        
        // MARK: - Methods
        
        /// Scans for a lock.
        ///
        /// - Parameter duration: The duration of the scan.
        ///
        /// - Returns: The locks found.
        public func scan(duration: Int = 3) throws {
            
            assert(self.internalManager.state == .poweredOn, "Should only scan when powered on")
            
            log?("Scanning...")
            
            scanning.value = true
            
            internalManager.disconnectAll()
            
            let foundDevices = self.internalManager.scan(duration: duration)
            
            if foundDevices.count > 0 { self.log?("Found \(foundDevices.count) peripherals") }
            
            var locks = [Lock]()
            
            for peripheral in foundDevices {
                
                do { try self.internalManager.connect(to: peripheral) }
                    
                catch { log?("Cound not connect to \(peripheral.identifier) (\(error))"); continue }
                
                guard let services = try? self.internalManager.discoverServices(for: peripheral)
                    else { continue }
                
                // found lock
                if services.contains({ $0.UUID == LockService.UUID }) {
                    
                    guard let foundLock = try? self.foundLock(peripheral: peripheral)
                        else { continue }
                    
                    locks.append(foundLock)
                }
                
                // disconnect
                internalManager.disconnect(peripheral: peripheral)
            }
            
            scanning.value = false
            
            foundLocks.value = locks
        }
        
        public func disconnect(lock: Lock) {
            
            internalManager.disconnect(peripheral: lock.peripheral)
        }
        
        // MARK: Lock Actions
        
        /// Setup the connected lock.
        public func setup(_ identifier: SwiftFoundation.UUID) throws -> Key {
            
            guard let lock = self[identifier]
                else { throw Error.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.Setup.UUID]) {
                
                // write to setup characteristic
                
                let key = Key(permission: .owner)
                
                let setup = LockService.Setup.init(identifier: key.identifier, value: key.data)
                
                try self.internalManager.write(data: setup.toBigEndian(), response: true, characteristic: LockService.Setup.UUID, service: LockService.UUID, peripheral: lock.peripheral)
                
                // read lock service values
                
                let statusValue = try self.internalManager.read(characteristic: LockService.Status.UUID, service: LockService.UUID, peripheral: lock.peripheral)
                
                guard let status = LockService.Status.init(bigEndian: statusValue)
                    else { throw LockManagerError.InvalidCharacteristicValue(LockService.Status.UUID) }
                
                guard status.value == .unlock
                    else { throw LockManagerError.InvalidStatus(status.value) }
                
                // update cached status
                self[identifier]?.status = status.value
                
                return key
            }
        }
        
        /// Unlock the connected lock
        public func unlock(_ identifier: SwiftFoundation.UUID, key: Key) throws {
            
            guard let lock = self[identifier]
                else { throw Error.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.Unlock.UUID]) {
                
                // unlock
                
                let unlock = LockService.Unlock.init(identifier: key.identifier, key: key.data)
                
                try self.internalManager.write(data: unlock.toBigEndian(), response: true, characteristic: LockService.Unlock.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            }
        }
        
        public func createNewKey(_ identifier: SwiftFoundation.UUID, permission: Permission, parentKey: KeyData, sharedSecret: SharedSecret = SharedSecret()) throws {
            
            assert(permission != .owner, "Cannot create owner keys")
            
            guard let lock = self[identifier]
                else { throw Error.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.NewKeyParentSharedSecret.UUID]) {
             
                // create new parent key
                
                let parentNewKey = LockService.NewKeyParentSharedSecret.init(sharedSecret: sharedSecret, parentKey: parentKey, permission: permission)
                
                try self.internalManager.write(data: parentNewKey.toBigEndian(), response: true, characteristic: LockService.NewKeyParentSharedSecret.UUID, service: LockService.UUID, peripheral: lock.peripheral)
                
                // update cached status
                self[identifier]?.status = .newKey
            }
        }
        
        public func recieveNewKey(_ identifier: SwiftFoundation.UUID, sharedSecret: SharedSecret) throws -> Key {
            
            guard let lock = self[identifier]
                else { throw Error.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.NewKeyChildSharedSecret.UUID, LockService.NewKeyFinish.UUID]) {
                
                // read new key child characteristic
                
                let newKeyChildValue = try self.internalManager.read(characteristic: LockService.NewKeyChildSharedSecret.UUID, service: LockService.UUID, peripheral: lock.peripheral)
                
                guard let newKeyChild = LockService.NewKeyChildSharedSecret.init(bigEndian: newKeyChildValue)
                    else { throw Error.InvalidCharacteristicValue(LockService.NewKeyChildSharedSecret.UUID) }
                
                guard let key = newKeyChild.decrypt(sharedSecret: sharedSecret)
                    else { throw Error.InvalidSharedSecret }
                
                // write confirmation value
                
                let newKeyFinish = LockService.NewKeyFinish.init(key: key.data)
                
                try self.internalManager.write(data: newKeyFinish.toBigEndian(), response: true, characteristic: LockService.NewKeyFinish.UUID, service: LockService.UUID, peripheral: lock.peripheral)
                
                // update cached status
                self[identifier]?.status = .unlock
                
                return key
            }
        }
        
        // MARK: - Private Methods
        
        /// Connects to the lock, fetches the data, and performs the action, and disconnects.
        private func lockAction<T>(peripheral: Peripheral, characteristics: [Bluetooth.UUID], action: () throws -> (T)) throws -> T {
            
            // connect first
            try internalManager.connect(to: peripheral, timeout: connectionTimeout)
            
            defer { internalManager.disconnect(peripheral: peripheral) }
            
            // discover lock service
            let services = try self.internalManager.discoverServices(for: peripheral)
            
            guard services.contains({ $0.UUID == LockService.UUID })
                else { throw Error.LockServiceNotFound }
            
            // read characteristic
            
            let foundCharacteristics = try internalManager.discoverCharacteristics(for: LockService.UUID, peripheral: peripheral)
            
            for requiredCharacteristic in characteristics {
                
                guard foundCharacteristics.contains({ $0.UUID == requiredCharacteristic })
                    else { throw Error.CharacteristicNotFound(requiredCharacteristic) }
            }
            
            // perform action
            return try action()
        }
        
        private func foundLock(peripheral: Peripheral) throws -> Lock {
            
            log?("Found lock peripheral \(peripheral.identifier)")
            
            // get lock status
            
            let characteristics = try internalManager.discoverCharacteristics(for: LockService.UUID, peripheral: peripheral)
            
            guard characteristics.contains({ $0.UUID == LockService.Status.UUID })
                else { throw Error.CharacteristicNotFound(LockService.Status.UUID) }
            
            let statusValue = try internalManager.read(characteristic: LockService.Status.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let status = LockService.Status.init(bigEndian: statusValue)
                else { throw Error.InvalidCharacteristicValue(LockService.Status.UUID) }
            
            // get lock UUID
            
            guard characteristics.contains({ $0.UUID == LockService.Identifier.UUID })
                else { throw Error.CharacteristicNotFound(LockService.Identifier.UUID) }
            
            let identifierValue = try internalManager.read(characteristic: LockService.Identifier.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let identifier = LockService.Identifier.init(bigEndian: identifierValue)
                else { throw Error.InvalidCharacteristicValue(LockService.Identifier.UUID) }
            
            // get model
            
            let modelValue = try internalManager.read(characteristic: LockService.Model.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let model = LockService.Model.init(bigEndian: modelValue)
                else { throw Error.InvalidCharacteristicValue(LockService.Model.UUID) }
            
            // get version
            
            let versionValue = try internalManager.read(characteristic: LockService.Version.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let version = LockService.Version.init(bigEndian: versionValue)
                else { throw Error.InvalidCharacteristicValue(LockService.Version.UUID) }
            
            // validate other characteristics
            
            guard characteristics.contains({ $0.UUID == LockService.Setup.UUID })
                else { throw Error.CharacteristicNotFound(LockService.Setup.UUID) }
            
            guard characteristics.contains({ $0.UUID == LockService.Unlock.UUID })
                else { throw Error.CharacteristicNotFound(LockService.Unlock.UUID) }
            
            guard characteristics.contains({ $0.UUID == LockService.NewKeyParentSharedSecret.UUID })
                else { throw Error.CharacteristicNotFound(LockService.NewKeyParentSharedSecret.UUID) }
            
            guard characteristics.contains({ $0.UUID == LockService.NewKeyChildSharedSecret.UUID })
                else { throw Error.CharacteristicNotFound(LockService.NewKeyChildSharedSecret.UUID) }
            
            guard characteristics.contains({ $0.UUID == LockService.NewKeyFinish.UUID })
                else { throw Error.CharacteristicNotFound(LockService.NewKeyFinish.UUID) }
            
            log?("Lock \((peripheral, identifier.value, status.value, model.value, version.value))")
            
            return Lock(peripheral: peripheral, UUID: identifier.value, status: status.value, model: model.value, version: version.value)
        }
    }
    
    public enum LockManagerError: ErrorProtocol {
        
        case NoLock
        case InvalidStatus(Status)
        case InvalidSharedSecret
        case CharacteristicNotFound(Bluetooth.UUID)
        case InvalidCharacteristicValue(Bluetooth.UUID)
        case LockServiceNotFound
    }
    
    public extension LockManager {
        
        public struct Lock {
            
            public let peripheral: Peripheral
            public let UUID: SwiftFoundation.UUID
            public let model: Model
            public let version: UInt64
            public var status: Status
            
            private init(peripheral: Peripheral, UUID: SwiftFoundation.UUID, status: Status, model: Model, version: UInt64) {
                
                self.peripheral = peripheral
                self.UUID = UUID
                self.status = status
                self.model = model
                self.version = version
            }
        }
    }
    
#endif