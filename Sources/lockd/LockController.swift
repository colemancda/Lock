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
    
    var configuration = try! Configuration.load(File.configuration)
    
    let model: Model = .orangePiOne
    
    let store = Store(filename: File.store)
    
    // MARK: - Private Properties
    
    private var newKey: Key?
    
    private var homeKitDeamon: pid_t?
    
    // MARK: - Intialization
    
    private init() {
        
        if store.keys.first == nil {
            
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
        ResetSwitch.onChange(resetSwitch)
        
        // start GATT server
        
        let beacon = Beacon(UUID: LockBeaconUUID, major: 0, minor: 0, RSSI: -56)
        
        #if os(Linux)
        do { try peripheral.start(beacon: beacon) }
        catch { fatalError("Could not start peripheral: \(error)") }
        #elseif os(OSX)
        do { try peripheral.start() }
        catch { fatalError("Could not start peripheral: \(error)") }
        #endif
        
        // start HomeKit deamon
        updateHomeKitSupport()
        
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
        
        let newKeyParent = Characteristic(UUID: LockService.NewKeyParent.UUID, permissions: [.Write], properties: [.Write])
        
        let newKeyChild = Characteristic(UUID: LockService.NewKeyChild.UUID, value: Data(), permissions: [.Read], properties: [.Read])
        
        let newKeyFinish = Characteristic(UUID: LockService.NewKeyFinish.UUID, value: Data(), permissions: [.Write], properties: [.Write])
        
        let homeKitEnable = Characteristic(UUID: LockService.HomeKitEnable.UUID, value: Data(), permissions: [.Write], properties: [.Write])
        
        let lockService = Service(UUID: LockService.UUID, primary: true, characteristics: [identifier, model, version, status, setup, unlock, newKeyParent, newKeyChild, newKeyFinish, homeKitEnable])
        
        let _ = try! peripheral.add(service: lockService)
    }
    
    private func didChangeStatus(oldValue: Status) {
        
        print("Status \(oldValue) -> \(status)")
        
        peripheral[characteristic: LockService.Status.UUID] = LockService.Status(value: self.status).toBigEndian()
    }
    
    private func willRead(central: Central, UUID: BluetoothUUID, value: Data, offset: Int) -> Bluetooth.ATT.Error? {
        
        switch UUID {
            
        case LockService.NewKeyChild.UUID:
            
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
            
            for key in store.keys {
                
                if unlock.authenticated(with: key.data) {
                    
                    authenticatedKey = key
                    
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
                
                // validate schedule
                guard schedule.valid()
                    else { return ATT.Error.WriteNotPermitted }
            }
            
            // send signal to GPIO
            UnlockIO()
            
            print("Unlocked by central \(central.identifier)")
            
        case LockService.NewKeyParent.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let newKeyParent = LockService.NewKeyParent.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            var authenticatedKey: Key!
            
            for key in store.keys {
                
                if newKeyParent.authenticated(with: key.data) {
                    
                    authenticatedKey = key
                    
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
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let _ = LockService.NewKeyFinish.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
        case LockService.HomeKitEnable.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let homeKit = LockService.HomeKitEnable.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            var authenticatedKey: Key!
            
            for key in store.keys {
                
                if homeKit.authenticated(with: key.data) {
                    
                    authenticatedKey = key
                    
                    break
                }
            }
            
            // not authenticated
            guard authenticatedKey != nil
                else { return ATT.Error.WriteNotPermitted }
            
            // verify permission
            guard authenticatedKey.permission == .owner
                else { return ATT.Error.WriteNotPermitted }
            
            // enable HomeKit
            self.configuration.isHomeKitEnabled = homeKit.enable
            try! self.configuration.save(File.configuration)
            
            updateHomeKitSupport()
            
            print("HomeKit enabled: \(configuration.isHomeKitEnabled)")
            
        case LockService.Update.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let update = LockService.Update.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            var authenticatedKey: Key!
            
            for key in store.keys {
                
                if update.authenticated(with: key.data) {
                    
                    authenticatedKey = key
                    
                    break
                }
            }
            
            // not authenticated
            guard authenticatedKey != nil
                else { return ATT.Error.WriteNotPermitted }
            
            // verify permission (only owner can update)
            guard authenticatedKey.permission == .owner
                else { return ATT.Error.WriteNotPermitted }
            
            // start updating
            updateSoftware()
            
            print("Software update command by central \(central.identifier)")
            
        default: fatalError("Writing to unknown characteristic \(UUID)")
        }
        
        return nil
    }
    
    private func didWrite(central: Central, UUID: BluetoothUUID, value: SwiftFoundation.Data, newValue: SwiftFoundation.Data){
        
        switch UUID {
            
        case LockService.Setup.UUID:
            
            assert(store.keys.isEmpty, "Lock already setup")
            
            // deserialize
            let key = LockService.Setup.init(bigEndian: newValue)!
            
            // validate authentication
            guard key.authenticatedWithSalt()
                else { fatalError("Unauthenticated setup key") }
            
            // set key
            store.add(Key(data: key.value, permission: .owner))
            
            print("Lock setup by central \(central.identifier)")
            
            status = .unlock
            
        case LockService.Unlock.UUID:
            
            assert(status == .unlock)
            
        case LockService.NewKeyParent.UUID:
            
            assert(status == .unlock)
            
            let newKeyParent = LockService.NewKeyParent.init(bigEndian: newValue)!
            
            var authenticatedKey: Key!
            
            for key in store.keys {
                
                if newKeyParent.authenticated(with: key.data) {
                    
                    authenticatedKey = key
                    
                    break
                }
            }
            
            let sharedSecret = newKeyParent.decrypt(key: authenticatedKey.data)!
            
            let newKey = Key(data: KeyData(), permission: newKeyParent.permission)
            self.newKey = newKey
            
            // new child value
            let newKeyChild = LockService.NewKeyChild(sharedSecret: sharedSecret, newKey: newKey)
            
            peripheral[characteristic: LockService.NewKeyChild.UUID] = newKeyChild.toBigEndian()
            
        case LockService.NewKeyFinish.UUID:
            
            assert(LockService.NewKeyFinish.canWrite(status: status))
            
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
            self.store.add(newKey)
            self.newKey = nil
            
        case LockService.HomeKitEnable.UUID:
            
            assert(LockService.HomeKitEnable.canWrite(status: status)) // nothing to do here
            
        case LockService.Update.UUID:
            
            assert(LockService.Update.canWrite(status: status))
            
            self.status = .update
            
        default: fatalError("Writing to characteristic \(UUID)")
        }
    }
    
    // MARK: GPIO
    
    private func resetSwitch(_ gpio: GPIO) {
        
        // reset DB
        print("Resetting...")
        
        AppLED.value = 0
        
        // reset config
        let newConfiguration = Configuration()
        try! newConfiguration.save(File.configuration)
        
        // clear store
        self.store.clear()
        
        // reset HomeKit
        if configuration.isHomeKitEnabled {
            
            configuration.isHomeKitEnabled = false
            updateHomeKitSupport()
        }
        
        // reboot
        #if os(Linux)
        system(Command.reboot)
        #endif
        
        return
    }
    
    // MARK: Actions
    
    private func updateHomeKitSupport() {
        
        if configuration.isHomeKitEnabled {
            
            guard self.homeKitDeamon == nil
                else { return }
            
            let launchPath = File.nodejs
            
            let argument = File.homeKitDaemon
            
            var args = [launchPath, argument]
            
            let argv : UnsafeMutablePointer<UnsafeMutablePointer<Int8>?> = args.withUnsafeBufferPointer {
                let array : UnsafeBufferPointer<String> = $0
                let buffer = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>(allocatingCapacity: array.count + 1)
                buffer.initializeFrom(array.map { $0.withCString(strdup) })
                buffer[array.count] = nil
                return buffer
            }
            
            defer {
                for arg in argv ..< argv + args.count {
                    free(UnsafeMutablePointer<Void>(arg.pointee))
                }
                
                argv.deallocateCapacity(args.count + 1)
            }
            
            var pid = pid_t()
            guard posix_spawn(&pid, launchPath, nil, nil, argv, nil) == 0
                else { fatalError("Could not start HomeKit Daemon: \(POSIXError.fromErrno!)") }
            
            self.homeKitDeamon = pid
            
        } else {
            
            guard let pid = self.homeKitDeamon
                else { return }
            
            kill(pid, SIGKILL)
            
            self.homeKitDeamon = nil
            
            do { try FileManager.removeItem(path: File.homeKitData) } catch { } // ignore error
        }
    }
    
    private func updateSoftware() {
        
        
        
        
    }
}
