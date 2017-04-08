//
//  NewKeyRecieveViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/11/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreLock
import JGProgressHUD

final class NewKeyRecieveViewController: UITableViewController, ActivityIndicatorViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var permissionImageView: UIImageView!
    
    @IBOutlet weak var permissionLabel: UILabel!
    
    @IBOutlet weak var lockLabel: UILabel!
    
    // MARK: - Properties
    
    var newKey: NewKeyInvitation!
    
    // MARK: - Private Properties
    
    let progressHUD = JGProgressHUD(style: .dark)!
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        assert(newKey != nil)
        
        self.tableView.tableFooterView = UIView()
        
        updateUI()
    }
    
    // MARK: - Actions
    
    @IBAction func cancel(_ sender: UIBarItem) {
        
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func save(_ sender: UIBarItem) {
        
        let newKeyInvitation = self.newKey!
        
        sender.isEnabled = false
        
        let keyData = KeyData()
        
        var foundLock: LockManager.Lock!
        
        showProgressHUD()
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            do {
                
                // scan lock is not cached
                if LockManager.shared.foundLocks.value.contains(where: { $0.identifier == newKeyInvitation.lock }) == false {
                    
                    try LockManager.shared.scan()
                }
                
                foundLock = LockManager.shared[newKeyInvitation.lock]
                
                guard foundLock != nil
                    else { throw AppError.lockNotInRange }
                
                // recieve new key
                try LockManager.shared.recieveNewKey(newKeyInvitation.lock, sharedSecret: newKeyInvitation.key.sharedSecret, newKey: (newKeyInvitation.key.identifier, keyData))
            }
            
            catch {
                
                mainQueue {
                    
                    controller.dismissProgressHUD(false)
                    controller.showErrorAlert("\(error)", okHandler: { controller.dismiss(animated: true, completion: nil) })
                }
                
                return
            }
            
            // update UI
            mainQueue {
                
                // save to cache
                
                let lockCache = LockCache(identifier: newKeyInvitation.lock,
                                          name: newKeyInvitation.key.name.rawValue,
                                          model: foundLock.model,
                                          permission: newKeyInvitation.key.permission,
                                          keyIdentifier: newKeyInvitation.key.identifier,
                                          version: foundLock.version,
                                          packageVersion: nil)
                
                Store.shared[newKeyInvitation.lock] = (lockCache, keyData)
                
                controller.dismissProgressHUD()
                
                controller.dismiss(animated: true, completion: nil)
            }
        }
        
        
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        
        self.navigationItem.title = newKey.key.name.rawValue
        
        self.lockLabel.text = newKey.lock.rawValue
        
        let permissionImage: UIImage
        
        let permissionText: String
        
        switch newKey.key.permission {
            
        case .owner:
            
            permissionImage = #imageLiteral(resourceName: "permissionBadgeOwner")
            
            permissionText = "Owner"
            
        case .admin:
            
            permissionImage = #imageLiteral(resourceName: "permissionBadgeAdmin")
            
            permissionText = "Admin"
            
        case .anytime:
            
            permissionImage = #imageLiteral(resourceName: "permissionBadgeAnytime")
            
            permissionText = "Anytime"
            
        case .scheduled:
            
            permissionImage = #imageLiteral(resourceName: "permissionBadgeScheduled")
            
            permissionText = "Scheduled" // FIXME: Localized Schedule text
        }
        
        self.permissionImageView.image = permissionImage
        
        self.permissionLabel.text = permissionText
    }
}
