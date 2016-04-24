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

final class ViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    // MARK: - Properties
    
    private lazy var fetchedResultsController: NSFetchedResultsController = NSFetchedResultsController(fetchRequest: NSFetchRequest(entityName: LockCache.entityName), managedObjectContext: Store.shared.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        try! fetchedResultsController.performFetch()
    }
    
    // MARK: - Private Methods
    
    private func configure(cell: KeyTableViewCell, at indexPath: NSIndexPath) {
        
        let managedObject = fetchedResultsController.object(at: indexPath) as! NSManagedObject
        
        let lock = LockCache(managedObject: managedObject)
        
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
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: KeyTableViewCell.resuseIdentifier, for: indexPath) as! KeyTableViewCell
        
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController) {
        
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController) {
        
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController, didChange anObject: AnyObject, at indexPath: NSIndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
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

// MARK: - Supporting Types

final class KeyTableViewCell: UITableViewCell {
    
    static let resuseIdentifier = "KeyTableViewCell"
    
    @IBOutlet weak var permissionImageView: UIImageView!
    
    @IBOutlet weak var lockNameLabel: UILabel!
        
    @IBOutlet weak var permissionLabel: UILabel!
}