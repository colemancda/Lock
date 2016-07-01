//
//  LockController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/17/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
    import Glibc
#elseif os(OSX)
    import Darwin.C
#endif

import SwiftFoundation
import Bluetooth
import GATT
import CoreLock

/// Lock's main controller
final class LockController {
    
    // MARK: - Properties
    
    static let shared = LockController()
    
    let peripheral: PeripheralManager
    
    var status: CoreLock.Status {
        
        didSet { didChangeStatus(oldValue: oldValue) }
    }
    
    let configuration = try! Configuration.load(File.configuration)
    
    let model: Model = .orangePiOne
    
    let store = Store(filename: File.store)
    
    // MARK: - Private Properties
    
    private var newKey: Key?
    
    private var resetSwitchLastFallDate = Date()
    
    private var resetThread: Thread?
    
    // MARK: - Intialization
    
    private init() {
        
        if store.data.first == nil {
            
            status = .setup
            
        } else {
            
            status = .unlock
        }
        
        // setup server
        
        #if os(Linux)
        peripheral = PeripheralManager()
        #elseif os(OSX)
        peripheral = PeripheralManager(localName: "Test Lock")
        #endif
        
        peripheral.log = { print("Peripheral: " + $0) }
        
        peripheral.willWrite = willWrite
        peripheral.willRead = willRead
        peripheral.didWrite = didWrite
        
        addLockService()
        
        // Setup GPIO
        
        // make sure lock is not accidentally unlocked by relay
        UnlockGPIO.value = 1
        
        // turn on app LED
        AppLED.value = 1
        
        // listen to reset switch
        ResetSwitch.onRaising(resetSwitch)
        
        // start GATT server
        
        let beacon = Beacon(UUID: LockBeaconUUID, major: 0, minor: 0, RSSI: -56)
        
        #if os(Linux)
        do { try peripheral.start(beacon: beacon) }
        catch { fatalError("Could not start peripheral: \(error)") }
        #elseif os(OSX)
        do { try peripheral.start() }
        catch { fatalError("Could not start peripheral: \(error)") }
        #endif
        
        print("Status: \(status)")
    }
    
    // MARK: - Private Methods
    
    // MARK: GATT
    
    private func addLockService() {
        
        let identifierValue = LockService.Identifier(value: configuration.identifier).toBigEndian()
        
        let identifier = Characteristic(UUID: LockService.Identifier.UUID, value: identifierValue, permissions: [.Read], properties: [.Read])
        
        let modelValue = LockService.Model(value: self.model).toBigEndian()
        
        let model = Characteristic(UUID: LockService.Model.UUID, value: modelValue, permissions: [.Read], properties: [.Read])
                
        let versionValue = LockService.Version(value: CoreLockVersion).toBigEndian()
        
        let version = Characteristic(UUID: LockService.Version.UUID, value: versionValue, permissions: [.Read], properties: [.Read])
        
        let statusValue = LockService.Status(value: self.status).toBigEndian()
        
        let status = Characteristic(UUID: LockService.Status.UUID, value: statusValue, permissions: [.Read], properties: [.Read])
        
        let setup = Characteristic(UUID: LockService.Setup.UUID, permissions: [.Write], properties: [.Write])
        
        let unlock = Characteristic(UUID: LockService.Unlock.UUID, permissions: [.Write], properties: [.Write])
        
        let newKeyParent = Characteristic(UUID: LockService.NewKeyParentSharedSecret.UUID, permissions: [.Write], properties: [.Write])
        
        let newKeyChild = Characteristic(UUID: LockService.NewKeyChildSharedSecret.UUID, value: Data(), permissions: [.Read], properties: [.Read])
        
        let newKeyFinish = Characteristic(UUID: LockService.NewKeyFinish.UUID, value: Data(), permissions: [.Write], properties: [.Write])
        
        let lockService = Service(UUID: LockService.UUID, primary: true, characteristics: [identifier, model, version, status, setup, unlock, newKeyParent, newKeyChild, newKeyFinish])
        
        let _ = try! peripheral.add(service: lockService)
    }
    
    private func didChangeStatus(oldValue: Status) {
        
        print("Status \(oldValue) -> \(status)")
        
        peripheral[characteristic: LockService.Status.UUID] = LockService.Status(value: self.status).toBigEndian()
    }
    
    private func willRead(central: Central, UUID: BluetoothUUID, value: Data, offset: Int) -> Bluetooth.ATT.Error? {
        
        switch UUID {
            
        case LockService.NewKeyChildSharedSecret.UUID:
            
            return nil
            
        default: return nil
        }
    }
    
    private func willWrite(central: Central, UUID: BluetoothUUID, value: Data, newValue: Data) -> Bluetooth.ATT.Error? {
        
        switch UUID {
            
        case LockService.Setup.UUID:
            
            guard status == .setup
                else { return ATT.Error.WriteNotPermitted }
            
            guard let key = LockService.Setup.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            guard key.authenticatedWithSalt()
                else { return ATT.Error.WriteNotPermitted }
            
        case LockService.Unlock.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let unlock = LockService.Unlock.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            var authenticatedKey: Key!
            
            for storeData in store.data {
                
                if unlock.authenticated(with: storeData.key.data) {
                    
                    authenticatedKey = storeData.key
                    
                    break
                }
            }
            
            // not authenticated
            guard authenticatedKey != nil
                else { return ATT.Error.WriteNotPermitted }
            
            // verify permission
            switch authenticatedKey.permission {
                
            case .owner, .admin, .anytime: break // can open
                
            case let .scheduled(schedule):
                
                guard schedule.valid()
                    else { return ATT.Error.WriteNotPermitted }
            }
            
            // send signal to GPIO
            UnlockIO()
            
            print("Unlocked by central \(central.identifier)")
            
        case LockService.NewKeyParentSharedSecret.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let newKeyParent = LockService.NewKeyParentSharedSecret.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            var authenticatedKey: Key!
            
            for storeData in store.data {
                
                if newKeyParent.authenticated(with: storeData.key.data) {
                    
                    authenticatedKey = storeData.key
                    
                    break
                }
            }
            
            // not authenticated
            guard authenticatedKey != nil
                else { return ATT.Error.WriteNotPermitted }
            
            guard authenticatedKey.permission == .owner || authenticatedKey.permission == .admin
                else { return ATT.Error.WriteNotPermitted }
            
            // decrypt shared secret
            guard let _ = newKeyParent.decrypt(key: authenticatedKey.data)
                else { return ATT.Error.WriteNotPermitted }
            
        case LockService.NewKeyFinish.UUID:
            
            guard status == .newKey
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let _ = LockService.NewKeyFinish.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
        default: fatalError("Writing to unknown characteristic \(UUID)")
        }
        
        return nil
    }
    
    private func didWrite(central: Central, UUID: BluetoothUUID, value: SwiftFoundation.Data, newValue: SwiftFoundation.Data){
        
        switch UUID {
            
        case LockService.Setup.UUID:
            
            assert(store.data.isEmpty, "Lock already setup")
            
            // deserialize
            let key = LockService.Setup.init(bigEndian: newValue)!
            
            // validate authentication
            guard key.authenticatedWithSalt()
                else { fatalError("Unauthenticated setup key") }
            
            // set key
            store.add(key: Key(data: key.value, permission: .owner))
            
            print("Lock setup by central \(central.identifier)")
            
            status = .unlock
            
        case LockService.Unlock.UUID:
            
            assert(status != .setup)
            
        case LockService.NewKeyParentSharedSecret.UUID:
            
            assert(status == .unlock)
            
            let newKeyParent = LockService.NewKeyParentSharedSecret.init(bigEndian: newValue)!
            
            var authenticatedKey: Key!
            
            for storeData in store.data {
                
                if newKeyParent.authenticated(with: storeData.key.data) {
                    
                    authenticatedKey = storeData.key
                    
                    break
                }
            }
            
            let sharedSecret = newKeyParent.decrypt(key: authenticatedKey.data)!
            
            // update status
            status = .newKey
            
            let newKey = Key(data: KeyData(), permission: newKeyParent.permission)
            self.newKey = newKey
            
            // new child value
            let newKeyChild = LockService.NewKeyChildSharedSecret(sharedSecret: sharedSecret, newKey: newKey)
            
            peripheral[characteristic: LockService.NewKeyChildSharedSecret.UUID] = newKeyChild.toBigEndian()
            
        case LockService.NewKeyFinish.UUID:
            
            assert(status == .newKey)
            
            guard let newKey = self.newKey
                else { fatalError("New key must not be nil") }
            
            // deserialize
            let newKeyFinish = LockService.NewKeyFinish.init(bigEndian: newValue)!
            
            guard newKeyFinish.authenticated(with: newKey.data) else {
                
                print("Invalid authentication for New Key confirmation, deleting new key")
                
                self.newKey = nil
                
                return
            }
            
            print("Successfully created new \(newKey.permission) key")
            
            // update status
            self.status = .unlock
            self.store.add(key: newKey)
            self.newKey = nil
            
        default: fatalError("Writing to characteristic \(UUID)")
        }
    }
    
    // MARK: GPIO
    
    private func resetSwitch(gpio: GPIO) {
        
        assert(gpio === ResetSwitch)
        
        resetSwitchLastFallDate = Date()
        
        if resetThread == nil {
            
            // create the reset checking thread
            resetThread = try! Thread { [weak self] in
                
                while self != nil {
                    
                    let controller = self!
                    
                    guard Date() - controller.resetSwitchLastFallDate < 10 else {
                        
                        ResetSwitch.clearListeners()
                        
                        // reset DB
                        
                        print("Resetting...")
                        
                        AppLED.value = 0
                        
                        // reset config
                        let newConfiguration = Configuration()
                        try! newConfiguration.save(File.configuration)
                        
                        // clear store
                        controller.store.clear()
                        
                        // reboot
                        system("reboot")
                        
                        return
                    }
                }
            }
        }
    }
}
