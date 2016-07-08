//
//  KeysInterfaceController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/8/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import WatchKit

final class KeysInterfaceController: WKInterfaceController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var tableView: WKInterfaceTable!
    
    // MARK: - Properties
    
    private(set) var locks = [LockCache]()
    
    private var locksObserver: Int!
    
    // MARK: - Loading
    
    override func awake(withContext context: AnyObject?) {
        super.awake(withContext: context)
        
        locksObserver = SessionController.shared.locks.observe(locksUpdated)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        self.reloadData()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // MARK: - Methods
    
    private func reloadData() {
        
        // request current locks
        do { try SessionController.shared.requestLocks() }
            
        catch { showError("\(error)"); return }
    }
    
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
                    
                case .owner: image = #imageLiteral(resourceName: "modularSmallOwner")
                case .admin: image = #imageLiteral(resourceName: "modularSmallAdmin")
                case .anytime: image = #imageLiteral(resourceName: "modularSmallAnytime")
                case .scheduled: image = #imageLiteral(resourceName: "modularSmallScheduled")
                }
                
                rowController.imageView.setImage(image)
            }
        }
    }
}

// MARK: - Supporting Types

final class LockRowController: NSObject {
    
    static let rowType = "Lock"
    
    @IBOutlet weak var imageView: WKInterfaceImage!
    
    @IBOutlet weak var label: WKInterfaceLabel!
}
