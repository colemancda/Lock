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
    
    let configuration: Configuration = Configuration()
    
    var keys: [Key]
    
    // MARK: - Intialization
    
    private init() {
        
        // load keys
        
        self.keys = loadKeys()
        
        if keys.first == nil {
            
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
        //AppLED.value = 1
        
        // listen to reset switch
        //ResetSwitch.onChange(resetSwitchPressed)
        
        // start GATT server
        
        do { try peripheral.start() }
        
        catch { fatalError("Could not start peripheral: \(error)") }
    }
    
    // MARK: - Private Methods
    
    // MARK: GATT
    
    private func addLockService() {
        
        let identifierValue = LockService.Identifier(value: configuration.identifier).toBigEndian()
        
        let identifier = Characteristic(UUID: LockService.Identifier.UUID, value: identifierValue, permissions: [.Read], properties: [.Read])
        
        let modelValue = LockService.Model(value: configuration.model).toBigEndian()
        
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
    
    private func willRead(central: Central, UUID: Bluetooth.UUID, value: Data, offset: Int) -> Bluetooth.ATT.Error? {
        
        switch UUID {
            
        case LockService.NewKeyChildSharedSecret.UUID:
            
            return nil
            
        default: return nil
        }
    }
    
    private func willWrite(central: Central, UUID: Bluetooth.UUID, value: Data, newValue: Data) -> Bluetooth.ATT.Error? {
        
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
            
            for key in keys {
                
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
            
            for key in keys {
                
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
            
            guard status == .newKey
                else { return ATT.Error.WriteNotPermitted }
            
            // deserialize
            guard let _ = LockService.NewKeyFinish.init(bigEndian: newValue)
                else { return ATT.Error.InvalidAttributeValueLength }
            
        default: fatalError("Writing to unknown characteristic \(UUID)")
        }
        
        return nil
    }
    
    private func didWrite(central: Central, UUID: Bluetooth.UUID, value: SwiftFoundation.Data, newValue: SwiftFoundation.Data){
        
        switch UUID {
            
        case LockService.Setup.UUID:
            
            // deserialize
            let key = LockService.Setup.init(bigEndian: newValue)!
            
            // validate authentication
            guard key.authenticatedWithSalt()
                else { fatalError("Unauthenticated setup key") }
            
            // set key
            self.keys = [Key(data: key.value, permission: .owner)]
            
            print("Lock setup by central \(central.identifier)")
            
            status = .unlock
            
        case LockService.Unlock.UUID:
            
            assert(status != .setup)
            
        case LockService.NewKeyParentSharedSecret.UUID:
            
            assert(status == .unlock)
            
            let newKeyParent = LockService.NewKeyParentSharedSecret.init(bigEndian: newValue)!
            
            var authenticatedKey: Key!
            
            for key in keys {
                
                if newKeyParent.authenticated(with: key.data) {
                    
                    authenticatedKey = key
                    
                    break
                }
            }
            
            let sharedSecret = newKeyParent.decrypt(key: authenticatedKey.data)!
            
            // update status
            status = .newKey
            
            let newKey = Key(data: KeyData(), permission: newKeyParent.permission)
            
            self.keys.append(newKey)
            
            // new child value
            let newKeyChild = LockService.NewKeyChildSharedSecret(sharedSecret: sharedSecret, newKey: newKey)
            
            peripheral[characteristic: LockService.NewKeyChildSharedSecret.UUID] = newKeyChild.toBigEndian()
            
        case LockService.NewKeyFinish.UUID:
            
            assert(status == .newKey)
            
            // deserialize
            let newKeyFinish = LockService.NewKeyFinish.init(bigEndian: newValue)!
            
            guard let newKey = keys.last
                else { fatalError("No keys") }
            
            self.status = .unlock
            
            guard newKeyFinish.authenticated(with: newKey.data) else {
                
                print("Invalid authentication for New Key confirmation, deleting new key")
                
                keys.removeLast()
                
                return
            }
            
            print("Successfully created new \(newKey.permission) key")
            
        default: fatalError("Writing to characteristic \(UUID)")
        }
    }
    
    // MARK: GPIO
    
    private func resetSwitchPressed(gpio: GPIO) {
        
        assert(gpio === ResetSwitch)
        
        guard gpio.value == 0 else { return }
        
        print("Resetting...")
        
        system("reboot")
    }
}
