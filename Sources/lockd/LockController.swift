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
    
    let peripheral = PeripheralManager()
    
    var status: CoreLock.Status = .Setup {
        
        didSet { didChangeStatus(oldValue: oldValue) }
    }
    
    let configuration: Configuration = Configuration()
    
    private var lockServiceID: Int?
    
    // MARK: - Intialization
    
    private init() {
        
        addLockService()
        
        loadStatus()
        
        peripheral.log = { print("Peripheral: " + $0) }
        
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
        
        let lockService = Service(UUID: LockProfile.LockService.Identifier.UUID, primary: true, characteristics: [identifier, model, version, status, action])
        
        lockServiceID = try! peripheral.add(service: lockService)
    }
    
    private func loadStatus() {
        
        status = .Setup
    }
    
    private func didChangeStatus(oldValue: Status) {
        
        if status != oldValue {
            
            print("Status \(oldValue) -> \(status)")
            
        } else {
            
            print("Status \(status)")
        }
        
        /*
        switch status {
            
        case .Setup:
            
            
        }*/
    }
}
