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
    
    var visible = false
    
    private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    private var foundLock: (peripheral: Peripheral, UUID: SwiftFoundation.UUID, status: Status)?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        visible = true
        
        central = CentralManager()
        
        central.stateChanged = stateChanged
        
        central.log = { print("Central: " + $0) }
        
        if central.state == .poweredOn {
            
            startScan()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        visible = true
        
        actionButton.isEnabled = true
        
        if centralStateLoaded {
            
            if central.state == .poweredOn {
                
                startScan()
                
            } else {
                
                bluetoothDisabled()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        visible = false
    }
    
    // MARK: - Actions
    
    @IBAction func actionButton(_ sender: UIButton) {
        
        guard let lock = self.foundLock else { return }
        
        switch lock.status {
            
        case .setup:
            
            // ask for name
            requestLockName { (lockName) in
                
                guard let name = lockName else { return }
                
                sender.isEnabled = false
                
                self.async {
                    
                    print("Setting up lock \(lock.UUID) (\(name))")
                    
                    let key = KeyData()
                    
                    let setup = LockProfile.SetupService.Key.init(value: key)
                    
                    do {
                        
                        let characteristics = try self.central.discoverCharacteristics(for: LockProfile.SetupService.UUID, peripheral: lock.peripheral)
                        
                        guard characteristics.contains({ $0.UUID == LockProfile.SetupService.Key.UUID })
                            else { mainQueue { self.actionError("Setup characteristic not found") }; return }
                        
                        try self.central.write(data: setup.toBigEndian(), response: true, characteristic: LockProfile.SetupService.Key.UUID, service: LockProfile.SetupService.UUID, peripheral: lock.peripheral)
                        
                        let statusValue = try self.central.read(characteristic: LockProfile.LockService.Status.UUID, service: LockProfile.LockService.UUID, peripheral: lock.peripheral)
                        
                        guard let status = LockProfile.LockService.Status.init(bigEndian: statusValue)
                            else { mainQueue { self.actionError("Invalid status value") }; return }
                        
                        guard status.value == .unlock
                            else { mainQueue { self.actionError("Could not setup new lock") }; return }
                        
                        self.foundLock!.status = status.value
                    }
                        
                    catch { mainQueue { self.actionError("\(error)") }; return }
                    
                    // save key + name
                    print("Successfully setup lock \(lock.UUID) (\(name))")
                    
                    // update UI (should go to unlock mode)
                    mainQueue { self.updateUI() }
                }
            }
            
        case .unlock:
            
            print("Unlocking")
            
            sender.isEnabled = false
            
            self.async {
                
                
            }
            
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
        self.updateUI()
    }
    
    private func startScan() {
        
        print("Scanning...")
        
        self.foundLock = nil
        
        // update UI
        self.updateUI()
        
        async { [weak self] in
            
            while self?.central.state == .poweredOn && self?.foundLock == nil && self?.visible == true {
                
                guard let controller = self else { return }
                
                let foundDevices = controller.central.scan(duration: controller.scanDuration)
                
                if foundDevices.count > 0 { print("Found \(foundDevices.count) peripherals") }
                
                for peripheral in foundDevices {
                    
                    do { try controller.central.connect(to: peripheral) }
                        
                    catch { print("Cound not connect to \(peripheral.identifier) (\(error))"); continue }
                    
                    guard let services = try? controller.central.discoverServices(for: peripheral)
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
                
                let services = try controller.central.discoverServices(for: peripheral)
                
                guard services.contains({ $0.UUID == LockProfile.LockService.UUID })
                    else { controller.actionError("Lock service not found"); return }
                
                let characteristics = try controller.central.discoverCharacteristics(for: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard characteristics.contains({ $0.UUID == LockProfile.LockService.Status.UUID })
                    else { controller.actionError("Status characteristic not found"); return }
                
                let statusValue = try controller.central.read(characteristic: LockProfile.LockService.Status.UUID, service: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard let status = LockProfile.LockService.Status.init(bigEndian: statusValue)
                    else { controller.actionError("Invalid data for Lock status"); return }
                
                lockStatus = status.value
                
                // get lock UUID
                
                guard characteristics.contains({ $0.UUID == LockProfile.LockService.Identifier.UUID })
                    else { controller.actionError("Identifier characteristic not found"); return }
                
                let identifierValue = try controller.central.read(characteristic: LockProfile.LockService.Identifier.UUID, service: LockProfile.LockService.UUID, peripheral: peripheral)
                
                guard let identifier = LockProfile.LockService.Identifier.init(bigEndian: identifierValue)
                    else { controller.actionError("Invalid data for Lock identifier"); return }
                
                lockUUID = identifier.value
            }
            
            catch { controller.actionError("\(error)"); return }
            
            print("Lock UUID: \(lockUUID)")
            print("Lock status: \(lockStatus)")
            
            controller.foundLock = (peripheral, lockUUID, lockStatus)
            
            mainQueue { controller.updateUI() }
        }
    }
    
    private func actionError(_ error: String) {
        
        print(error)
        
        // update UI
        setTitle("Error")
        
        self.actionButton.isEnabled = true
        
        showErrorAlert(localizedText: error, okHandler: { self.startScan() })
    }
    
    private func setTitle(_ title: String) {
        
        self.navigationItem.title = title
    }
    
    private func lockName(_ UUID: SwiftFoundation.UUID) -> String? {
        
        return nil
    }
    
    private func updateUI() {
        
        // No lock
        guard let lock = foundLock else {
            
            if central.state == .poweredOn {
                
                setTitle("Scanning...")
                
                let image1 = UIImage(named: "scan1")!
                let image2 = UIImage(named: "scan2")!
                let image3 = UIImage(named: "scan3")!
                let image4 = UIImage(named: "scan4")!
                
                self.actionButton.isHidden = true
                self.actionButton.setImage(nil, for: UIControlState(rawValue: 0))
                self.actionImageView.isHidden = false
                self.actionImageView.animationImages = [image1, image2, image3, image4]
                self.actionImageView.animationDuration = 2.0
                self.actionImageView.startAnimating()
                
            } else {
                
                self.setTitle("Error")
                
                let image1 = UIImage(named: "bluetoothLogo")!
                let image2 = UIImage(named: "bluetoothLogoDisabled")!
                
                self.actionButton.isHidden = true
                self.actionButton.setImage(nil, for: UIControlState(rawValue: 0))
                self.actionImageView.isHidden = false
                self.actionImageView.animationImages = [image1, image2]
                self.actionImageView.animationDuration = 2.0
                self.actionImageView.startAnimating()
                
                self.showErrorAlert(localizedText: "Bluetooth disabled")
            }
            
            return
        }
        
        switch lock.status {
            
        case .setup:
            
            // setup UI
            
            self.setTitle("New Lock")
            
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = true
            self.actionButton.setImage(UIImage(named: "setupLock")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "setupLockSelected")!, for: UIControlState.highlighted)
            
        case .unlock:
            
            // Unlock UI (if possible)
            
            // set lock name (if any)
            let lockName = self.lockName(lock.UUID) ?? "Lock"
            self.setTitle(lockName)
            
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = true
            self.actionButton.setImage(UIImage(named: "unlockButton")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "unlockButtonSelected")!, for: UIControlState.highlighted)
            
        case .newKey:
            
            // new key UI
            
            // set lock name (if any)
            let lockName = self.lockName(lock.UUID) ?? "New Key"
            self.setTitle(lockName)
            
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = true
            self.actionButton.setImage(UIImage(named: "setupKey")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "setupKeySelected")!, for: UIControlState.highlighted)
            
        default: fatalError("not implemented")
        }
    }
    
    /// Ask's the user for the lock's name.
    private func requestLockName(_ completion: String? -> ()) {
        
        let alert = UIAlertController(title: NSLocalizedString("Lock Name", comment: "LockName"),
                                      message: "Type a user friendly name for the lock.",
                                      preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField { $0.text = "New Lock" }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: UIAlertActionStyle.`default`, handler: { (UIAlertAction) in
            
            completion(alert.textFields![0].text)
            
            alert.dismiss(animated: true) {  }
            
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: UIAlertActionStyle.destructive, handler: { (UIAlertAction) in
            
            completion(nil)
            
            alert.dismiss(animated: true) {  }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
}
