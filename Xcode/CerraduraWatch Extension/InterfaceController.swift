//
//  InterfaceController.swift
//  CerraduraWatch Extension
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import WatchKit
import Foundation

final class InterfaceController: WKInterfaceController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var button: WKInterfaceButton!
    
    // MARK: - Properties
    
    private lazy var scanAnimation: AnimatedButtonController = AnimatedButtonController.init(images: ["watchScan1", "watchScan2", "watchScan3", "watchScan4"], interval: 0.5, target: self.button)
    
    // MARK: - Loading

    override func awake(withContext context: AnyObject?) {
        super.awake(withContext: context)
        
        scanAnimation.startAnimating()
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
    
    @IBAction func action(_ sender: AnyObject?) {
        
        
    }
}
