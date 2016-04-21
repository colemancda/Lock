//
//  NearLockViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/20/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth
import SwiftFoundation
import Bluetooth
import GATT
import CoreLock

final class NearLockViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var actionButton: UIButton!
    
    @IBOutlet weak var actionImageView: UIImageView!
    
    // MARK: - Properties
    
    let scanDuration = 5
    
    var central: CentralManager!
    
    var centralStateLoaded = false
    
    private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    private var lockInfo: (UUID: SwiftFoundation.UUID, status: Status)?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central = CentralManager()
        
        central.log = { print("Central: " + $0) }
        
        central.stateChanged = stateChanged
        
        self.startScan()
        
        async {
            
            sleep(5)
            
            mainQueue {
                
                if self.centralStateLoaded == false {
                    
                    self.centralStateLoaded = true
                    
                    if self.central.state == .poweredOn {
                        
                        
                        
                    } else {
                        
                        self.bluetoothDisabled()
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if centralStateLoaded {
            
            if central.state == .poweredOn {
                
                startScan()
                
            } else {
                
                bluetoothDisabled()
            }
        }
        
    }
    
    // MARK: - Actions
    
    @IBAction func actionButton(_ sender: UIButton) {
        
        guard let lock = self.lockInfo else { return }
        
        switch lock.status {
            
        case .setup: break
            
        case .unlock: break
            
        case .newKey: break
            
        case .update: break
        }
    }
    
    // MARK: - Private Methods
    
    /// Perform a task on the internal queue.
    private func async(_ block: () -> ()) {
        
        dispatch_async(queue) { block() }
    }
    
    private func stateChanged(state: CBCentralManagerState) {
        
        centralStateLoaded = true
        
        if state == .poweredOn {
            
            startScan()
            
        } else {
            
            bluetoothDisabled()
        }
    }
    
    private func bluetoothDisabled() {
        
        print("Bluetooth disabled")
        
        self.lockInfo = nil
        
        // update UI
        
        setTitle("Scanning...")
        
        let image1 = UIImage(named: "bluetoothLogo")!
        let image2 = UIImage(named: "bluetoothLogoDisabled")!
        
        self.actionButton.setImage(nil, for: UIControlState(rawValue: 0))
        self.actionImageView.animationImages = [image1, image2]
        self.actionImageView.animationDuration = 2.0
        self.actionImageView.startAnimating()
        
        self.showErrorAlert(localizedText: "Enable Bluetooth")
    }
    
    private func startScan() {
        
        print("Starting scan")
        
        self.lockInfo = nil
        
        // update UI
        setTitle("Scanning...")
        
        async { [weak self] in
            
            while self?.central.state == .poweredOn && self?.lockInfo == nil {
                
                guard let controller = self else { return }
                
                print("Scanning for \(controller.scanDuration) seconds")
                
                let foundDevices = controller.central.scan(duration: controller.scanDuration)
                
                print("Found \(foundDevices.count) peripherals")
                
                for peripheral in foundDevices {
                    
                    do { try controller.central.connect(peripheral) }
                        
                    catch { print("Cound not connect to \(peripheral.identifier) (\(error))"); continue }
                    
                    guard let services = try? controller.central.discover(services: peripheral)
                        else { continue }
                    
                    // found lock
                    if services.contains({ $0.UUID == LockProfile.LockService.UUID }) {
                        
                        controller.foundLock(peripheral: peripheral)
                        return
                    }
                }
            }
        }
    }
    
    private func foundLock(peripheral: Peripheral) {
        
        print("Found lock peripheral \(peripheral.identifier)")
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            var lockStatus: CoreLock.Status!
            
            var lockUUID: SwiftFoundation.UUID!
            
            do {
                
                // get lock status
                
                let services = try controller.central.discover(services: peripheral)
                
                guard services.contains({ $0.UUID == LockProfile.LockService.UUID })
                    else { controller.foundLockError("Lock service not found"); return }
                
                let characteristics = try controller.central.discover(characteristics: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard characteristics.contains({ $0.UUID == LockProfile.LockService.Status.UUID })
                    else { controller.foundLockError("Status characteristic not found"); return }
                
                let statusValue = try controller.central.read(characteristic: LockProfile.LockService.Status.UUID, service: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard let status = LockProfile.LockService.Status.init(bigEndian: statusValue)
                    else { controller.foundLockError("Invalid data for Lock status"); return }
                
                lockStatus = status.value
                
                // get lock UUID
                
                guard characteristics.contains({ $0.UUID == LockProfile.LockService.Identifier.UUID })
                    else { controller.foundLockError("Identifier characteristic not found"); return }
                
                let identifierValue = try controller.central.read(characteristic: LockProfile.LockService.Identifier.UUID, service: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard let identifier = LockProfile.LockService.Identifier.init(bigEndian: identifierValue)
                    else { controller.foundLockError("Invalid data for Lock identifier"); return }
                
                lockUUID = identifier.value
            }
            
            catch { controller.foundLockError("\(error)"); return }
            
            print("Lock UUID: \(lockUUID)")
            print("Lock status: \(lockStatus)")
            
            controller.lockInfo = (lockUUID, lockStatus)
            
            mainQueue {
                
                switch lockStatus! {
                    
                case .setup:
                    
                    // setup UI
                    
                    controller.setTitle("New Lock")
                    
                    
                    
                    break
                    
                case .unlock:
                    
                    // Unlock UI (if possible)
                    
                    // set lock name (if any)
                    let lockName = controller.lockName(lockUUID) ?? "Lock"
                    controller.setTitle(lockName)
                    
                    
                    
                    break
                    
                case .newKey:
                    
                    // new key UI
                    
                    break
                    
                default: fatalError("not implemented")
                }
            }
        }
    }
    
    private func foundLockError(_ error: String) {
        
        print("Found lock error: " + error)
        
        // update UI
    }
    
    private func setTitle(_ title: String) {
        
        self.navigationItem.title = title
    }
    
    private func lockName(_ UUID: SwiftFoundation.UUID) -> String? {
        
        return nil
    }
}
