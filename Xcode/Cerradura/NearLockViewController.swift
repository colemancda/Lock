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
    
    private lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // start observing
        LockManager.shared.foundLock.observe(foundLock)
        
        LockManager.shared.state.observe(stateChanged)
        
        // update UI
        self.updateUI()
    }
    
    // MARK: - Actions
    
    @IBAction func newKey(_ sender: AnyObject?) {
        
        guard let foundLock = LockManager.shared.foundLock.value else { return }
        
        let navigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "newKeyNavigationStack") as! UINavigationController
        
        let destinationViewController = navigationController.viewControllers.first! as! NewKeySelectPermissionViewController
        
        destinationViewController.lockIdentifier = foundLock.UUID
        
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @IBAction func actionButton(_ sender: UIButton) {
        
        guard let foundLock = LockManager.shared.foundLock.value else { return }
        
        func unlock() {
            
            print("Unlocking")
            
            sender.isEnabled = false
            
            guard let cachedLock = Store.shared[foundLock.UUID]
                else { self.actionError("No stored key for lock"); return }
            
            async {
                
                do { try LockManager.shared.unlock(key: cachedLock.key.data) }
                    
                catch { mainQueue { self.actionError("\(error)") }; return }
                
                print("Successfully unlocked lock \"\(foundLock.UUID)\"")
                
                mainQueue { self.updateUI() }
            }
        }
        
        switch foundLock.status {
            
        case .setup:
            
            // ask for name
            requestLockName { (lockName) in
                
                guard let name = lockName else { return }
                
                sender.isEnabled = false
                
                self.async {
                    
                    do {
                        
                        print("Setting up lock \(foundLock.UUID) (\(name))")
                        
                        let key = try LockManager.shared.setup(name: name)
                        
                        mainQueue {
                            
                            // save in Store
                            let newLock = Lock(identifier: foundLock.UUID, name: name, model: foundLock.model, version: foundLock.version, key: key)
                            
                            Store.shared[newLock.identifier] = newLock
                            
                            print("Successfully setup lock \(name) \(foundLock)")
                            
                            mainQueue { self.updateUI() }
                        }
                    }
                        
                    catch { mainQueue { self.actionError("\(error)") }; return }
                }
            }
            
        case .unlock:
            
            unlock()
            
        case .newKey:
            
            guard Store.shared[foundLock.UUID] == nil
                else { unlock(); return }
            
            requestNewKey { (textValues) in
                
                guard let textValues = textValues else { return }
                
                // build shared secret from text
                guard let sharedSecret = SharedSecret(string: textValues.sharedSecret)
                    else { self.actionError("Invalid PIN code"); return }
                
                sender.isEnabled = false
                
                self.async {
                    
                    do {
                        
                        let key = try LockManager.shared.recieveNewKey(sharedSecret: sharedSecret)
                        
                        mainQueue {
                            
                            let lock = Lock(identifier: foundLock.UUID, name: textValues.name, model: foundLock.model, version: foundLock.version, key: key)
                            
                            Store.shared[foundLock.UUID] = lock
                            
                            print("Successfully added new key for lock \(textValues.name)")
                            
                            mainQueue { self.updateUI() }
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
            
            if state == .poweredOn {
                
                LockManager.shared.startScan()
            }
            
            self.updateUI()
        }
    }
    
    private func foundLock(lock: (peripheral: Peripheral, UUID: SwiftFoundation.UUID, status: Status, model: Model, version: UInt64)?) {
        
        mainQueue { self.updateUI() }
    }
    
    private func actionError(_ error: String) {
        
        print("Error: " + error)
        
        // update UI
        self.setTitle("Error")
        
        self.actionButton.isEnabled = true
        
        showErrorAlert(error, okHandler: { LockManager.shared.startScan() })
    }
    
    private func setTitle(_ title: String) {
        
        self.navigationItem.title = title
    }
    
    private func updateUI() {
        
        self.navigationItem.rightBarButtonItem = nil
        
        self.actionButton.isEnabled = true
        
        // No lock
        guard let lock = LockManager.shared.foundLock.value else {
            
            if LockManager.shared.state.value == .poweredOn {
                
                self.setTitle("Scanning...")
                
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
        
        func configureUnlockUI() {
            
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
            if (lockInfo?.key.permission == .owner || lockInfo?.key.permission == .admin) && lock.status == .unlock {
                
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newKey))
            }
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
            
            configureUnlockUI()
            
        case .newKey:
            
            /// Cannot have duplicate keys for same lock.
            guard Store.shared[lock.UUID] == nil
                else { configureUnlockUI(); return }
            
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
