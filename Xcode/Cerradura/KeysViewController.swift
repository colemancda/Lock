//
//  KeysViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/23/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CoreBluetooth
import CoreLock
import GATT

final class KeysViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    
    private lazy var fetchedResultsController: NSFetchedResultsController<NSManagedObject> = {
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: LockCache.entityName)
        
        fetchRequest.sortDescriptors = [SortDescriptor(key: LockCache.Property.name.rawValue, ascending: true)]
        
        let controller = NSFetchedResultsController<NSManagedObject>(fetchRequest: fetchRequest, managedObjectContext: Store.shared.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        controller.delegate = self
        
        return controller
    }()
    
    private var stateObserver: Int!
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup table view
        tableView.register(LockTableViewCell.nib, forCellReuseIdentifier: LockTableViewCell.reuseIdentifier)
        
        // start observing Core Data context
        try! fetchedResultsController.performFetch()
    }
    
    // MARK: - Methods
    
    private func stateChanged(_ state: CBCentralManagerState) {
        
        mainQueue {
            
            self.tableView.setEditing(false, animated: true)
        }
    }
    
    private func item(at indexPath: IndexPath) -> LockCache {
        
        let managedObject = fetchedResultsController.object(at: indexPath)
        
        let lock = LockCache(managedObject: managedObject)
        
        return lock
    }
    
    private func configure(cell: LockTableViewCell, at indexPath: IndexPath) {
        
        let lock = item(at: indexPath)
        
        let permissionImage: UIImage
        
        let permissionText: String
        
        switch lock.permission {
            
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
        
        cell.lockTitleLabel.text = lock.name
        
        cell.lockDetailLabel.text = permissionText
        
        cell.lockImageView.image = permissionImage
    }
    
    // MARK: - UITableViewDatasource
    
    @objc func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    @objc func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    @objc func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: LockTableViewCell.reuseIdentifier, for: indexPath) as! LockTableViewCell
        
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        
        // show LockVC
        
        let lock = self.item(at: indexPath)
        
        let navigationController = UIStoryboard(name: "LockDetail", bundle: nil).instantiateInitialViewController() as! UINavigationController
        
        let lockVC = navigationController.topViewController as! LockViewController
        
        lockVC.lockIdentifier = lock.identifier
        
        // iPhone
        if splitViewController?.viewControllers.count == 1 {
            
            self.show(lockVC, sender: self)
        }
        // iPad
        else {
            
            self.showDetailViewController(navigationController, sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        var actions = [UITableViewRowAction]()
        
        let lockCache = self.item(at: indexPath)
        
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") {
            
            assert($0.1 == indexPath)
            
            let alert = UIAlertController(title: NSLocalizedString("Confirmation", comment: "DeletionConfirmation"),
                                          message: "Are you sure you want to delete this key?",
                                          preferredStyle: UIAlertControllerStyle.alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: { (UIAlertAction) in
                
                alert.dismiss(animated: true, completion: nil)
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete"), style: .destructive, handler: { (UIAlertAction) in
                
                Store.shared.remove(lockCache.identifier)
                
                alert.dismiss(animated: true, completion: nil)
            }))
            
           self.present(alert, animated: true, completion: nil)
        }
        
        actions.append(delete)
        
        return actions
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    @objc(controllerWillChangeContent:)
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        tableView.beginUpdates()
    }
    
    @objc(controllerDidChangeContent:)
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: AnyObject, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
            
        case .insert:
            
            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
            
        case .delete:
            
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            
        case .update:
            
            if let indexPath = indexPath {
                
                if let cell = tableView.cellForRow(at: indexPath) as? LockTableViewCell {
                    
                    self.configure(cell: cell, at: indexPath)
                }
            }
            
        case .move:
            
            if let indexPath = indexPath {
                
                if let newIndexPath = newIndexPath {
                    
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    tableView.insertRows(at: [newIndexPath], with: .automatic)
                }
            }
        }
    }
}
