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
import CoreLock

final class KeysViewController: UITableViewController /* NSFetchedResultsControllerDelegate */ {
    
    // MARK: - Properties
    
    private lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: LockCache.entityName)
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: LockCache.Property.name.rawValue, ascending: true)]
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: Store.shared.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        return controller
    }()
    
    private lazy var controller: Controller = Controller(tableView: self.tableView, fetchedResultsController: self.fetchedResultsController)
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        fetchedResultsController.delegate = unsafeBitCast(self.controller, to: NSFetchedResultsControllerDelegate.self)
        tableView.dataSource = unsafeBitCast(self.controller, to: UITableViewDataSource.self)
        tableView.delegate = unsafeBitCast(self.controller, to: UITableViewDelegate.self)
        
        try! fetchedResultsController.performFetch()
    }
}

private extension KeysViewController {
    
    @objc private final class Controller: NSObject {
        
        weak var tableView: UITableView!
        
        weak var fetchedResultsController: NSFetchedResultsController!
        
        private init(tableView: UITableView, fetchedResultsController: NSFetchedResultsController) {
            
            self.tableView = tableView
            self.fetchedResultsController = fetchedResultsController
        }
        
        private func item(at indexPath: NSIndexPath) -> LockCache {
            
            let managedObject = fetchedResultsController.object(at: indexPath) as! NSManagedObject
            
            let lock = LockCache(managedObject: managedObject)
            
            return lock
        }
        
        private func configure(cell: KeyTableViewCell, at indexPath: NSIndexPath) {
            
            let lock = item(at: indexPath)
            
            let permissionImage: UIImage
            
            let permissionText: String
            
            switch lock.permission {
                
            case .owner:
                
                permissionImage = UIImage(named: "permissionBadgeOwner")!
                
                permissionText = "Owner"
                
            case .admin:
                
                permissionImage = UIImage(named: "permissionBadgeAdmin")!
                
                permissionText = "Admin"
                
            case .anytime:
                
                permissionImage = UIImage(named: "permissionBadgeAnytime")!
                
                permissionText = "Anytime"
                
            case let .scheduled(schedule):
                
                permissionImage = UIImage(named: "permissionBadgeScheduled")!
                
                permissionText = "Scheduled" // FIXME
            }
            
            cell.lockNameLabel.text = lock.name
            
            cell.permissionImageView.image = permissionImage
            
            cell.permissionLabel.text = permissionText
        }
        
        // MARK: - UITableViewDatasource
        
        @objc func numberOfSectionsInTableView(_ tableView: UITableView) -> Int {
            
            return 1
        }
        
        @objc func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            
            return fetchedResultsController.fetchedObjects?.count ?? 0
        }
        
        @objc func tableView(_ tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: KeyTableViewCell.resuseIdentifier, for: indexPath) as! KeyTableViewCell
            
            configure(cell: cell, at: indexPath)
            
            return cell
        }
        
        // MARK: - UITableViewDelegate
        
        /*
        @objc func tableView(_ tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
            
            let lock = item(at: indexPath)
            
            Store.shared.remove(lock.identifier)
        }
        
        @objc func tableView(_ tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
            
            return .delete
        }*/
        
        func tableView(_ tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            
            
        }
        
        // MARK: - NSFetchedResultsControllerDelegate
        
        @objc func controllerWillChangeContent(_ controller: NSFetchedResultsController) {
            
            tableView.beginUpdates()
        }
        
        @objc func controllerDidChangeContent(_ controller: NSFetchedResultsController) {
            
            tableView.endUpdates()
        }
        
        @objc func controller(_ controller: NSFetchedResultsController,
                              didChangeObject anObject: AnyObject,
                              atIndexPath indexPath: NSIndexPath?,
                              forChangeType type: NSFetchedResultsChangeType,
                              newIndexPath: NSIndexPath?) {
            
            sleep(1)
            
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
                    
                    if let cell = tableView.cellForRow(at: indexPath) as? KeyTableViewCell {
                        
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
}

// MARK: - Supporting Types

final class KeyTableViewCell: UITableViewCell {
    
    static let resuseIdentifier = "KeyTableViewCell"
    
    @IBOutlet weak var permissionImageView: UIImageView!
    
    @IBOutlet weak var lockNameLabel: UILabel!
        
    @IBOutlet weak var permissionLabel: UILabel!
}
