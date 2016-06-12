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
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard newKey != nil else { fatalError("Controller not configured") }
        
        self.navigationItem.hidesBackButton = true
        
        doneBarItem.isEnabled = false
        
        setupNewKey()
    }
    
    // MARK: - Actions
    
    @IBAction func done(_ sender: AnyObject?) {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Methods
    
    /// Perform a task on the internal queue.
    private func async(_ block: () -> ()) {
        
        dispatch_async(queue) { block() }
    }
    
    private func setupNewKey() {
        
        guard let parentKey = Store.shared[key: newKey.identifier]
            else { newKeyError("The key for the specified lock has been deleted from the database."); return }
        
        print("Setting up new key for lock \(newKey.identifier)...")
        
        async {
            
            // write to parent new key characteristic
            
            let sharedSecret = SharedSecret()
            
            do {
                
                guard var lock = try LockManager.shared.scan(duration: 1, filter: self.newKey.identifier)
                    else { mainQueue { self.newKeyError("Lock not found") }; return }
                
                try LockManager.shared.createNewKey(lock: &lock, permission: self.newKey.permission, parentKey: parentKey, sharedSecret: sharedSecret)
            }
                
            catch { mainQueue { self.newKeyError("Could not create new key. (\(error))") }; return }
            
            print("Successfully put lock \(self.newKey.identifier) in new key mode")
            
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