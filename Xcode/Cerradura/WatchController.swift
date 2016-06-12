//
//  WatchController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import WatchConnectivity
import SwiftFoundation
import CoreLock
import GATT

@available(iOS 9.3, *)
final class WatchController: NSObject, WCSessionDelegate {
    
    static let shared = WatchController()
    
    // MARK: - Properties
    
    var log: ((String) -> ())?
    
    private let session = WCSession.default()
    
    // MARK: - Methods
    
    func activate() {
        
        session.delegate = self
        session.activate()
    }
    
    // MARK: - WCSessionDelegate
    
    @objc(session:activationDidCompleteWithState:error:)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: NSError?) {
        
        guard activationState == .activated
            && session.isReachable else {
            
            log?("Activation error: \(error?.localizedDescription ?? "Not Reachable")")
            
            return
        }
        
        log?("Activation did complete")
    }
    
    @objc(session:didReceiveMessage:replyHandler:)
    func session(_ session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Swift.Void) {
        
        guard let identifierNumber = message[WatchMessageIdentifierKey] as? NSNumber,
            let identifier = WatchMessageType(rawValue: identifierNumber.uint8Value)
            else { fatalError("Invalid message: \(message)") }
        
        switch identifier {
            
        case .UnlockRequest:
            
            log?("Recieved unlock request")
            
            guard let foundLock = try? LockManager.shared.scan(duration: 1, filter: <#T##UUID?#>)
                else { replyHandler(UnlockResponse(error: "Lock not found").toMessage()); return }
            
            guard let cachedLock = Store.shared[foundLock.UUID]
                else { replyHandler(UnlockResponse(error: "No stored key for lock").toMessage()); return }
            
            do { try LockManager.shared.unlock(lock: foundLock, key: cachedLock.key.data) }
            
            catch { replyHandler(UnlockResponse(error: "\(error)").toMessage()); return }
            
            /// Success
            replyHandler(UnlockResponse().toMessage())
            
            print("Unlocked from Watch")
            
        case .CurrentLockRequest:
            
            log?("Recieved current lock request")
            
            if LockManager.shared.foundLock.value == nil {
                
                LockManager.shared.startScan()
            }
            
            guard let foundLock = LockManager.shared.foundLock.value,
                let cachedLock = Store.shared[foundLock.UUID]
                else { replyHandler(CurrentLockResponse().toMessage()); return }
            
            let response = CurrentLockResponse(permission: cachedLock.key.permission.type)
            
            replyHandler(response.toMessage())
            
        default: fatalError("Unexpected message: \(message)")
        }
    }
}