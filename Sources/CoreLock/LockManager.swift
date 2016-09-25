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
        
        public lazy var state: Observable<CBCentralManagerState> = unsafeBitCast(Observable(self.internalManager.state), to: Observable<CBCentralManagerState>.self)
        
        // MARK: - Private Properties
        
        private lazy var internalManager: CentralManager = {
            
            let central = CentralManager()
            
            // lazy initialization for CBCentralManager
            let _ = central.state
            
            central.stateChanged = { self.state.value = $0 }
            
            return central
        }()
        
        // MARK: - Subscripting
        
        public private(set) subscript (identifier: UUID) -> Lock? {
            
            get {
                
                guard let index = foundLocks.value.index(where: { $0.identifier == identifier })
                    else { return nil }
                
                return foundLocks.value[index]
            }
            
            set {
                
                guard let index = foundLocks.value.index(where: { $0.identifier == identifier })
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
                if services.contains(where: { $0.UUID == LockService.UUID }) {
                    
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
        
        public func clear() {
            
            foundLocks.value = []
        }
        
        public func disconnect(lock: Lock) {
            
            internalManager.disconnect(peripheral: lock.peripheral)
        }
        
        // MARK: Lock Actions
        
        /// Setup the connected lock.
        public func setup(_ identifier: UUID) throws -> Key {
            
            guard let lock = self[identifier]
                else { throw LockManagerError.NoLock }
            
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
        public func unlock(_ identifier: UUID, key: (UUID, KeyData)) throws {
            
            guard let lock = self[identifier]
                else { throw LockManagerError.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.Unlock.UUID]) {
                
                // unlock
                
                let unlock = LockService.Unlock.init(identifier: key.0, key: key.1)
                
                try self.internalManager.write(data: unlock.toBigEndian(), response: true, characteristic: LockService.Unlock.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            }
        }
        
        public func createNewKey(_ identifier: UUID, parentKey: (UUID, KeyData), childKey: (UUID, Permission, Key.Name), sharedSecret: KeyData) throws {
            
            assert(childKey.1 != .owner, "Cannot create owner keys")
            
            guard let lock = self[identifier]
                else { throw LockManagerError.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.NewKeyParent.UUID]) {
             
                // create new parent key
                let parentNewKey = LockService.NewKeyParent.init(sharedSecret: sharedSecret, parentKey: parentKey, childKey: childKey)
                
                try self.internalManager.write(data: parentNewKey.toBigEndian(), response: true, characteristic: LockService.NewKeyParent.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            }
        }
        
        public func recieveNewKey(_ identifier: UUID, sharedSecret: KeyData, newKey: (UUID, KeyData)) throws {
            
            guard let lock = self[identifier]
                else { throw LockManagerError.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.NewKeyChild.UUID]) {
                
                let newKeyChild = LockService.NewKeyChild.init(sharedSecret: sharedSecret, newKey: newKey)
                
                try self.internalManager.write(data: newKeyChild.toBigEndian(), response: true, characteristic: LockService.NewKeyChild.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            }
        }
        
        /// Put the lock in HomeKit mode.
        public func enableHomeKit(_ identifier: UUID, key: (UUID, KeyData), enable: Bool = true) throws {
            
            guard let lock = self[identifier]
                else { throw LockManagerError.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.HomeKitEnable.UUID]) {
                
                // enable Homekit
                
                let homeKit = LockService.HomeKitEnable.init(identifier: key.0, key: key.1, enable: enable)
                
                try self.internalManager.write(data: homeKit.toBigEndian(), response: true, characteristic: LockService.HomeKitEnable.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            }
        }
        
        /// Update the lock device.
        public func update(_ identifier: UUID, key: (UUID, KeyData)) throws {
            
            guard let lock = self[identifier]
                else { throw LockManagerError.NoLock }
            
            return try lockAction(peripheral: lock.peripheral, characteristics: [LockService.Update.UUID]) {
                
                // unlock
                
                let unlock = LockService.Update.init(identifier: key.0, key: key.1)
                
                try self.internalManager.write(data: unlock.toBigEndian(), response: true, characteristic: LockService.Update.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            }
        }
        
        // MARK: - Private Methods
        
        /// Connects to the lock, fetches the data, and performs the action, and disconnects.
        private func lockAction<T>(peripheral: Peripheral, characteristics: [BluetoothUUID], action: () throws -> (T)) throws -> T {
            
            // connect first
            try internalManager.connect(to: peripheral, timeout: connectionTimeout)
            
            defer { internalManager.disconnect(peripheral: peripheral) }
            
            // discover lock service
            let services = try self.internalManager.discoverServices(for: peripheral)
            
            guard services.contains(where: { $0.UUID == LockService.UUID })
                else { throw LockManagerError.LockServiceNotFound }
            
            // read characteristic
            
            let foundCharacteristics = try internalManager.discoverCharacteristics(for: LockService.UUID, peripheral: peripheral)
            
            for requiredCharacteristic in characteristics {
                
                guard foundCharacteristics.contains(where: { $0.UUID == requiredCharacteristic })
                    else { throw LockManagerError.CharacteristicNotFound(requiredCharacteristic) }
            }
            
            // perform action
            return try action()
        }
        
        private func foundLock(peripheral: Peripheral) throws -> Lock {
            
            log?("Found lock peripheral \(peripheral.identifier)")
            
            // get lock status
            
            let characteristics = try internalManager.discoverCharacteristics(for: LockService.UUID, peripheral: peripheral)
            
            assert(characteristics.count == 10, "Invalid number of characteristics on lock: \(characteristics.count)")
            
            guard characteristics.contains(where: { $0.UUID == LockService.Status.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.Status.UUID) }
            
            let statusValue = try internalManager.read(characteristic: LockService.Status.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let status = LockService.Status.init(bigEndian: statusValue)
                else { throw LockManagerError.InvalidCharacteristicValue(LockService.Status.UUID) }
            
            // get lock UUID
            
            guard characteristics.contains(where: { $0.UUID == LockService.Identifier.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.Identifier.UUID) }
            
            let identifierValue = try internalManager.read(characteristic: LockService.Identifier.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let identifier = LockService.Identifier.init(bigEndian: identifierValue)
                else { throw LockManagerError.InvalidCharacteristicValue(LockService.Identifier.UUID) }
            
            // get model
            
            guard characteristics.contains(where: { $0.UUID == LockService.Model.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.Model.UUID) }
            
            let modelValue = try internalManager.read(characteristic: LockService.Model.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let model = LockService.Model.init(bigEndian: modelValue)
                else { throw LockManagerError.InvalidCharacteristicValue(LockService.Model.UUID) }
            
            // get version
            
            guard characteristics.contains(where: { $0.UUID == LockService.Version.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.Version.UUID) }
            
            let versionValue = try internalManager.read(characteristic: LockService.Version.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let version = LockService.Version.init(bigEndian: versionValue)
                else { throw LockManagerError.InvalidCharacteristicValue(LockService.Version.UUID) }
            
            // get package version
            
            guard characteristics.contains(where: { $0.UUID == LockService.PackageVersion.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.PackageVersion.UUID) }
            
            let packageVersionValue = try internalManager.read(characteristic: LockService.PackageVersion.UUID, service: LockService.UUID, peripheral: peripheral)
            
            guard let packageVersion = LockService.PackageVersion.init(bigEndian: packageVersionValue)
                else { throw LockManagerError.InvalidCharacteristicValue(LockService.PackageVersion.UUID) }
            
            // validate other characteristics
            
            guard characteristics.contains(where: { $0.UUID == LockService.Setup.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.Setup.UUID) }
            
            guard characteristics.contains(where: { $0.UUID == LockService.Unlock.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.Unlock.UUID) }
            
            guard characteristics.contains(where: { $0.UUID == LockService.NewKeyParent.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.NewKeyParent.UUID) }
            
            guard characteristics.contains(where: { $0.UUID == LockService.NewKeyChild.UUID })
                else { throw LockManagerError.CharacteristicNotFound(LockService.NewKeyChild.UUID) }
            
            log?("Lock \((peripheral, identifier.value, status.value, model.value, version.value))")
            
            return Lock(peripheral: peripheral, identifier: identifier.value, status: status.value, model: model.value, version: version.value, packageVersion: packageVersion.value)
        }
    }
    
    public enum LockManagerError: Error {
        
        case NoLock
        case InvalidStatus(Status)
        case InvalidSharedSecret
        case CharacteristicNotFound(BluetoothUUID)
        case InvalidCharacteristicValue(BluetoothUUID)
        case LockServiceNotFound
    }
    
    public extension LockManager {
        
        public struct Lock {
            
            public let peripheral: Peripheral
            public let identifier: UUID
            public let model: Model
            public let version: UInt64
            public let packageVersion: (UInt16, UInt16, UInt16)
            public var status: Status
            
            fileprivate init(peripheral: Peripheral, identifier: SwiftFoundation.UUID, status: Status, model: Model, version: UInt64, packageVersion: (UInt16, UInt16, UInt16)) {
                
                self.peripheral = peripheral
                self.identifier = identifier
                self.status = status
                self.model = model
                self.version = version
                self.packageVersion = packageVersion
            }
        }
    }
    
#endif
