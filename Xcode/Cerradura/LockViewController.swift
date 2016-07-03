//
//  LockViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import UIKit
import CoreLock

final class LockViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var unlockButton: UIButton!
    
    // MARK: - Properties
    
    var lockIdentifier: UUID! {
        
        didSet { if isViewLoaded() { updateUI() } }
    }
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard lockIdentifier != nil else { fatalError("Lock identifer not set") }
        
        self.updateUI()
    }
    
    // MARK: - Actions
    
    @IBAction func newKey(_ sender: UIBarButtonItem) {
        
        let navigationController = UIStoryboard(name: "NewKey", bundle: nil).instantiateInitialViewController() as! UINavigationController
        
        let destinationViewController = navigationController.viewControllers.first! as! NewKeySelectPermissionViewController
        
        destinationViewController.lockIdentifier = lockIdentifier
        
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @IBAction func unlock(_ sender: UIButton) {
        
        print("Unlocking \(lockIdentifier!)")
        
        guard let (lockCache, keyData) = Store.shared[lockIdentifier]
            else { fatalError("No stored key for lock") } // FRC should prevent this
        
        sender.isEnabled = false
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            // enable action button
            defer { mainQueue { sender.isEnabled = true } }
            
            do {
                
                if LockManager.shared[controller.lockIdentifier] == nil {

                    try LockManager.shared.scan()
                }
                
                try LockManager.shared.unlock(controller.lockIdentifier, key: (lockCache.keyIdentifier, keyData))
            }
                
            catch { mainQueue { controller.showErrorAlert("\(error)") }; return }
            
            print("Successfully unlocked lock \"\(controller.lockIdentifier!)\"")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        
        // Lock has been deleted
        guard let lockCache = Store.shared[cache: lockIdentifier] else {
            
            // FIXME: handle deletion
            return
        }
        
        // set lock name
        self.navigationItem.title = lockCache.name
        
        // setup new key button
        switch lockCache.permission {
            
        case .owner, .admin:
            
            let newKeyBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newKey))
            
            self.navigationItem.rightBarButtonItem = newKeyBarButtonItem
            
        default:
            
            self.navigationItem.rightBarButtonItem = nil
        }
        
        // setup unlock button
        switch lockCache.permission {
            
        case .owner, .admin, .anytime:
            
            self.unlockButton.isEnabled = true
            
        case let .scheduled(schedule):
            
            self.unlockButton.isEnabled = schedule.valid()
        }
        
    }
}
