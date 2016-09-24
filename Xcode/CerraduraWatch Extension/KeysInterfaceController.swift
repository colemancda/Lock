//
//  KeysInterfaceController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/8/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import WatchKit
import enum WatchConnectivity.WCSessionActivationState

final class KeysInterfaceController: WKInterfaceController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var tableView: WKInterfaceTable!
    
    // MARK: - Properties
    
    private(set) var locks = [LockCache]()
    
    private var locksObserver: Int!
    
    private var activationObserver: Int!
    
    // MARK: - Loading
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        locksObserver = SessionController.shared.locks.observe(locksUpdated)
        activationObserver = SessionController.shared.activationState.observe(activationStateChanged)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        if SessionController.shared.session.activationState == .activated {
            
            self.reloadData()
        }
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // MARK: - Methods
    
    private func reloadData() {
        
        async {
            
            // request current locks
            do { try SessionController.shared.requestLocks() }
                
            catch { mainQueue { self.showError("\(error)"); return } }
        }
    }
    
    // MARK: - Session Controller Notifications
    
    private func locksUpdated(_ locks: [LockCache]) {
        
        mainQueue {
            
            self.locks = SessionController.shared.locks.value
            
            self.tableView.setNumberOfRows(locks.count, withRowType: LockRowController.rowType)
            
            // setup rows
            for (index, lock) in locks.enumerated() {
                
                let rowController = self.tableView.rowController(at: index) as! LockRowController
                
                rowController.label.setText(lock.name)
                
                let image: UIImage
                
                switch lock.permission {
                case .owner: image = #imageLiteral(resourceName: "watchOwner")
                case .admin: image = #imageLiteral(resourceName: "watchAdmin")
                case .anytime: image = #imageLiteral(resourceName: "watchAnytime")
                case .scheduled: image = #imageLiteral(resourceName: "watchScheduled")
                }
                
                rowController.imageView.setImage(image)
            }
        }
    }
    
    private func activationStateChanged(_ state: WCSessionActivationState) {
        
        mainQueue {
            
            if SessionController.shared.session.activationState == .activated {
                
                self.reloadData()
                
            } else {
                
                // could not activate
                self.showError("Could not activate communicate with iPhone. ")
            }
        }
    }
    
    // MARK: - Segue
    
    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        
        let lock = locks[rowIndex]
        
        return LockContext(lock: lock)
    }
}

// MARK: - Supporting Types

final class LockRowController: NSObject {
    
    static let rowType = "Lock"
    
    @IBOutlet weak var imageView: WKInterfaceImage!
    
    @IBOutlet weak var label: WKInterfaceLabel!
}
