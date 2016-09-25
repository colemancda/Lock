//
//  LockPermissionsViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 9/25/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import UIKit
import CoreLock
import JGProgressHUD

final class LockPermissionsViewController: UITableViewController, ActivityIndicatorViewController {
    
    // MARK: - Properties
    
    var lockIdentifier: UUID!
    
    var completion: (() -> ())?
    
    private(set) var state: State = .fetching {
        
        didSet { updateUI() }
    }
    
    let progressHUD = JGProgressHUD(style: .dark)!
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        assert(lockIdentifier != nil, "No lock set")
        
        // setup table view
        tableView.register(LockTableViewCell.nib, forCellReuseIdentifier: LockTableViewCell.reuseIdentifier)
        
        reloadData()
    }
    
    // MARK: - Actions
    
    @IBAction func reloadData(_ sender: AnyObject? = nil) {
        
        self.state = .fetching
        
        let lockIdentifier = self.lockIdentifier!
        
        guard let (lockCache, lockKeyData) = Store.shared[lockIdentifier]
            else { self.state = .error(AppError.lockDeleted); return }
        
        async {
            
            var keys: [KeyEntry]!
            
            do { keys = try LockManager.shared.listKeys(lockCache.identifier, key: (lockCache.keyIdentifier, lockKeyData)) }
            
            catch { mainQueue { self.state = .error(error) }; return }
            
            mainQueue { self.state = .keys(keys) }
        }
    }
    
    @IBAction func newKey(_ sender: AnyObject? = nil) {
        
        let navigationController = UIStoryboard(name: "NewKey", bundle: nil).instantiateInitialViewController() as! UINavigationController
        
        let destinationViewController = navigationController.viewControllers.first! as! NewKeySelectPermissionViewController
        
        destinationViewController.lockIdentifier = lockIdentifier
        
        destinationViewController.completion = { _ in mainQueue { self.reloadData() } }
        
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @IBAction func done(_ sender: AnyObject? = nil) {
        
        self.dismiss(animated: true, completion: completion)
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        
        refreshControl?.endRefreshing()
        
        switch self.state {
            
        case .keys:
            
            self.dismissProgressHUD(true)
            
            self.tableView.reloadData()
            
        case .fetching:
            
            self.showProgressHUD()
            
        case let .error(error):
            
            self.dismissProgressHUD(false)
            
            showErrorAlert("\(error)",
                okHandler: { self.tableView.reloadData() },
                retryHandler: { self.reloadData() })
        }
    }
    
    private func configure(cell: LockTableViewCell, at indexPath: IndexPath) {
        
        guard case let .keys(keys) = self.state else { fatalError("Cannot display keys in state: \(self.state)") }
        
        let key = keys[indexPath.row]
        
        let permissionImage: UIImage
        
        let permissionText: String
        
        switch key.permission {
            
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
        
        cell.lockTitleLabel.text = key.name.rawValue
        
        cell.lockDetailLabel.text = permissionText
        
        cell.lockImageView.image = permissionImage
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard case let .keys(keys) = self.state else { return 0 }
        
        return keys.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: LockTableViewCell.reuseIdentifier, for: indexPath) as! LockTableViewCell
        
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        // show key info
        
        guard case let .keys(keys) = self.state else { fatalError("Cannot select key in state: \(self.state)") }
        
        let key = keys[indexPath.row]
        
        // present key detail VC
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        var actions = [UITableViewRowAction]()
        
        let lockIdentifier = self.lockIdentifier!
        
        guard let (lockCache, lockKeyData) = Store.shared[lockIdentifier]
            else { return nil }
        
        guard case let .keys(keys) = self.state else { fatalError("Cannot edit key in state: \(self.state)") }
        
        let keyEntry = keys[indexPath.row]
        
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") {
            
            assert($0.1 == indexPath)
            
            let alert = UIAlertController(title: NSLocalizedString("Confirmation", comment: "DeletionConfirmation"),
                                          message: "Are you sure you want to delete this key?",
                                          preferredStyle: UIAlertControllerStyle.alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: { (UIAlertAction) in
                
                alert.dismiss(animated: true, completion: nil)
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete"), style: .destructive, handler: { (UIAlertAction) in
                
                alert.dismiss(animated: true) {
                    
                    self.showProgressHUD()
                    
                    async {
                        
                        do { try LockManager.shared.removeKey(lockCache.identifier, key: (lockCache.keyIdentifier, lockKeyData), removedKey: keyEntry.identifier) }
                            
                        catch { mainQueue { self.state = .error(error) }; return }
                        
                        mainQueue { self.reloadData() }
                    }
                }
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
        
        actions.append(delete)
        
        return actions
    }
}

// MARK: - Supporting Types

extension LockPermissionsViewController {
    
    typealias KeyEntry = LockService.ListKeysValue.KeyEntry
    
    enum State {
        
        case fetching
        case keys([KeyEntry])
        case error(Error)
    }
}
