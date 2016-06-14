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
import KeychainAccess

final class TodayViewController: UIViewController, NCWidgetProviding, AsyncProtocol {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var actionButton: UIButton!
    
    // MARK: - Private Properties
    
    internal lazy var queue: dispatch_queue_t = dispatch_queue_create("\(self.dynamicType) Internal Queue", DISPATCH_QUEUE_SERIAL)
    
    private var foundLock: (lock: SwiftFoundation.UUID, key: KeyData)? {
        
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
        
        let keychain = Keychain(accessGroup: AppGroup)
        
        print("All Keys: ", keychain.allKeys())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.scan()
    }
    
    // MARK: - Actions
    
    @IBAction func scan(_ sender: AnyObject? = nil) {
        
        // remove current lock (updates UI)
        if foundLock != nil { foundLock = nil }
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            do { try LockManager.shared.scan() }
                
            catch { mainQueue { controller.actionError("\(error)") }; return }
            
            // observer callback will update UI
        }
    }
    
    @IBAction func unlock(_ sender: UIButton) {
        
        guard let foundLock = self.foundLock else { return }
        
        print("Unlocking")
        
        sender.isEnabled = false
        
        async {
            
            do { try LockManager.shared.unlock(foundLock.lock, key: foundLock.key) }
                
            catch { mainQueue { self.actionError("\(error)") }; return }
            
            print("Successfully unlocked lock \"\(foundLock.lock)\"")
            
            mainQueue { self.updateUI() }
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
        
        print("Fetched locks: \(locks.map({ $0.UUID }))")
        
        mainQueue {
            
            guard let lockIdentifier = locks.first?.UUID,
                let lock = Store.shared[lockIdentifier]
                else { self.scan(); return }
            
            self.foundLock = (lockIdentifier, lock.key.data)
        }
    }
    
    private func actionError(_ error: String) {
        
        print("Error: " + error)
        
        self.scan()
    }
    
    private func updateUI() {
        
        print("Found lock \(foundLock?.lock.description ?? "(null)")")
                
        guard foundLock != nil else {
            
            self.activityIndicator.isHidden = false
            self.activityIndicator.startAnimating()
            self.actionButton.isHidden = true
            
            return
        }
        
        self.activityIndicator.stopAnimating()
        self.actionButton.isHidden = false
    }
    
    // MARK: - NCWidgetProviding
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> ())) {
        
        print("Update Today Extension")
        
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        async {
            
            do { try LockManager.shared.scan(duration: 5) }
            
            catch { print("Error scanning for lock: \(error)") }
            
            completionHandler(NCUpdateResult.newData)
        }
    }
}
