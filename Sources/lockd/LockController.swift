//
//  LockController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/17/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

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
        
        self.keys = loadKeys()
        
        if keys.first == nil {
            
            status = .setup
            
        } else {
            
            status = .unlock
        }
        
        #if os(Linux)
            peripheral = PeripheralManager()
        #else
            peripheral = PeripheralManager(localName: "Test Lock")
        #endif
        
        peripheral.log = { print("Peripheral: " + $0) }
        
        peripheral.willWrite = willWrite
        peripheral.willRead = willRead
        peripheral.didWrite = didWrite
        
        addLockService()
        
        try! peripheral.start()
    }
    
    // MARK: - Methods
    
    private func addLockService() {
        
        let identifierValue = LockService.Identifier(value: configuration.identifier).toBigEndian()
        
        let identifier = Characteristic(UUID: LockService.Identifier.UUID, value: identifierValue, permissions: [.Read], properties: [.Read])
        
        let modelValue = LockService.Model(value: configuration.model).toBigEndian()
        
        let model = Characteristic(UUID: LockService.Model.UUID, value: modelValue, permissions: [.Read], properties: [.Read])
                
        let versionValue = LockService.Version(value: CoreLockVersion).toBigEndian()
        
        let version = Characteristic(UUID: LockService.Version.UUID, value: versionValue, permissions: [.Read], properties: [.Read])
        
        let statusValue = LockService.Status(value: self.status).toBigEndian()
        
        let status = Characteristic(UUID: LockService.Status.UUID, value: statusValue, permissions: [.Read], properties: [.Read])
        
        let action = Characteristic(UUID: LockService.Action.UUID, permissions: [.Write], properties: [.Write])
        
        let setup = Characteristic(UUID: LockService.Setup.UUID, permissions: [.Write], properties: [.Write])
        
        let unlock = Characteristic(UUID: LockService.Unlock.UUID, permissions: [.Write], properties: [.Write])
        
        let newKeyParent = Characteristic(UUID: LockService.NewKeyParentSharedSecret.UUID, permissions: [.Write], properties: [.Write])
        
        let newKeyChild = Characteristic(UUID: LockService.NewKeyChildKey.UUID, value: Data(), permissions: [.Read], properties: [.Read])
        
        let lockService = Service(UUID: LockService.UUID, primary: true, characteristics: [identifier, model, version, status, action, setup, unlock, newKeyParent, newKeyChild])
        
        try! peripheral.add(service: lockService)
    }
    
    private func didChangeStatus(oldValue: Status) {
        
        print("Status \(oldValue) -> \(status)")
        
        peripheral[characteristic: LockService.Status.UUID] = LockService.Status(value: self.status).toBigEndian()
    }
    
    private func willRead(central: Central, UUID: Bluetooth.UUID, value: Data, offset: Int) -> Bluetooth.ATT.Error? {
        
        return nil
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
            
            return nil
            
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
            
            print("Unlocked by central \(central.identifier)")
            
            return nil
            
        default: fatalError("Writing to characteristic \(UUID)")
        }
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
            
        default: fatalError("Writing to characteristic \(UUID)")
        }
    }
}
