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
                
        session = WCSession.defaultSession()
        session.delegate = self
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        guard session.activationState == .activated else {
            
            button.setEnabled(true)
            session.activate()
            scanAnimation.startAnimating()
            return
        }
        
        // request current lock
        session.sendMessage(CurrentLockRequest().toMessage(),
                            replyHandler: currentLockResponse,
                            errorHandler: { self.showError($0.localizedDescription) })
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
        
        guard lock != nil else {
            
            // request current lock
            session.sendMessage(CurrentLockRequest().toMessage(),
                                replyHandler: currentLockResponse,
                                errorHandler: { (error) in mainQueue { self.showError(error.localizedDescription) } })
            
            return
        }
        
        sender.setEnabled(false)
        
        session.sendMessage(UnlockRequest().toMessage(),
                            replyHandler: self.unlockResponse,
                            errorHandler: { (error) in mainQueue { self.showError(error.localizedDescription) } })
        
        print("Sent unlock message")
    }
    
    // MARK: - Private Functions
    
    private func didFindLock() {
        
        print("New lock value \(self.lock)")
        
        button.setEnabled(true)
        
        if let permission = self.lock {
            
            let imageName: String
            
            switch permission {
            case .admin: imageName = "watchAdmin"
            case .owner: imageName = "watchOwner"
            case .anytime: imageName = "watchAnytime"
            case .scheduled: imageName = "watchScheduled"
            }
            
            self.scanAnimation.stopAnimating()
            self.button.setBackgroundImageNamed(imageName)
            
        } else {
            
            self.scanAnimation.startAnimating()
        }
    }
    
    private func currentLockResponse(message: [String: AnyObject]) {
        
        guard let response = CurrentLockResponse(message: message)
            else { fatalError("Invalid message: \(message)") }
        
        mainQueue { self.lock = response.permission }
    }
    
    private func unlockResponse(message: [String: AnyObject]) {
        
        guard let response = UnlockResponse(message: message)
            else { fatalError("Invalid message: \(message)") }
        
        mainQueue {
            
            if let error = response.error {
                
                self.showError(error)
                return
            }
            
            self.button.setEnabled(true)
        }
    }
    
    private func showError(_ error: String) {
        
        print("Error: \(error)")
        
        let action = WKAlertAction(title: "OK", style: WKAlertActionStyle.`default`) { }
        
        self.presentAlert(withTitle: "Error", message: error, preferredStyle: .actionSheet, actions: [action])
        
        self.button.setEnabled(true)
        
        self.scanAnimation.startAnimating()
    }
    
    // MARK: - WCSessionDelegate
    
    @objc(session:activationDidCompleteWithState:error:)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: NSError?) {
        
        guard activationState == .activated && session.isReachable
            else {
            
            var message = "Cannot communicate with iPhone. "
            
            if let error = error {
                
                message += "(\(error.localizedDescription))"
                
            } else if session.isReachable == false {
                
                message += "iPhone is not reachable."
            }
            
            mainQueue { self.showError(message) }
            
            return
        }
        
        print("Session did activate")
        
        // request current lock
        session.sendMessage(CurrentLockRequest().toMessage(),
                            replyHandler: currentLockResponse,
                            errorHandler: { (error) in mainQueue { self.showError(error.localizedDescription) } })
    }
    
    @objc(session:didReceiveMessage:)
    func session(_ session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        
        guard let identifierNumber = message[WatchMessageIdentifierKey] as? NSNumber,
            let identifier = WatchMessageType(rawValue: identifierNumber.uint8Value)
            else { fatalError("Invalid message: \(message)") }
        
        switch identifier {
            
        case .FoundLockNotification:
            
            print("Recieved found lock notification")
            
            guard let notification = FoundLockNotification(message: message)
                else { fatalError("Invalid message: \(message)") }
            
            mainQueue { self.lock = notification.permission }
            
        default: fatalError("Unexpected message: \(message)")
        }
    }
}
