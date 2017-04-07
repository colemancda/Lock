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
import Foundation
import GATT
import CoreLock

final class NewKeyParentViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var codeLabel: UILabel!
    
    @IBOutlet weak var doneBarItem: UIBarButtonItem!
    
    // MARK: - Properties
    
    var completion: ((Bool) -> ())?
    
    var newKey: (identifier: UUID, permission: Permission)!
    
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
        
        let completion = self.completion // for ARC
        
        self.dismiss(animated: true) { completion?(true) }
    }
    
    // MARK: - Methods
    
    private func setupNewKey() {
        
        guard let (lockCache, parentKeyData) = Store.shared[newKey.identifier]
            else { newKeyError("The key for the specified lock has been deleted from the database."); return }
        
        let parentKey = (lockCache.keyIdentifier, parentKeyData)
        
        print("Setting up new key for lock \(newKey.identifier)...")
        
        let sharedSecret = SharedSecret()
        
        async {
            
            // write to parent new key characteristic
            
            do { try LockManager.shared.createNewKey(self.newKey.identifier, permission: self.newKey.permission, parentKey: parentKey, sharedSecret: sharedSecret)  }
                
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
