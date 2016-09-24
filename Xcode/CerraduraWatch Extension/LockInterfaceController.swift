//
//  LockInterfaceController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/9/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import WatchKit

final class LockInterfaceController: WKInterfaceController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var button: WKInterfaceButton!
    
    @IBOutlet weak var imageView: WKInterfaceImage!
    
    // MARK: - Properties
    
    var lock: LockCache!
    
    // MARK: - Loading
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        lock = (context as! LockContext).lock
        
        updateUI()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // MARK: - Actions
    
    @IBAction func unlock(_ sender: WKInterfaceButton) {
        
        async { [weak self] in
            
            guard let controller = self else { return }
            
            do { try SessionController.shared.unlock(controller.lock.identifier) }
            
            catch { mainQueue { controller.showError("\(error)"); return } }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        
        setTitle(lock.name)
        
        let buttonImage: UIImage
        
        switch lock.permission {
        case .owner: buttonImage = #imageLiteral(resourceName: "watchOwner")
        case .admin: buttonImage = #imageLiteral(resourceName: "watchAdmin")
        case .anytime: buttonImage = #imageLiteral(resourceName: "watchAnytime")
        case .scheduled: buttonImage = #imageLiteral(resourceName: "watchScheduled")
        }
        
        imageView.setImage(buttonImage)
    }
}
