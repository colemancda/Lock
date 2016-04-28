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
    
    private var central: CentralManager!
    
    private var centralStateLoaded = false
    
    private var visible = false
    
    private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    private var foundLock: (peripheral: Peripheral, UUID: SwiftFoundation.UUID, status: Status, model: Model, version: UInt64)?
    
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
    
    @IBAction func newKey(_ sender: UITabBarItem) {
        
        guard let foundLock = self.foundLock else { return }
        
        let navigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "newKeyNavigationStack") as! UINavigationController
        
        let destinationViewController = navigationController.viewControllers.first! as! NewKeySelectPermissionViewController
        
        destinationViewController.lockIdentifier = foundLock.UUID
        
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @IBAction func actionButton(_ sender: UIButton) {
        
        guard let foundLock = self.foundLock else { return }
        
        switch foundLock.status {
            
        case .setup:
            
            // ask for name
            requestLockName { (lockName) in
                
                guard let name = lockName else { return }
                
                sender.isEnabled = false
                
                self.async {
                    
                    do {
                        
                        // write to setup characteristic
                        
                        print("Setting up lock \(foundLock.UUID) (\(name))")
                        
                        let key = Key(data: KeyData(), permission: .owner)
                        
                        let setup = LockService.Setup.init(value: key.data)
                        
                        try self.central.write(data: setup.toBigEndian(), response: true, characteristic: LockService.Setup.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
                        
                        // read lock service values
                        
                        let statusValue = try self.central.read(characteristic: LockService.Status.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
                        
                        guard let status = LockService.Status.init(bigEndian: statusValue)
                            else { mainQueue { self.actionError("Invalid status value") }; return }
                        
                        guard status.value == .unlock
                            else { mainQueue { self.actionError("Could not setup new lock") }; return }
                        
                        // save in Store
                        let newLock = Lock(identifier: foundLock.UUID, name: name, model: foundLock.model, version: foundLock.version, key: key)
                        
                        Store.shared[newLock.identifier] = newLock
                            
                        print("Successfully setup lock \(name) \(foundLock)")
                        
                        mainQueue {
                            
                            // in case the user left the VC
                            if self.foundLock?.UUID == foundLock.UUID {
                                
                                self.foundLock!.status = status.value
                                
                                // update UI (should go to unlock mode)
                                mainQueue { self.updateUI() }
                            }
                        }
                    }
                        
                    catch { mainQueue { self.actionError("\(error)") }; return }
                }
            }
            
        case .unlock:
            
            print("Unlocking")
            
            sender.isEnabled = false
            
            guard let cachedLock = Store.shared[foundLock.UUID]
                else { self.actionError("No stored key for lock"); return }
            
            let unlock = LockService.Unlock.init(key: cachedLock.key.data)
            
            async {
                
                // write to unlock characteristic
                
                do { try self.central.write(data: unlock.toBigEndian(), response: true, characteristic: LockService.Unlock.UUID, service: LockService.UUID, peripheral: foundLock.peripheral) }
                
                catch { mainQueue { self.actionError("\(error)") }; return }
                
                print("Successfully unlocked lock \(foundLock.UUID)")
                
                mainQueue { self.updateUI() }
            }
            
        case .newKey:
            
            requestNewKey { (textValues) in
                
                guard let textValues = textValues else { return }
                
                // build shared secret from text
                guard let sharedSecret = SharedSecret(string: textValues.sharedSecret)
                    else { self.actionError("Invalid PIN code"); return }
                
                sender.isEnabled = false
                
                self.async {
                    
                    do {
                        
                        // read new key child characteristic
                        
                        let newKeyChildValue = try self.central.read(characteristic: LockService.NewKeyChildSharedSecret.UUID, service: LockService.UUID, peripheral: foundLock.peripheral)
                        
                        guard let newKeyChild = LockService.NewKeyChildSharedSecret.init(bigEndian: newKeyChildValue)
                            else { mainQueue { self.actionError("Invalid value for new key characteristic") }; return }
                        
                        guard let key = newKeyChild.decrypt(sharedSecret: sharedSecret)
                            else { mainQueue { self.actionError("Invalid PIN code") }; return }
                        
                        // write confirmation value
                        
                        
                        mainQueue {
                            
                            let lock = Lock(identifier: foundLock.UUID, name: textValues.name, model: foundLock.model, version: foundLock.version, key: key)
                            
                            Store.shared[foundLock.UUID] = lock
                            
                            print("Successfully added new key for lock \(textValues.name)")
                        }
                    }
                    
                    catch { mainQueue { self.actionError("\(error)") }; return }
                }
            }
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
                    if services.contains({ $0.UUID == LockService.UUID }) {
                        
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
            
            do {
                
                // get lock status
                
                let characteristics = try controller.central.discoverCharacteristics(for: LockService.UUID, peripheral: peripheral)
                
                guard characteristics.contains({ $0.UUID == LockService.Status.UUID })
                    else { controller.actionError("Status characteristic not found"); return }
                
                let statusValue = try controller.central.read(characteristic: LockService.Status.UUID, service: LockService.UUID, peripheral: peripheral)
                
                guard let status = LockService.Status.init(bigEndian: statusValue)
                    else { controller.actionError("Invalid data for Lock status"); return }
                
                // get lock UUID
                
                guard characteristics.contains({ $0.UUID == LockService.Identifier.UUID })
                    else { controller.actionError("Identifier characteristic not found"); return }
                
                let identifierValue = try controller.central.read(characteristic: LockService.Identifier.UUID, service: LockService.UUID, peripheral: peripheral)
                
                guard let identifier = LockService.Identifier.init(bigEndian: identifierValue)
                    else { controller.actionError("Invalid data for Lock identifier"); return }
                
                // get model
                
                let modelValue = try controller.central.read(characteristic: LockService.Model.UUID, service: LockService.UUID, peripheral: peripheral)
                
                guard let model = LockService.Model.init(bigEndian: modelValue)
                    else { mainQueue { controller.actionError("Invalid Model value") }; return }
                
                // get version
                
                let versionValue = try controller.central.read(characteristic: LockService.Version.UUID, service: LockService.UUID, peripheral: peripheral)
                
                guard let version = LockService.Version.init(bigEndian: versionValue)
                    else { mainQueue { controller.actionError("Invalid Version value") }; return }
                
                // validate other characteristics
                
                guard characteristics.contains({ $0.UUID == LockService.Setup.UUID })
                    else { mainQueue{ controller.actionError("Setup characteristic not found") }; return }
                
                guard characteristics.contains({ $0.UUID == LockService.Unlock.UUID })
                    else { mainQueue{ controller.actionError("Unlock characteristic not found") }; return }
                
                guard characteristics.contains({ $0.UUID == LockService.NewKeyParentSharedSecret.UUID })
                    else { mainQueue{ controller.actionError("Parent Shared Secret characteristic not found") }; return }
                
                guard characteristics.contains({ $0.UUID == LockService.NewKeyChildSharedSecret.UUID })
                    else { mainQueue { controller.actionError("Child Key characteristic not found") }; return }
                
                mainQueue {
                    
                    controller.foundLock = (peripheral, identifier.value, status.value, model.value, version.value)
                    
                    print("Lock \(controller.foundLock!)")
                    
                    controller.updateUI()
                }
            }
            
            catch { mainQueue { controller.actionError("\(error)") }; return }
        }
    }
    
    private func actionError(_ error: String) {
        
        print("Error: " + error)
        
        // update UI
        self.setTitle("Error")
        
        self.actionButton.isEnabled = true
        
        showErrorAlert(error, okHandler: { self.startScan() })
    }
    
    private func setTitle(_ title: String) {
        
        self.navigationItem.title = title
    }
    
    private func updateUI() {
        
        self.navigationItem.rightBarButtonItem = nil
        
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
                
                self.showErrorAlert("Bluetooth disabled")
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
            
            let lockInfo = Store.shared[lock.UUID]
            
            // set lock name (if any)
            let lockName = lockInfo?.name ?? "Lock"
            self.setTitle(lockName)
            
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = (lockInfo != nil)
            self.actionButton.setImage(UIImage(named: "unlockButton")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "unlockButtonSelected")!, for: UIControlState.highlighted)
            
            // enable creating ney keys
            if lockInfo?.key.permission == .owner || lockInfo?.key.permission == .admin {
                
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newKey))
            }
            
        case .newKey:
            
            /// Cannot have duplicate keys for same lock.
            guard Store.shared[key: lock.UUID] == nil
                else { foundLock?.status = .unlock; updateUI(); return }
            
            // new key UI
            
            self.setTitle("New Key")
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = true
            self.actionButton.setImage(UIImage(named: "setupKey")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "setupKeySelected")!, for: UIControlState.highlighted)
        }
    }
    
    /// Ask's the user for the lock's name.
    private func requestLockName(_ completion: String? -> ()) {
        
        let alert = UIAlertController(title: NSLocalizedString("Lock Name", comment: "LockName"),
                                      message: "Type a user friendly name for the lock.",
                                      preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField { $0.text = "Lock" }
        
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
    
    private func requestNewKey(_ completion: (name: String, sharedSecret: String)? -> ()) {
        
        let alert = UIAlertController(title: NSLocalizedString("New Key", comment: "NewKeyTitle"),
                                      message: "Type a user friendly name for the lock and enter the PIN code.",
                                      preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField { $0.text = "Lock" }
        
        alert.addTextField { $0.placeholder = "PIN Code"; $0.keyboardType = .numberPad }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: UIAlertActionStyle.`default`, handler: { (UIAlertAction) in
            
            completion((name: alert.textFields![0].text ?? "", sharedSecret: alert.textFields![1].text ?? ""))
            
            alert.dismiss(animated: true) {  }
            
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: UIAlertActionStyle.destructive, handler: { (UIAlertAction) in
            
            completion(nil)
            
            alert.dismiss(animated: true) {  }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
}
