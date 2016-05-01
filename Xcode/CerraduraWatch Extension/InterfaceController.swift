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
    
    private var session: WCSession!
    
    private var lock: PermissionType? {
        
        didSet { didFindLock() }
    }
    
    // MARK: - Private Properties
    
    private lazy var scanAnimation: AnimatedButtonController = AnimatedButtonController(images: ["watchScan1", "watchScan2", "watchScan3", "watchScan4"], interval: 0.5, target: self.button)
    
    // MARK: - Loading

    override func awake(withContext context: AnyObject?) {
        super.awake(withContext: context)
        
        scanAnimation.startAnimating()
        
        session = WCSession.defaultSession()
        session.delegate = self
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        session.activate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // MARK: - Actions
    
    @IBAction func action(_ sender: WKInterfaceButton) {
        
        guard session.activationState == .activated else {
            
            button.setEnabled(true)
            session.activate()
            scanAnimation.startAnimating()
            return
        }
        
        guard lock != nil else { return }
        
        sender.setEnabled(false)
        
        session.sendMessage(UnlockRequest().toMessage(),
                            replyHandler: self.unlockResponse,
                            errorHandler: { self.unlockError($0.localizedDescription) })
        
    }
    
    // MARK: - Private Functions
    
    private func didFindLock() {
        
        button.setEnabled(true)
        
        if let permission = self.lock {
            
            let imageName: String
            
            switch permission {
            case .admin: imageName = "watchAdmin"
            case .owner: imageName = "watchOwner"
            case .anytime: imageName = "watchAnytime"
            case .scheduled: imageName = "watchScheduled"
            }
            
            self.button.setBackgroundImageNamed(imageName)
            
        } else {
            
            self.scanAnimation.startAnimating()
        }
    }
    
    private func unlockResponse(message: [String: AnyObject]) {
        
        guard let response = UnlockResponse(message: message)
            else { fatalError("Invalid message: \(message)") }
        
        if let error = response.error {
            
            unlockError(error)
            return
        }
        
        button.setEnabled(true)
    }
    
    private func unlockError(_ error: String) {
        
        let action = WKAlertAction(title: "OK", style: WKAlertActionStyle.`default`) { self.button.setEnabled(true) }
        
        self.presentAlert(withTitle: "Error", message: error, preferredStyle: .actionSheet, actions: [action])
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
        
        print("Session did activate")
    }
    
    @objc(session:didReceiveMessage:)
    func session(_ session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        
        guard let identifierRawValue = message[WatchMessageIdentifierKey] as? WatchMessageType.RawValue,
            let identifier = WatchMessageType(rawValue: identifierRawValue)
            else { return }
        
        switch identifier {
            
        case .FoundLockNotification:
            
            print("Recieved found lock notification")
            
            guard let notification = FoundLockNotification(message: message)
                else { fatalError("Invalid message: \(message)") }
            
            lock = notification.permission
            
        default: fatalError("Unexpected message: \(message)")
        }
    }
}
