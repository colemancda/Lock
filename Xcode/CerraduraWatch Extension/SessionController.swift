//
//  SessionController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/8/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import WatchConnectivity

final class SessionController: NSObject, WCSessionDelegate {
    
    static let shared = SessionController()
    
    // MARK: - Properties
    
    var timeout = 3
    
    var log: ((String) -> ())?
    
    let session = WCSession.default()
    
    let locks = Observable([LockCache]())
    
    let activationState = Observable(WCSessionActivationState.notActivated)
    
    private var operationState: (semaphore: DispatchSemaphore, error: Error?)!
    
    // MARK: - Methods
    
    func activate() throws {
        
        session.delegate = self
        session.activate()
        
        // wait
        try wait()
    }
    
    func requestLocks() throws {
        
        guard session.isReachable
            else { throw SessionControllerError.notReachable }
        
        guard session.activationState == .activated
            else { throw SessionControllerError.notActivated }
        
        // request current locks
        session.sendMessage(LocksRequest().toMessage(),
                            replyHandler: locksResponse,
                            errorHandler: { if self.operationState != nil { self.stopWaiting($0) } })
        
        guard try wait(timeout)
            else { throw SessionControllerError.timeout }
    }
    
    func unlock(_ lock: UUID) throws {
        
        guard session.isReachable
            else { throw SessionControllerError.notReachable }
        
        guard session.activationState == .activated
            else { throw SessionControllerError.notActivated }
        
        // request current locks
        session.sendMessage(UnlockRequest(lock: lock).toMessage(),
                            replyHandler: unlockResponse,
                            errorHandler: { if self.operationState != nil { self.stopWaiting($0) } })
        
        guard try wait(timeout)
            else { throw SessionControllerError.timeout }
    }
    
    // MARK: - Private Methods
    
    private func locksResponse(_ message: [String: Any]) {
        
        log?("Recieved locks updated notification")
        
        guard let response = LocksUpdatedNotification(message: message)
            else { fatalError("Invalid message: \(message)") }
        
        self.locks.value = response.locks
        
        if operationState != nil {
            
            stopWaiting()
        }
    }
    
    private func unlockResponse(_ message: [String: Any]) {
        
        log?("Recieved unlock response")
        
        guard let response = UnlockResponse(message: message)
            else { fatalError("Invalid message: \(message)") }
        
        if operationState != nil {
            
            if let errorText = response.error {
                
                stopWaiting(SessionControllerError.unlock(errorText))
                
            } else {
                
                stopWaiting()
            }
        }
    }
    
    @discardableResult
    private func wait(_ timeout: Int? = nil) throws -> Bool {
        
        assert(operationState == nil, "Already waiting for an asyncronous operation to finish")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        // set semaphore
        operationState = (semaphore, nil)
        
        // wait
        
        let dispatchTime: DispatchTime
        
        if let timeout = timeout {
            
            dispatchTime = DispatchTime.now() + Double(timeout)
            
        } else {
            
            dispatchTime = .distantFuture
        }
        
        // wait until expiratation or signal
        let success = semaphore.wait(timeout: dispatchTime) == .success
        
        let error = operationState.error
        
        // clear state
        operationState = nil
        
        if let error = error {
            
            throw error
        }
        
        return success
    }
    
    private func stopWaiting(_ error: Error? = nil, _ function: String = #function) {
        
        assert(operationState != nil, "Did not expect \(function)")
        
        operationState.error = error
        
        operationState.semaphore.signal()
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        // inform observers
        self.activationState.value = activationState
        
        guard activationState == .activated && session.isReachable else {
            
            let error: Error = error ?? SessionControllerError.notReachable
            
            log?("Error activating: \(error)")
            
            stopWaiting(error)
            
            return
        }
        
        log?("Session did activate")
        
        stopWaiting()
    }
    
    @objc(sessionReachabilityDidChange:)
    func sessionReachabilityDidChange(_ session: WCSession) {
        
        guard session.isReachable else {
            
            log?("iPhone is not reacheable.")
            
            return
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        guard let identifierNumber = message[WatchMessageIdentifierKey] as? NSNumber,
            let identifier = WatchMessageType(rawValue: identifierNumber.uint8Value)
            else { fatalError("Invalid message: \(message)") }
        
        switch identifier {
            
        case .LocksUpdatedNotification:
            
            self.locksResponse(message)
            
        default: fatalError("Unexpected message: \(message)")
        }
    }
}

// MARK: - Supporting Types

enum SessionControllerError: Error {
    
    case notReachable
    case notActivated
    case timeout
    case unlock(String)
}
