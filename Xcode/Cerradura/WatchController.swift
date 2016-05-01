//
//  WatchController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import WatchConnectivity

@available(iOS 9.3, *)
final class WatchController: NSObject, WCSessionDelegate {
    
    static let shared = WatchController()
    
    // MARK: - Properties
    
    var log: (String -> ())?
    
    private let session = WCSession.defaultSession()
    
    // MARK: - Methods
    
    func activate() {
        
        session.delegate = self
        session.activate()
    }
    
    // MARK: - WCSessionDelegate
    
    @objc(session:activationDidCompleteWithState:error:)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: NSError?) {
        
        guard activationState == .activated else {
            
            log?("Activation error: \(error?.localizedDescription ?? "None")")
            
            return
        }
        
        log?("Activation did complete")
    }
}