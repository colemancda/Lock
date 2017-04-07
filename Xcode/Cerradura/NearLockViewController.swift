//
//  NearLockViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/20/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CoreBluetooth
import Foundation
import Bluetooth
import GATT
import CoreLock

/// Displays a list of nearby locks.
final class NearLockViewController: UITableViewController, EmptyTableViewController, NSFetchedResultsControllerDelegate {
    
    // MARK: - Properties
    
    private(set) var state: State = .scanning {
        
        didSet { updateUI() }
    }
    
    var emptyTableView: EmptyTableView?
    
    // MARK: - Private Properties
    
    private var stateObserver: Int!
    
    private var locksObserver: Int!
    
    private var scanningObserver: Int!
    
    private lazy var fetchedResultsController: NSFetchedResultsController<NSManagedObject> = {
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: LockCache.entityName)
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: LockCache.Property.name.rawValue, ascending: true)]
        
        let controller = NSFetchedResultsController<NSManagedObject>(fetchRequest: fetchRequest, managedObjectContext: Store.shared.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        controller.delegate = self
        
        return controller
    }()
    
    // MARK: - Loading
    
    deinit {
        
        // stop observing state
        LockManager.shared.state.remove(observer: stateObserver)
        LockManager.shared.foundLocks.remove(observer: locksObserver)
        LockManager.shared.scanning.remove(observer: scanningObserver)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup table view
        tableView.register(LockTableViewCell.nib, forCellReuseIdentifier: LockTableViewCell.reuseIdentifier)
        
        // start observing state
        stateObserver = LockManager.shared.state.observe(stateChanged)
        locksObserver = LockManager.shared.foundLocks.observe(foundLocks)
        scanningObserver = LockManager.shared.scanning.observe(scanningStateChanged)
        
        // start scanning
        if LockManager.shared.state.value == .poweredOn {
            
            self.scan()
            
        } else {
            
            self.state = .error(AppError.bluetoothDisabled)
        }
        
        // start observing Core Data context
        try! fetchedResultsController.performFetch()
    }
    
    // MARK: - Actions
    
    @IBAction func scan(_ sender: AnyObject? = nil) {
        
        // update UI
        switch state {
        case .scanning: break
        default: state = .scanning
        }
        
        // dont scan if already scanning
        guard LockManager.shared.scanning.value == false,
            LockManager.shared.state.value == .poweredOn
            else { return }
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            do { try LockManager.shared.scan(duration: 4) }
            
            catch { mainQueue { controller.state = .error(error) }; return }
            
            // callback will update UI or continue to scan
        }
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        
        refreshControl?.endRefreshing()
        
        emptyTableView?.imageView.stopAnimating()
        
        tableView.reloadData()
        
        switch state {
            
        case .scanning:
            
            showEmptyTableView()
            
            emptyTableView?.label.text = "Scanning..."
            
            emptyTableView?.imageView.animationDuration = 2.0
            
            emptyTableView?.imageView.animationImages = [#imageLiteral(resourceName: "scan1"), #imageLiteral(resourceName: "scan2"), #imageLiteral(resourceName: "scan3"), #imageLiteral(resourceName: "scan4")]
            
            emptyTableView?.imageView.startAnimating()
            
        case let .error(error):
            
            do { throw error }
            
            catch AppError.bluetoothDisabled {
                
                showEmptyTableView()
                
                emptyTableView?.label.text = "Bluetooth disabled"
                
                emptyTableView?.imageView.animationDuration = 2.0
                
                emptyTableView?.imageView.animationImages = [#imageLiteral(resourceName: "bluetoothLogo"), #imageLiteral(resourceName: "bluetoothLogoDisabled")]
                
                emptyTableView?.imageView.startAnimating()
            }
            
            catch {
                
                showErrorAlert("\(error)", okHandler: { self.scan() })
            }
            
        case let .found(locks):
            
            assert(locks.isEmpty == false, "Should scan continously when there are no locks")
            
            hideEmptyTableView()
            
            tableView.reloadData()
        }
    }
    
    private func configure(cell: LockTableViewCell, at indexPath: IndexPath) {
        
        guard case let .found(locks) = self.state else { fatalError("Invalid state: \(self.state)") }
        
        let lock = locks[indexPath.row]
        
        let cellImage: (UIImage, UIImage)
        
        let cellTitle: String
        
        let cellDetail: String
        
        let enabled: Bool
        
        switch lock.status {
            
        case .setup:
            
            enabled = true
            
            cellImage = (#imageLiteral(resourceName: "setupLock"), #imageLiteral(resourceName: "setupLockSelected"))
            
            cellTitle = "New Lock"
            
            cellDetail = lock.identifier.rawValue
            
        case .unlock:
            
            cellImage = (#imageLiteral(resourceName: "unlockButton"), #imageLiteral(resourceName: "unlockButtonSelected"))
            
            if let lockCache = Store.shared[cache: lock.identifier] {
                
                enabled = true
                
                cellTitle = lockCache.name
                
                let permission = lockCache.permission
                
                switch permission {
                    
                case .owner: cellDetail = "Owner"
                    
                case .admin: cellDetail = "Admin"
                    
                case .anytime: cellDetail = "Anytime"
                    
                case .scheduled: cellDetail = "Scheduled" // FIXME: detailed schedule description
                }
                
            } else {
                
                enabled = false
                
                cellTitle = "Unknown lock"
                
                cellDetail = lock.identifier.rawValue
            }
        }
        
        // configure cell
    
        cell.lockTitleLabel.text = cellTitle
        
        cell.lockDetailLabel.text = cellDetail
        
        cell.lockImageView.image = cellImage.0
        
        cell.lockImageView.highlightedImage = cellImage.1
        
        cell.isUserInteractionEnabled = enabled
        
        cell.lockTitleLabel.isEnabled = enabled
        
        cell.lockDetailLabel.isEnabled = enabled
        
        cell.lockImageView.alpha = enabled ? 1.0 : 0.6
        
        cell.selectionStyle = enabled ? .default : .none
    }
    
    /// Ask's the user for the lock's name.
    private func requestLockName(_ completion: @escaping (String?) -> ()) {
        
        let alert = UIAlertController(title: NSLocalizedString("Lock Name", comment: "LockName"),
                                      message: "Type a user friendly name for the lock.",
                                      preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField { $0.text = "Lock" }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: UIAlertActionStyle.`default`, handler: { (UIAlertAction) in
            
            completion(alert.textFields![0].text)
            
            alert.dismiss(animated: true) {  }
            
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: UIAlertActionStyle.destructive, handler: { (UIAlertAction) in
            
            completion(nil)
            
            alert.dismiss(animated: true) {  }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    private func performAction(lock: LockManager.Lock) {
        
        switch lock.status {
            
        case .setup:
            
            // ask for name
            requestLockName { (lockName) in
                
                guard let name = lockName else { return }
                
                async {
                    
                    do {
                        
                        print("Setting up lock \(lock.identifier) (\(name))")
                        
                        let key = try LockManager.shared.setup(lock.identifier)
                        
                        mainQueue {
                            
                            // save in Store
                            let cache = LockCache(identifier: lock.identifier, name: name, model: lock.model, version: lock.version, packageVersion: lock.packageVersion, permission: key.permission, keyIdentifier: key.identifier)
                            
                            Store.shared[lock.identifier] = (cache, key.data)
                            
                            print("Successfully setup lock \(name) \(lock.identifier)")
                            
                            mainQueue { self.updateUI() }
                        }
                    }
                        
                    catch { mainQueue { self.state = .error(error) }; return }
                }
            }
            
        case .unlock:
            
            print("Unlocking \(lock.identifier)")
            
            guard let (lockCache, keyData) = Store.shared[lock.identifier]
                else { fatalError("No stored key for lock") } // FRC should prevent this
            
            async {
                
                do { try LockManager.shared.unlock(lock.identifier, key: (lockCache.keyIdentifier, keyData)) }
                    
                catch { mainQueue { self.state = .error(error) }; return }
                
                print("Successfully unlocked lock \"\(lock.identifier)\"")
                
                mainQueue { self.updateUI() }
            }
        }
    }
    
    // MARK: Lock Manager Notifications
    
    private func stateChanged(managerState: CBManagerState) {
        
        mainQueue {
            
            // just powered on
            if managerState == .poweredOn {
                
                self.scan()
            }
            
            // bluetooth disabled
            else {
                
                self.state = .error(AppError.bluetoothDisabled)
            }
        }
    }
    
    private func scanningStateChanged(isScanning: Bool) {
        
        if isScanning {
            
            mainQueue { self.state  = .scanning }
        }
    }
    
    private func foundLocks(locks: [LockManager.Lock]) {
        
        mainQueue {
            
            /// no locks were found
            guard locks.isEmpty == false else {
             
                self.scan()
                return
            }
            
            // display found locks
            mainQueue { self.state = .found(locks) }
        }
    }
    
    // MARK: -
    // MARK: UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        guard case .found = self.state else { return 0 }
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard case let .found(locks) = self.state else { return 0 }
        
        return locks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: LockTableViewCell.reuseIdentifier, for: indexPath) as! LockTableViewCell
        
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        
        let cell = tableView.cellForRow(at: indexPath) as! LockTableViewCell
        
        cell.imageView?.isHighlighted = true
        
        // perform action
        
        guard case let .found(locks) = self.state else { fatalError("Invalid state: \(self.state)") }
        
        let lock = locks[indexPath.row]
        
        performAction(lock: lock)
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: indexPath) as! LockTableViewCell
        
        cell.imageView?.isHighlighted = true
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    @objc(controllerDidChangeContent:)
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        self.updateUI()
    }
}

// MARK: - Supporting Types

extension NearLockViewController {
    
    enum State {
        
        case scanning
        case error(Swift.Error)
        case found([LockManager.Lock])
    }
}
