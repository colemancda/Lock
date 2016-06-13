//
//  TodayViewController.swift
//  CerraduraTodayExtension
//
//  Created by Alsey Coleman Miller on 6/13/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import UIKit
import NotificationCenter
import CoreBluetooth
import SwiftFoundation
import CoreLock

final class TodayViewController: UIViewController, NCWidgetProviding, AsyncProtocol {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var actionButton: UIButton!
    
    @IBOutlet weak var actionImageView: UIImageView!
    
    // MARK: - Private Properties
    
    internal lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    private var foundLock: SwiftFoundation.UUID? {
        
        didSet { updateUI() }
    }
    
    // MARK: - Loading
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.
        
        print("Loaded Today Extension")
        
        LockManager.shared.log = { print("LockManager: " + $0) }
        
        // start observing state
        let _ = LockManager.shared.state.observe(stateChanged)
        let _ = LockManager.shared.foundLocks.observe(locksUpdated)
        
        // update UI
        self.updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.scan()
    }
    
    // MARK: - Actions
    
    @IBAction func scan(sender: AnyObject? = nil) {
        
        // remove current lock (updates UI)
        if foundLock != nil { foundLock = nil }
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            do { try LockManager.shared.scan() }
                
            catch { mainQueue { controller.actionError("\(error)") }; return }
            
            // observer callback will update UI
        }
    }
    
    // MARK: - Private Methods
    
    private func stateChanged(state: CBCentralManagerState) {
        
        mainQueue {
            
            self.foundLock = nil
            
            if state == .poweredOn {
                
                self.scan()
            }
            
            self.updateUI()
        }
    }
    
    private func locksUpdated(locks: [LockManager.Lock]) {
        
        mainQueue {
            
            self.foundLock = locks.first?.UUID
            
            // continue scanning
            if self.foundLock == nil {
                
                self.scan()
            }
        }
    }
    
    private func actionError(_ error: String) {
        
        print("Error: " + error)
        
        // update UI
       //self.setTitle("Error")
        
        self.actionButton.isEnabled = true
        
        self.foundLock = nil
        
        //showErrorAlert(error, okHandler: { self.scan() })
    }
    
    private func updateUI() {
        
        self.navigationItem.rightBarButtonItem = nil
        
        self.actionButton.isEnabled = true
        
        // No lock
        guard let lockIdentifier = self.foundLock else {
            
            if LockManager.shared.state.value == .poweredOn {
                
                //self.setTitle("Scanning...")
                
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
                
                //self.setTitle("Error")
                
                let image1 = UIImage(named: "bluetoothLogo")!
                let image2 = UIImage(named: "bluetoothLogoDisabled")!
                
                self.actionButton.isHidden = true
                self.actionButton.setImage(nil, for: UIControlState(rawValue: 0))
                self.actionImageView.isHidden = false
                self.actionImageView.animationImages = [image1, image2]
                self.actionImageView.animationDuration = 2.0
                self.actionImageView.startAnimating()
                
                //self.showErrorAlert("Bluetooth disabled")
            }
            
            return
        }
        
        let lock = LockManager.shared[lockIdentifier]!
        
        func configureUnlockUI() {
            
            // Unlock UI (if possible)
            let key = Store.shared[key: lockIdentifier]
            
            // set lock name (if any)
            //let lockName = key?.name ?? "Lock"
            //self.setTitle(lockName)
            
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = (key != nil)
            self.actionButton.setImage(UIImage(named: "unlockButton")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "unlockButtonSelected")!, for: UIControlState.highlighted)
        }
        
        switch lock.status {
            
        case .setup:
            
            // setup UI
            
            //self.setTitle("New Lock")
            
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
            guard Store.shared[key: lock.UUID] == nil
                else { configureUnlockUI(); return }
            
            // new key UI
            
            //self.setTitle("New Key")
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = true
            self.actionButton.setImage(UIImage(named: "setupKey")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "setupKeySelected")!, for: UIControlState.highlighted)
        }
    }
    
    // MARK: - NCWidgetProviding
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)) {
        
        print("Update Today Extension")
        
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData

        completionHandler(NCUpdateResult.newData)
    }
    
}
