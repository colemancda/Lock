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
        
        public lazy var state: Observable<CBCentralManagerState> = Observable(self.internalManager.state)
        
        // MARK: - Private Properties
        
        private lazy var internalManager: CentralManager = {
            
            let central = CentralManager()
            
            // lazy initialization for CBCentralManager
            let _ = central.state
            
            central.stateChanged = { self.state.value = $0 }
            
            return central
        }()
        
        // MARK: - Methods
        
        /// Disconnnect from current lock (if any) and scans for a lock. 
        ///
        /// - Parameter duration: The duration of the scan.
        ///
        /// - Parameter filter: The UUID Lock to find, or `nil` for the first lock found.
        ///
        /// - Returns: The first lock found.
        public func scan(duration: Int = 2, filter UUID: SwiftFoundation.UUID? = nil) throws -> Lock? {
            
            assert(self.internalManager.state == .poweredOn, "Should only scan when powered on")
            
            log?("Scanning...")
            
            internalManager.disconnectAll()
            
            let foundDevices = self.internalManager.scan(duration: duration)
            
            if foundDevices.count > 0 { self.log?("Found \(foundDevices.count) peripherals") }
            
            for peripheral in foundDevices {
                
                do { try self.internalManager.connect(to: peripheral) }
                    
                catch { print("Cound not connect to \(peripheral.identifier) (\(error))"); continue }
                
                guard let services = try? self.internalManager.discoverServices(for: peripheral)
                    else { continue }
                
                // found lock
                if services.contains({ $0.UUID == LockService.UUID }) {
                    
                    let foundLock = try self.foundLock(peripheral: peripheral)
                    
                    // optionally filter locks
                    guard foundLock.UUID == UUID || UUID != nil else { continue }
                    
                    return foundLock
                }
            }
            
            return nil
        }
        
        public func disconnect(lock: Lock) {
            
            internalManager.disconnect(peripheral: lock.peripheral)
        }
        
        /// Setup the connected lock.
        public func setup(lock: inout Lock) throws -> Key {
            
            // write to setup characteristic
            
            let key = Key(data: KeyData(), permission: .owner)
            
            let setup = LockService.Setup.init(value: key.data)
            
            try internalManager.write(data: setup.toBigEndian(), response: true, characteristic: LockService.Setup.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            
            // read lock service values
            
            let statusValue = try internalManager.read(characteristic: LockService.Status.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            
            guard let status = LockService.Status.init(bigEndian: statusValue)
                else { throw LockManagerError.InvalidCharacteristicValue(LockService.Status.UUID) }
            
            guard status.value == .unlock
                else { throw LockManagerError.InvalidStatus(status.value) }
            
            // update cached status
            lock.status = status.value
            
            return key
        }
        
        /// Unlock the connected lock
        public func unlock(lock: Lock, key: KeyData) throws {
            
            let unlock = LockService.Unlock.init(key: key)
            
            try internalManager.write(data: unlock.toBigEndian(), response: true, characteristic: LockService.Unlock.UUID, service: LockService.UUID, peripheral: lock.peripheral)
        }
        
        public func createNewKey(lock: inout Lock, permission: Permission, parentKey: KeyData, sharedSecret: SharedSecret = SharedSecret()) throws {
            
            assert(permission != .owner, "Cannot create owner keys")
            
            let parentNewKey = LockService.NewKeyParentSharedSecret.init(sharedSecret: sharedSecret, parentKey: parentKey, permission: permission)
            
            try internalManager.write(data: parentNewKey.toBigEndian(), response: true, characteristic: LockService.NewKeyParentSharedSecret.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            
            // update cached status
            lock.status = .newKey
        }
        
        public func recieveNewKey(lock: inout Lock, sharedSecret: SharedSecret) throws -> Key {
            
            // read new key child characteristic
            
            let newKeyChildValue = try internalManager.read(characteristic: LockService.NewKeyChildSharedSecret.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            
            guard let newKeyChild = LockService.NewKeyChildSharedSecret.init(bigEndian: newKeyChildValue)
                else { throw Error.InvalidCharacteristicValue(LockService.NewKeyChildSharedSecret.UUID) }
            
            guard let key = newKeyChild.decrypt(sharedSecret: sharedSecret)
                else { throw Error.InvalidSharedSecret }
            
            // write confirmation value
            
            let newKeyFinish = LockService.NewKeyFinish.init(key: key.data)
            
            try internalManager.write(data: newKeyFinish.toBigEndian(), response: true, characteristic: LockService.NewKeyFinish.UUID, service: LockService.UUID, peripheral: lock.peripheral)
            
            // update cached status
            lock.status = .unlock
            
            return key
        }
        
        // MARK: - Private Methods
        
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
        
        case InvalidStatus(Status)
        case InvalidSharedSecret
        case CharacteristicNotFound(Bluetooth.UUID)
        case InvalidCharacteristicValue(Bluetooth.UUID)
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