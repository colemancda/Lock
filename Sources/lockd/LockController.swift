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
    
    static let sharedController = LockController()
    
    let peripheral: PeripheralManager
    
    var status: CoreLock.Status = .Setup {
        
        didSet { didChangeStatus(oldValue: oldValue) }
    }
    
    let configuration: Configuration = Configuration()
    
    var keys = [KeyData]()
    
    private var lockServiceID: Int?
    
    private var setupServiceID: Int?
    
    private var unlockServiceID: Int?
    
    // MARK: - Intialization
    
    private init() {
        
        #if os(Linux)
            peripheral = PeripheralManager(maximumTransmissionUnit: ATT.MTU.LowEnergy.Maximum)
        #else
            peripheral = PeripheralManager(localName: "Test Lock")
        #endif
        
        peripheral.log = { print("Peripheral: " + $0) }
        
        peripheral.willWrite = willWrite
        peripheral.willRead = willRead
        
        addLockService()
        
        loadKeys()
        
        if keys.first == nil {
            
            setupMode()
            
        } else {
            
            unlockMode()
        }
        
        try! peripheral.start()
    }
    
    // MARK: - Methods
    
    private func addLockService() {
        
        assert(lockServiceID == nil)
        
        let identifierValue = LockProfile.LockService.Identifier(value: configuration.identifier).toBigEndian()
        
        let identifier = Characteristic(UUID: LockProfile.LockService.Identifier.UUID, value: identifierValue, permissions: [.Read], properties: [.Read])
        
        let modelValue = LockProfile.LockService.Model(value: configuration.model).toBigEndian()
        
        let model = Characteristic(UUID: LockProfile.LockService.Model.UUID, value: modelValue, permissions: [.Read], properties: [.Read])
                
        let versionValue = LockProfile.LockService.Version(value: CoreLockVersion).toBigEndian()
        
        let version = Characteristic(UUID: LockProfile.LockService.Version.UUID, value: versionValue, permissions: [.Read], properties: [.Read])
        
        let statusValue = LockProfile.LockService.Status(value: self.status).toBigEndian()
        
        let status = Characteristic(UUID: LockProfile.LockService.Status.UUID, value: statusValue, permissions: [.Read], properties: [.Read])
        
        let action = Characteristic(UUID: LockProfile.LockService.Action.UUID, permissions: [.Write], properties: [.Write])
        
        let lockService = Service(UUID: LockProfile.LockService.UUID, primary: true, characteristics: [identifier, model, version, status, action])
        
        lockServiceID = try! peripheral.add(service: lockService)
    }
    
    private func didChangeStatus(oldValue: Status) {
        
        print("Status \(oldValue) -> \(status)")
        
        peripheral[characteristic: LockProfile.LockService.Status.UUID] = LockProfile.LockService.Status(value: self.status).toBigEndian()
    }
    
    private func loadKeys() {
        
        
    }
    
    private func setupMode() {
        
        assert(setupServiceID == nil)
        
        status = .Setup
        
        let characteristic = Characteristic(UUID: LockProfile.SetupService.Key.UUID, permissions: [.Write], properties: [.Write])
        
        let service = Service(UUID: LockProfile.SetupService.UUID, primary: true, characteristics: [characteristic])
        
        setupServiceID = try! peripheral.add(service: service)
    }
    
    private func unlockMode() {
        
        assert(setupServiceID == nil)
        
        status = .Unlock
        
        guard unlockServiceID == nil else { return }
        
        let characteristic = Characteristic(UUID: LockProfile.UnlockService.Unlock.UUID, permissions: [.Write], properties: [.Write])
        
        let service = Service(UUID: LockProfile.UnlockService.UUID, primary: true, characteristics: [characteristic])
        
        unlockServiceID = try! peripheral.add(service: service)
    }
    
    private func willRead(central: Central, UUID: Bluetooth.UUID, value: SwiftFoundation.Data, offset: Int) -> Bluetooth.ATT.Error? {
        
        return nil
    }
    
    private func willWrite(central: Central, UUID: Bluetooth.UUID, value: SwiftFoundation.Data, newValue: (newValue: SwiftFoundation.Data, newBytes: SwiftFoundation.Data, offset: Int)) -> Bluetooth.ATT.Error? {
        
        switch UUID {
            
        case LockProfile.SetupService.Key.UUID:
            
            assert(status == .Setup, "Setup Service should not exist when the lock is not in Setup mode")
            
            // continue writing
            guard newValue.newValue.byteValue.count == LockProfile.SetupService.Key.length
                else { return nil }
            
            // deserialize
            let key = LockProfile.SetupService.Key.init(bigEndian: newValue.newValue)!
            
            // validate authentication
            guard key.authenticatedWithSalt()
                else { return ATT.Error.WriteNotPermitted }
            
            // set key
            self.keys = [key.value]
            
            print("Lock setup by central \(central.identifier)")
            
            peripheral.remove(service: setupServiceID!)
            
            unlockMode()
            
            return nil
            
        case LockProfile.UnlockService.Unlock.UUID:
            
            assert(status != .Setup, "Should not be in setup mode")
            
            // continue writing
            guard newValue.newValue.byteValue.count == LockProfile.UnlockService.Unlock.length
                else { return nil }
            
            // deserialize
            let unlock = LockProfile.UnlockService.Unlock.init(bigEndian: newValue.newValue)!
            
            var authenticatedKey: KeyData!
            
            for key in keys {
                
                if unlock.authenticated(with: key) {
                    
                    authenticatedKey = key
                    
                    break
                }
            }
            
            /// not authenticated
            guard authenticatedKey != nil else { return ATT.Error.WriteNotPermitted }
            
            print("Unlocked by central \(central.identifier)")
            
            return nil
            
        default: fatalError("Writing to characteristic \(UUID)")
        }
    }
}
