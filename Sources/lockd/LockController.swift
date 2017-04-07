//
//  LockController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/17/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
    import Glibc
#elseif os(macOS)
    import Darwin.C
#endif

import Foundation
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
    
    var configuration = try! Configuration.load(File.configuration) {
        
        // save to disk
        didSet { try! self.configuration.save(File.configuration) }
    }
    
    let model: Model = .orangePiOne
    
    let store = Store(filename: File.store)
    
    // MARK: - Private Properties
        
    private var homeKitDeamon: pid_t?
    
    private var updating = false
    
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
        #elseif os(macOS)
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
        #elseif os(macOS)
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
        
        let packageVersionValue = LockService.PackageVersion(value: LinuxPackageVersion).toBigEndian()
        
        let packageVersion = Characteristic(UUID: LockService.PackageVersion.UUID, value: packageVersionValue, permissions: [.Read], properties: [.Read])
        
        let statusValue = LockService.Status(value: self.status).toBigEndian()
        
        let status = Characteristic(UUID: LockService.Status.UUID, value: statusValue, permissions: [.Read], properties: [.Read])
        
        let setup = Characteristic(UUID: LockService.Setup.UUID, permissions: [.Write], properties: [.Write])
        
        let unlock = Characteristic(UUID: LockService.Unlock.UUID, permissions: [.Write], properties: [.Write])
        
        let newKeyParent = Characteristic(UUID: LockService.NewKeyParent.UUID, permissions: [.Write], properties: [.Write])
        
        let newKeyChild = Characteristic(UUID: LockService.NewKeyChild.UUID, permissions: [.Write], properties: [.Write])
        
        let homeKitEnable = Characteristic(UUID: LockService.HomeKitEnable.UUID, permissions: [.Write], properties: [.Write])
        
        let update = Characteristic(UUID: LockService.Update.UUID, permissions: [.Write], properties: [.Write])
        
        let listKeysCommand = Characteristic(UUID: LockService.ListKeysCommand.UUID, permissions: [.Write], properties: [.Write])
        
        let listKeysValue = Characteristic(UUID: LockService.ListKeysValue.UUID, permissions: [.Read], properties: [.Read])
        
        let removeKey = Characteristic(UUID: LockService.RemoveKey.UUID, permissions: [.Write], properties: [.Write])
        
        let lockService = Service(UUID: LockService.UUID, primary: true, characteristics: [identifier, model, version, packageVersion, status, setup, unlock, newKeyParent, newKeyChild, homeKitEnable, update, listKeysCommand, listKeysValue, removeKey])
        
        let _ = try! peripheral.add(service: lockService)
    }
    
    private func didChangeStatus(oldValue: Status) {
        
        print("Status \(oldValue) -> \(status)")
        
        peripheral[characteristic: LockService.Status.UUID] = LockService.Status(value: self.status).toBigEndian()
    }
    
    private func willRead(central: Central, UUID: BluetoothUUID, value: Data, offset: Int) -> Bluetooth.ATT.Error? {
        
        return nil
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
            
            // setup done in didWrite
            
        case LockService.Unlock.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let unlock = LockService.Unlock.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            // not authenticated
            guard let authenticatedKey = authenticate(key: unlock.identifier, characteristic: unlock)
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
            
            // cannot create owner keys
            guard newKeyParent.permission != .owner
                else { return ATT.Error.WriteNotPermitted }
            
            // authenticate
            guard let authenticatedKey = authenticate(key: newKeyParent.parent, characteristic: newKeyParent)
                else { return ATT.Error.WriteNotPermitted }
            
            // only owner and admin can create new keys
            guard authenticatedKey.permission == .owner
                || authenticatedKey.permission == .admin
                else { return ATT.Error.WriteNotPermitted }
            
            // decrypt shared secret
            guard let sharedSecret = newKeyParent.decrypt(key: authenticatedKey.data)
                else { return ATT.Error.WriteNotPermitted }
            
            let newKey = NewKey(identifier: newKeyParent.child, name: newKeyParent.name, sharedSecret: sharedSecret, permission: newKeyParent.permission)
            
            store.add(newKey: newKey)
            
            print("Created new key " + newKey.identifier.rawValue)
            
        case LockService.NewKeyChild.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let newKeyChild = LockService.NewKeyChild.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            // get new key
            guard let pendingNewKey = store[newKey: newKeyChild.identifier]
                else { return ATT.Error.WriteNotPermitted }
            
            // remove pending key (no matter success or failure)
            defer { store.remove(newKey: newKeyChild.identifier) }
            
            // authenticate with shared secret
            guard newKeyChild.authenticated(with: pendingNewKey.sharedSecret)
                else { return ATT.Error.WriteNotPermitted }
            
            // decrypt new key data
            guard let keyData = newKeyChild.decrypt(sharedSecret: pendingNewKey.sharedSecret)
                else { return ATT.Error.WriteNotPermitted }
            
            // add key to store
            let key = Key(identifier: pendingNewKey.identifier, name: pendingNewKey.name, data: keyData, permission: pendingNewKey.permission, date: pendingNewKey.date)
            
            store.add(key: key)
            
            print("\(central.identifier) accepted pending key \(key.identifier)")
            
        case LockService.HomeKitEnable.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let homeKit = LockService.HomeKitEnable.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            // authenticate
            guard let authenticatedKey = authenticate(key: homeKit.identifier, characteristic: homeKit)
                else { return ATT.Error.WriteNotPermitted }
            
            // verify permission
            guard authenticatedKey.permission == .owner
                else { return ATT.Error.WriteNotPermitted }
            
            // enable HomeKit
            self.configuration.isHomeKitEnabled = homeKit.enable
            
            updateHomeKitSupport()
            
            print("HomeKit enabled: \(configuration.isHomeKitEnabled)")
            
        case LockService.Update.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let update = LockService.Update.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            // authenticate
            guard let authenticatedKey = authenticate(key: update.identifier, characteristic: update)
                else { return ATT.Error.WriteNotPermitted }
            
            // verify permission (only owner can update)
            guard authenticatedKey.permission == .owner
                else { return ATT.Error.WriteNotPermitted }
            
            // start updating
            updateSoftware()
            
            print("Software update command by central \(central.identifier)")
            
        case LockService.ListKeysCommand.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let command = LockService.ListKeysCommand.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            // authenticate
            guard let authenticatedKey = authenticate(key: command.identifier, characteristic: command)
                else { return ATT.Error.WriteNotPermitted }
            
            // verify permission (only owner or admin and see keys)
            guard authenticatedKey.permission == .owner || authenticatedKey.permission == .admin
                else { return ATT.Error.WriteNotPermitted }
            
        case LockService.RemoveKey.UUID:
            
            guard status == .unlock
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let removeCommand = LockService.RemoveKey.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
            // authenticate
            guard let authenticatedKey = authenticate(key: removeCommand.identifier, characteristic: removeCommand)
                else { return ATT.Error.WriteNotPermitted }
            
            // verify permission (only owner or admin can remove keys)
            guard authenticatedKey.permission == .owner || authenticatedKey.permission == .admin
                else { return ATT.Error.WriteNotPermitted }
            
            if store.keys.contains(where: { $0.identifier == removeCommand.removedKey }) {
                
                store.remove(key: removeCommand.removedKey)
                
            } else if store.newKeys.contains(where: { $0.identifier == removeCommand.removedKey }) {
                
                store.remove(newKey: removeCommand.removedKey)
                
            } else {
                
                // key not in store
                return ATT.Error.WriteNotPermitted
            }
            
            print("Central \(central.identifier) removed key \(removeCommand.removedKey)")
            
        default: fatalError("Writing to unknown characteristic \(UUID)")
        }
        
        return nil
    }
    
    private func didWrite(central: Central, UUID: BluetoothUUID, value: Foundation.Data, newValue: Foundation.Data) {
        
        switch UUID {
            
        case LockService.Setup.UUID:
            
            assert(store.keys.isEmpty, "Lock already setup")
            
            // deserialize
            let key = LockService.Setup.init(bigEndian: newValue)!
            
            // validate authentication
            guard key.authenticatedWithSalt()
                else { fatalError("Unauthenticated setup key") }
            
            // set key
            store.add(key: Key(identifier: key.identifier, data: key.value, permission: .owner))
            
            print("Lock setup by central \(central.identifier)")
            
            status = .unlock
            
        case LockService.Unlock.UUID: assert(status != .setup)
            
        case LockService.NewKeyParent.UUID: assert(status != .setup)
        
        case LockService.NewKeyChild.UUID: assert(status != .setup)
            
        case LockService.HomeKitEnable.UUID: assert(status != .setup)
            
        case LockService.Update.UUID: assert(status != .setup)
            
        case LockService.ListKeysCommand.UUID:
            
            typealias KeyEntry = LockService.ListKeysValue.KeyEntry
            
            assert(status != .setup)
            
            let command = LockService.ListKeysCommand.init(bigEndian: newValue)!
            
            let authenticatedKey = authenticate(key: command.identifier, characteristic: command)!
        
            let keys = self.store.keys.filter({ $0.permission != .owner }).map { KeyEntry(identifier: $0.identifier, name: $0.name!, date: $0.date, permission: $0.permission) }
            
            let pendingKeys = self.store.newKeys.map { KeyEntry(identifier: $0.identifier, name: $0.name, date: $0.date, permission: $0.permission, pending: true) }
            
            let keyList = keys + pendingKeys
            
            // encrypt key list with authenticated keys
            let encryptedKeys = LockService.ListKeysValue.init(keys: keyList, key: authenticatedKey.data)
            
            print("Listing \(keyList.count) keys for central \(central.identifier)")
            
            peripheral[characteristic: LockService.ListKeysValue.UUID] = encryptedKeys.toBigEndian()
            
        case LockService.RemoveKey.UUID: assert(status != .setup)
            
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
                let buffer = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: array.count + 1)
                buffer.initialize(from: array.map { $0.withCString(strdup) })
                buffer[array.count] = nil
                return buffer
            }
            
            defer {
                for arg in argv ..< argv + args.count {
                    free(UnsafeMutableRawPointer(arg.pointee))
                }
                
                argv.deallocate(capacity: args.count + 1)
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
        
        guard updating == false else { return }
        
        // run update commands
        
        updating = true
        
        let _ = try! Thread(block: {
            
            #if os(Linux)
                system(Command.updatePackageList)
                system(Command.updateLock)
                
                print("Will reboot for update")
                
                system(Command.reboot)
            #endif
        })
    }
    
    // MARK: Utility
    
    @inline(__always)
    private func authenticate(key identifier: UUID, characteristic: AuthenticatedCharacteristic) -> Key? {
        
        guard let key = store[key: identifier],
            characteristic.authenticated(with: key.data)
            else { return nil }
        
        return key
    }
}
