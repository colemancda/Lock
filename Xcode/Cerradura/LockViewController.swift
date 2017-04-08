//
//  LockViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import UIKit
import JGProgressHUD
import CoreLock
import CoreData

final class LockViewController: UITableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) weak var unlockButton: UIButton!
    
    @IBOutlet private(set) weak var lockIdentifierLabel: UILabel!
    
    @IBOutlet private(set) weak var keyIdentifierLabel: UILabel!
    
    @IBOutlet private(set) weak var permissionLabel: UILabel!
    
    @IBOutlet private(set) weak var versionLabel: UILabel!
    
    @IBOutlet private(set) weak var modelLabel: UILabel!
    
    // MARK: - Properties
    
    var lockIdentifier: UUID! {
        
        didSet { if self.isViewLoaded { self.updateUI() } }
    }
    
    // MARK: - Private Properties
    
    private let progressHUD = JGProgressHUD(style: .dark)!
    
    // MARK: - Loading
    
    deinit {
        
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard lockIdentifier != nil else { fatalError("Lock identifer not set") }
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 44
        self.tableView.tableFooterView = UIView()
        
        // observe context
        NotificationCenter.default.addObserver(self, selector: #selector(contextObjectsDidChange), name: Notification.Name.NSManagedObjectContextObjectsDidChange, object: Store.shared.managedObjectContext)
        
        self.updateUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        view.bringSubview(toFront: progressHUD)
    }
    
    // MARK: - Actions
    
    @IBAction func showActionMenu(_ sender: UIBarButtonItem) {
        
        let lockIdentifier = self.lockIdentifier!
        
        let foundLock = LockManager.shared[lockIdentifier]
        
        let isScanning = LockManager.shared.scanning.value == false
        
        let shouldScan = foundLock == nil && isScanning == false
        
        func show() {
            
            let activities = [NewKeyActivity(), ManageKeysActivity(), RenameActivity(), UpdateActivity(), DeleteLockActivity()]
            
            let lockItem = LockActivityItem(identifier: lockIdentifier)
            
            let items = [lockItem, lockItem.text, lockItem.image] as [Any]
            
            let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: activities)
            activityViewController.excludedActivityTypes = LockActivityItem.excludedActivityTypes
            activityViewController.modalPresentationStyle = .popover
            activityViewController.popoverPresentationController?.barButtonItem = sender
            
            self.present(activityViewController, animated: true, completion: nil)
        }
        
        if shouldScan {
            
            self.progressHUD.show(in: self.view)
            
            async { [weak self] in
                
                guard let controller = self else { return }
                
                // try to scan if not in range
                do { try LockManager.shared.scan() }
                    
                catch {
                    
                    mainQueue {
                        
                        controller.progressHUD.dismiss(animated: false)
                        controller.showErrorAlert("\(error)")
                    }
                }
                
                mainQueue {
                    
                    controller.progressHUD.dismiss()
                    show()
                }
            }
            
        } else {
            
            show()
        }
    }
    
    @IBAction func unlock(_ sender: UIButton) {
        
        print("Unlocking \(lockIdentifier!)")
        
        guard let (lockCache, keyData) = Store.shared[lockIdentifier]
            else { fatalError("No stored key for lock") } // FRC should prevent this
        
        guard let foundLock = LockManager.shared[lockIdentifier]
            else { showErrorAlert("Lock not in area. Please rescan for nearby locks."); return }
        
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
        guard let lockCache = Store.shared[cache: lockIdentifier]
            else { return }
        
        // set lock name
        self.navigationItem.title = lockCache.name
        
        // setup unlock button
        switch lockCache.permission {
            
        case .owner, .admin, .anytime:
            
            self.unlockButton.isEnabled = true
            
        case let .scheduled(schedule):
            
            self.unlockButton.isEnabled = schedule.valid()
        }
        
        self.lockIdentifierLabel.text = lockCache.identifier.rawValue
        self.keyIdentifierLabel.text = lockCache.keyIdentifier.rawValue
        self.modelLabel.text = lockCache.model.name
        
        if let version = lockCache.packageVersion {
            
            self.versionLabel.text = "\(version.0).\(version.1).\(version.2)"
            
        } else {
            
            self.versionLabel.text = "1.0.0"
        }
        
        let permissionImage: UIImage
        
        let permissionText: String
        
        switch lockCache.permission {
            
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
        
        self.permissionLabel.text = permissionText
    }
    
    // MARK: Notifications
    
    @objc private func contextObjectsDidChange(_ notification: Notification) {
        
        // check if deleted
        guard let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>,
            deletedObjects.contains(where: { LockCache(managedObject: $0).identifier == self.lockIdentifier })
            else { return }
        
        if navigationController?.viewControllers.count ?? 0 > 1 {
            
            let _ = navigationController?.popToRootViewController(animated: true)
            
        } else {
            
            let emptyVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmptyViewController")
            
            navigationController?.viewControllers = [emptyVC]
        }
    }
}
