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
import CoreData

@available(iOS 9.3, *)
final class WatchController: NSObject, WCSessionDelegate, NSFetchedResultsControllerDelegate {
    
    static let shared = WatchController()
    
    // MARK: - Properties
    
    var log: ((String) -> ())?
    
    private let session = WCSession.default()
    
    private lazy var fetchedResultsController: NSFetchedResultsController<NSManagedObject> = {
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: LockCache.entityName)
        
        fetchRequest.sortDescriptors = [SortDescriptor(key: LockCache.Property.name.rawValue, ascending: true)]
        
        let controller = NSFetchedResultsController<NSManagedObject>(fetchRequest: fetchRequest, managedObjectContext: Store.shared.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        controller.delegate = self
        
        return controller
    }()
    
    // MARK: - Methods
    
    func activate() {
        
        session.delegate = self
        session.activate()
        
        try! fetchedResultsController.performFetch()
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    @objc(controllerDidChangeContent:)
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        /*
        guard session.activationState == .activated
            else { log?("Could not send found lock notification to Watch app, session not activated."); return }
        
        guard session.isReachable
            else { log?("Could not send found lock notification to Watch app, the counterpart app is not available for live messaging."); return }
        */
        
        guard session.activationState == .activated && session.isReachable
            else { return }
        
        let managedObjects = (controller.fetchedObjects ?? []) as! [NSManagedObject]
        
        let locks = LockCache.from(managedObjects: managedObjects)
        
        let notification = LocksUpdatedNotification(locks: locks)
        
        session.sendMessage(notification.toMessage(),
                            replyHandler: nil,
                            errorHandler: { self.log?("Error sending locks updated notification: \($0.localizedDescription)") } )
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
    func session(_ session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> ()) {
        
        guard let identifierNumber = message[WatchMessageIdentifierKey] as? NSNumber,
            let identifier = WatchMessageType(rawValue: identifierNumber.uint8Value)
            else { fatalError("Invalid message: \(message)") }
        
        switch identifier {
            
        case .UnlockRequest:
            
            log?("Recieved unlock request")
            
            guard let unlockRequest = UnlockRequest(message: message)
                else { fatalError("Invalid message: \(message)") }
            
            guard LockManager.shared.foundLocks.value.contains({ $0.identifier == unlockRequest.lock })
                else { replyHandler(UnlockResponse(error: "Lock disconnected").toMessage()); return }
            
            guard let (lockCache, keyData) = Store.shared[unlockRequest.lock]
                else { replyHandler(UnlockResponse(error: "No stored key for lock").toMessage()); return }
            
            do { try LockManager.shared.unlock(unlockRequest.lock, key: (lockCache.keyIdentifier, keyData)) }
            
            catch { replyHandler(UnlockResponse(error: "\(error)").toMessage()); return }
            
            /// Success
            replyHandler(UnlockResponse().toMessage())
            
            log?("Unlocked \(unlockRequest.lock) from Watch")
            
        default: fatalError("Unexpected message: \(message)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
        log?("Session inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
        log?("Session deactivated")
    }
}
