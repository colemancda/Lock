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
    
    let scanDuration = 2
    
    var central: CentralManager!
    
    var centralStateLoaded = false
    
    private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    private var foundLock: (peripheral: Peripheral, UUID: SwiftFoundation.UUID, status: Status)?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central = CentralManager()
        
        central.stateChanged = stateChanged
        
        central.log = { print("Central: " + $0) }
        
        if central.state == .poweredOn {
            
            startScan()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        actionButton.isEnabled = true
        
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
        
        guard let lock = self.foundLock else { return }
        
        switch lock.status {
            
        case .setup:
            
            sender.isEnabled = false
            
            async {
                
                self.central.write()
            }
            
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
        
        mainQueue {
            
            self.centralStateLoaded = true
            
            if state == .poweredOn {
                
                self.startScan()
                
            } else {
                
                self.bluetoothDisabled()
            }
        }
    }
    
    private func bluetoothDisabled() {
        
        print("Bluetooth disabled")
        
        self.foundLock = nil
        
        // update UI
        
        setTitle("Error")
        
        let image1 = UIImage(named: "bluetoothLogo")!
        let image2 = UIImage(named: "bluetoothLogoDisabled")!
        
        self.actionImageView.isHidden = false
        self.actionButton.setImage(nil, for: UIControlState(rawValue: 0))
        self.actionImageView.animationImages = [image1, image2]
        self.actionImageView.animationDuration = 2.0
        self.actionImageView.startAnimating()
        
        self.showErrorAlert(localizedText: "Bluetooth disabled")
    }
    
    private func startScan() {
        
        print("Starting scan")
        
        self.foundLock = nil
        
        // update UI
        setTitle("Scanning...")
        
        let image1 = UIImage(named: "scan1")!
        let image2 = UIImage(named: "scan2")!
        let image3 = UIImage(named: "scan3")!
        let image4 = UIImage(named: "scan4")!
        
        self.actionImageView.isHidden = false
        self.actionButton.setImage(nil, for: UIControlState(rawValue: 0))
        self.actionImageView.animationImages = [image1, image2, image3, image4]
        self.actionImageView.animationDuration = 2.0
        self.actionImageView.startAnimating()
        
        async { [weak self] in
            
            while self?.central.state == .poweredOn && self?.foundLock == nil {
                
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
            
            controller.foundLock = (peripheral, lockUUID, lockStatus)
            
            mainQueue {
                
                switch lockStatus! {
                    
                case .setup:
                    
                    // setup UI
                    
                    controller.setTitle("New Lock")
                    
                    controller.actionImageView.stopAnimating()
                    controller.actionImageView.animationImages = nil
                    controller.actionImageView.isHidden = true
                    controller.actionButton.setImage(UIImage(named: "setupLock")!, for: UIControlState(rawValue: 0))
                    controller.actionButton.setImage(UIImage(named: "setupLockSelected")!, for: UIControlState.highlighted)
                    
                    break
                    
                case .unlock:
                    
                    // Unlock UI (if possible)
                    
                    // set lock name (if any)
                    let lockName = controller.lockName(lockUUID) ?? "Lock"
                    controller.setTitle(lockName)
                    
                    
                    
                    break
                    
                case .newKey:
                    
                    // new key UI
                    
                    controller.actionImageView.stopAnimating()
                    controller.actionImageView.animationImages = nil
                    controller.actionImageView.isHidden = true
                    controller.actionButton.setImage(UIImage(named: "setupKey")!, for: UIControlState(rawValue: 0))
                    controller.actionButton.setImage(UIImage(named: "setupKeySelected")!, for: UIControlState.highlighted)
                    
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
