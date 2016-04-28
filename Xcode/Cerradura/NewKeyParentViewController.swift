//
//  NewKeyParentViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/26/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth
import SwiftFoundation
import GATT
import CoreLock

final class NewKeyParentViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var codeLabel: UILabel!
    
    @IBOutlet weak var doneBarItem: UIBarButtonItem!
    
    // MARK: - Properties
    
    var newKey: (identifier: UUID, permission: Permission)!
    
    private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    private lazy var central = CentralManager()
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard newKey != nil else { fatalError("Controller not configured") }
        
        central.stateChanged = stateChanged
        
        central.log = { print("Central: " + $0) }
        
        self.navigationItem.hidesBackButton = true
        
        doneBarItem.isEnabled = false
        
        if central.state == .poweredOn {
            
            self.setupNewKey()
        }
    }
    
    // MARK: - Actions
    
    @IBAction func done(_ sender: AnyObject?) {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Methods
    
    private func stateChanged(state: CBCentralManagerState) {
        
        mainQueue {
            
            if state == .poweredOn {
                
                self.setupNewKey()
                
            } else {
                
                self.newKeyError("Bluetooth disabled")
            }
        }
    }
    
    /// Perform a task on the internal queue.
    private func async(_ block: () -> ()) {
        
        dispatch_async(queue) { block() }
    }
    
    private func setupNewKey() {
        
        let newKey = self.newKey
        
        guard let parentKey = Store.shared[key: newKey.identifier]
            else { newKeyError("The key for the specified lock has been deleted from the database."); return }
        
        print("Setting up new key for lock \(newKey.identifier)...")
        
        async {
            
            let peripherals = self.central.scan(duration: 2)
            
            var lockPeripheral: Peripheral!
            
            for peripheral in peripherals {
                
                do {
                    
                    try self.central.connect(to: peripheral)
                    
                    let services = try self.central.discoverServices(for: peripheral)
                    
                    guard services.contains({ $0.UUID == LockService.UUID })
                        else { continue }
                    
                    let characteristics = try self.central.discoverCharacteristics(for: LockService.UUID, peripheral: peripheral)
                    
                    guard characteristics.contains({ $0.UUID == LockService.Identifier.UUID }) &&
                        characteristics.contains({ $0.UUID == LockService.NewKeyParentSharedSecret.UUID })
                        else { continue }
                    
                    let identifierValue = try self.central.read(characteristic: LockService.Identifier.UUID, service: LockService.UUID, peripheral: peripheral)
                    
                    // validate identifier
                    guard let identifier = LockService.Identifier.init(bigEndian: identifierValue)
                        where identifier.value == newKey.identifier
                        else { continue }
                    
                    lockPeripheral = peripheral
                    break
                }
                    
                catch { continue }
            }
            
            guard lockPeripheral != nil
                else { mainQueue { self.newKeyError("Could not find lock") }; return }
            
            // write to parent new key characteristic
            
            let sharedSecret = SharedSecret()
            
            let parentNewKey = LockService.NewKeyParentSharedSecret.init(sharedSecret: sharedSecret, parentKey: parentKey, permission: newKey.permission)
            
            do { try self.central.write(data: parentNewKey.toBigEndian(), response: true, characteristic: LockService.NewKeyParentSharedSecret.UUID, service: LockService.UUID, peripheral: lockPeripheral) }
                
            catch { mainQueue { self.newKeyError("Could not create new key. (\(error))") }; return }
            
            print("Successfully put lock \(newKey.identifier) in new key mode")
            
            mainQueue {
                
                self.doneBarItem.isEnabled = true
                self.codeLabel.isHidden = false
                self.codeLabel.text = "\(sharedSecret)"
                self.activityIndicatorView.stopAnimating()
            }
        }
    }
    
    private func newKeyError(_ error: String) {
        
        self.showErrorAlert(error, okHandler: { self.dismiss(animated: true, completion: nil) })
    }
}