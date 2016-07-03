//
//  NearLockViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/20/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth
import SwiftFoundation
import Bluetooth
import GATT
import CoreLock

/// Displays a list of nearby locks.
final class NearLockViewController: UITableViewController, EmptyTableViewController {
    
    // MARK: - Properties
    
    private(set) var state: State = .scanning {
        
        didSet { updateUI() }
    }
    
    var emptyTableView: EmptyTableView?
    
    // MARK: - Private Properties
    
    private var stateObserver: Int!
    
    private var locksObserver: Int!
    
    private var scanningObserver: Int!
    
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
            
            self.state = .error(Error.bluetoothDisabled)
        }
    }
    
    // MARK: - Actions
    
    @IBAction func scan(_ sender: AnyObject? = nil) {
        
        // dont scan if already scanning
        guard LockManager.shared.scanning.value == false
            && LockManager.shared.state.value == .poweredOn
            else { return }
        
        state = .scanning
        
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
            
            catch Error.bluetoothDisabled {
                
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
            
        case .newKey:
            
            enabled = true
            
            cellImage = (#imageLiteral(resourceName: "setupKey"), #imageLiteral(resourceName: "setupKeySelected"))
            
            cellTitle = "New Key"
            
            cellDetail = lock.identifier.rawValue
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
    private func requestLockName(_ completion: (String?) -> ()) {
        
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
    
    private func requestNewKey(_ completion: ((name: String, sharedSecret: String)?) -> ()) {
        
        let alert = UIAlertController(title: NSLocalizedString("New Key", comment: "NewKeyTitle"),
                                      message: "Type a user friendly name for the lock and enter the PIN code.",
                                      preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField { $0.text = "Lock" }
        
        alert.addTextField { $0.placeholder = "PIN Code"; $0.keyboardType = .numberPad }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: UIAlertActionStyle.`default`, handler: { (UIAlertAction) in
            
            completion((name: alert.textFields![0].text ?? "", sharedSecret: alert.textFields![1].text ?? ""))
            
            alert.dismiss(animated: true) {  }
            
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: UIAlertActionStyle.destructive, handler: { (UIAlertAction) in
            
            completion(nil)
            
            alert.dismiss(animated: true) {  }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    private func performAction(lock: LockManager.Lock) {
        
        func unlock() {
            
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
                            let cache = LockCache(identifier: lock.identifier, name: name, model: lock.model, version: lock.version, permission: key.permission, keyIdentifier: key.identifier)
                            
                            Store.shared[lock.identifier] = (cache, key.data)
                            
                            print("Successfully setup lock \(name) \(lock.identifier)")
                            
                            mainQueue { self.updateUI() }
                        }
                    }
                        
                    catch { mainQueue { self.state = .error(error) }; return }
                }
            }
            
        case .unlock:
            
            unlock()
            
        case .newKey:
            
            break
        }
    }
    
    // MARK: Lock Manager Notifications
    
    private func stateChanged(managerState: CBCentralManagerState) {
        
        mainQueue {
            
            // just powered on
            if managerState == .poweredOn {
                
                self.scan()
            }
            
            // bluetooth disabled
            else {
                
                self.state = .error(Error.bluetoothDisabled)
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
}

// MARK: - Supporting Types

extension NearLockViewController {
    
    enum State {
        
        case scanning
        case error(ErrorProtocol)
        case found([LockManager.Lock])
    }
}

/*
final class NearLockViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var actionButton: UIButton!
    
    @IBOutlet weak var actionImageView: UIImageView!
    
    // MARK: - Properties
    
    // The current lock
    private var foundLock: UUID? {
        
        didSet { updateUI() }
    }
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // start observing state
        let _ = LockManager.shared.state.observe(stateChanged)
        let _ = LockManager.shared.foundLocks.observe(locksUpdated)
        
        // update UI
        self.updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        self.scan()
    }
    
    // MARK: - Actions
    
    @IBAction func scan(sender: AnyObject? = nil) {
        
        // remove current lock (updates UI)
        if foundLock != nil { foundLock = nil }
        
        // already scanning
        guard LockManager.shared.scanning.value == false
            else { return }
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            do { try LockManager.shared.scan() }
            
            catch { mainQueue { controller.actionError("\(error)") }; return }
            
            // observer callback will update UI
        }
    }
    
    @IBAction func newKey(_ sender: AnyObject?) {
        
        guard let foundLock = self.foundLock else { return }
        
        let navigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "newKeyNavigationStack") as! UINavigationController
        
        let destinationViewController = navigationController.viewControllers.first! as! NewKeySelectPermissionViewController
        
        destinationViewController.lockIdentifier = foundLock
        
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @IBAction func actionButton(_ sender: UIButton) {
        
        guard let lockIdentifier = self.foundLock else { return }
        
        guard let lock = LockManager.shared[lockIdentifier] else { return }
        
        func unlock() {
            
            print("Unlocking")
            
            sender.isEnabled = false
            
            guard let cachedLock = Store.shared[lockIdentifier]
                else { self.actionError("No stored key for lock"); return }
            
            async {
                
                do { try LockManager.shared.unlock(lockIdentifier, key: cachedLock.key.data) }
                    
                catch { mainQueue { self.actionError("\(error)") }; return }
                
                print("Successfully unlocked lock \"\(lockIdentifier)\"")
                
                mainQueue { self.updateUI() }
            }
        }
        
        switch lock.status {
            
        case .setup:
            
            // ask for name
            requestLockName { (lockName) in
                
                guard let name = lockName else { return }
                
                sender.isEnabled = false
                
                async {
                    
                    do {
                        
                        print("Setting up lock \(lockIdentifier) (\(name))")
                        
                        let key = try LockManager.shared.setup(lockIdentifier)
                        
                        mainQueue {
                            
                            // save in Store
                            let newLock = Lock(identifier: lockIdentifier, name: name, model: lock.model, version: lock.version, key: key)
                            
                            Store.shared[newLock.identifier] = newLock
                            
                            print("Successfully setup lock \(name) \(lockIdentifier)")
                            
                            mainQueue { self.updateUI() }
                        }
                    }
                        
                    catch { mainQueue { self.actionError("\(error)") }; return }
                }
            }
            
        case .unlock:
            
            unlock()
            
        case .newKey:
            
            guard Store.shared[lockIdentifier] == nil
                else { unlock(); return }
            
            requestNewKey { (textValues) in
                
                guard let textValues = textValues else { return }
                
                // build shared secret from text
                guard let sharedSecret = SharedSecret(string: textValues.sharedSecret)
                    else { self.actionError("Invalid PIN code"); return }
                
                sender.isEnabled = false
                
                async {
                    
                    do {
                        
                        let key = try LockManager.shared.recieveNewKey(lockIdentifier, sharedSecret: sharedSecret)
                        
                        mainQueue {
                            
                            let lock = Lock(identifier: lockIdentifier, name: textValues.name, model: lock.model, version: lock.version, key: key)
                            
                            Store.shared[lockIdentifier] = lock
                            
                            print("Successfully added new key for lock \(textValues.name)")
                            
                            mainQueue { self.updateUI() }
                        }
                    }
                    
                    catch { mainQueue { self.actionError("\(error)") }; return }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func stateChanged(state: CBManagerState) {
        
        mainQueue {
            
            self.foundLock = nil
            
            if state == .poweredOn {
                
                self.scan()
            }
            
            self.updateUI()
        }
    }
    
    private func locksUpdated(locks: [LockManager.Lock]) {
        
        mainQueue {
            
            self.foundLock = locks.first?.UUID
            
            // continue scanning
            if self.foundLock == nil {
                
                self.scan()
            }
        }
    }
    
    private func actionError(_ error: String) {
        
        print("Error: " + error)
        
        // update UI
        self.setTitle("Error")
        
        self.actionButton.isEnabled = true
        
        self.foundLock = nil
        
        showErrorAlert(error, okHandler: { self.scan() })
    }
    
    private func setTitle(_ title: String) {
        
        self.navigationItem.title = title
    }
    
    private func updateUI() {
        
        self.navigationItem.rightBarButtonItem = nil
        
        self.actionButton.isEnabled = true
        
        // No lock
        guard let lockIdentifier = self.foundLock else {
            
            if LockManager.shared.state.value == .poweredOn {
                
                self.setTitle("Scanning...")
                
                let image1 = UIImage(named: "scan1")!
                let image2 = UIImage(named: "scan2")!
                let image3 = UIImage(named: "scan3")!
                let image4 = UIImage(named: "scan4")!
                
                self.actionButton.isHidden = true
                self.actionButton.setImage(nil, for: UIControlState(rawValue: 0))
                self.actionImageView.isHidden = false
                self.actionImageView.animationImages = [image1, image2, image3, image4]
                self.actionImageView.animationDuration = 2.0
                self.actionImageView.startAnimating()
                
            } else {
                
                self.setTitle("Error")
                
                let image1 = UIImage(named: "bluetoothLogo")!
                let image2 = UIImage(named: "bluetoothLogoDisabled")!
                
                self.actionButton.isHidden = true
                self.actionButton.setImage(nil, for: UIControlState(rawValue: 0))
                self.actionImageView.isHidden = false
                self.actionImageView.animationImages = [image1, image2]
                self.actionImageView.animationDuration = 2.0
                self.actionImageView.startAnimating()
                
                self.showErrorAlert("Bluetooth disabled")
            }
            
            return
        }
        
        let lock = LockManager.shared[lockIdentifier]!
        
        func configureUnlockUI() {
            
            // Unlock UI (if possible)
            let lockInfo = Store.shared[lockIdentifier]
            
            // set lock name (if any)
            let lockName = lockInfo?.name ?? "Lock"
            self.setTitle(lockName)
            
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = (lockInfo != nil)
            self.actionButton.setImage(UIImage(named: "unlockButton")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "unlockButtonSelected")!, for: UIControlState.highlighted)
            
            // enable creating ney keys
            if (lockInfo?.key.permission == .owner || lockInfo?.key.permission == .admin) && lock.status == .unlock {
                
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newKey))
            }
        }
        
        switch lock.status {
            
        case .setup:
            
            // setup UI
            
            self.setTitle("New Lock")
            
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = true
            self.actionButton.setImage(UIImage(named: "setupLock")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "setupLockSelected")!, for: UIControlState.highlighted)
            
        case .unlock:
            
            configureUnlockUI()
            
        case .newKey:
            
            /// Cannot have duplicate keys for same lock.
            guard Store.shared[lock.UUID] == nil
                else { configureUnlockUI(); return }
            
            // new key UI
            
            self.setTitle("New Key")
            self.actionImageView.stopAnimating()
            self.actionImageView.animationImages = nil
            self.actionImageView.isHidden = true
            self.actionButton.isHidden = false
            self.actionButton.isEnabled = true
            self.actionButton.setImage(UIImage(named: "setupKey")!, for: UIControlState(rawValue: 0))
            self.actionButton.setImage(UIImage(named: "setupKeySelected")!, for: UIControlState.highlighted)
        }
    }
    
    /// Ask's the user for the lock's name.
    private func requestLockName(_ completion: (String?) -> ()) {
        
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
    
    private func requestNewKey(_ completion: ((name: String, sharedSecret: String)?) -> ()) {
        
        let alert = UIAlertController(title: NSLocalizedString("New Key", comment: "NewKeyTitle"),
                                      message: "Type a user friendly name for the lock and enter the PIN code.",
                                      preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField { $0.text = "Lock" }
        
        alert.addTextField { $0.placeholder = "PIN Code"; $0.keyboardType = .numberPad }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: UIAlertActionStyle.`default`, handler: { (UIAlertAction) in
            
            completion((name: alert.textFields![0].text ?? "", sharedSecret: alert.textFields![1].text ?? ""))
            
            alert.dismiss(animated: true) {  }
            
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: UIAlertActionStyle.destructive, handler: { (UIAlertAction) in
            
            completion(nil)
            
            alert.dismiss(animated: true) {  }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
}
*/
