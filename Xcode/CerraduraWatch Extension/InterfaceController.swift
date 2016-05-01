//
//  InterfaceController.swift
//  CerraduraWatch Extension
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import WatchKit
import WatchConnectivity
import Foundation

final class InterfaceController: WKInterfaceController, WCSessionDelegate {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var button: WKInterfaceButton!
    
    // MARK: - Properties
    
    var session: WCSession!
    
    // MARK: - Private Properties
    
    private lazy var scanAnimation: AnimatedButtonController = AnimatedButtonController(images: ["watchScan1", "watchScan2", "watchScan3", "watchScan4"], interval: 0.5, target: self.button)
    
    // MARK: - Loading

    override func awake(withContext context: AnyObject?) {
        super.awake(withContext: context)
        
        scanAnimation.startAnimating()
        
        session = WCSession.defaultSession()
        session?.delegate = self
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        session?.activate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // MARK: - Actions
    
    @IBAction func action(_ sender: AnyObject?) {
        
        
    }
    
    // MARK: - WCSessionDelegate
    
    @objc(session:activationDidCompleteWithState:error:)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: NSError?) {
        
        guard activationState == .activated else {
            
            var message = "Cannot communicate with iPhone. "
            
            if let error = error {
                
                message += "(\(error.localizedDescription))"
            }
            
            let action = WKAlertAction(title: "OK", style: WKAlertActionStyle.`default`) { }
            
            self.presentAlert(withTitle: "Error", message: message, preferredStyle: .actionSheet, actions: [action])
            
            return
        }
        
        
    }
}
