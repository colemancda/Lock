//
//  NewKeyViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/10/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import SwiftFoundation
import CoreLock

protocol NewKeyViewController: class, ActivityIndicatorViewController {
    
    var lockIdentifier: UUID! { get }
    
    var view: UIView! { get }
    
    func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> ())?)
    
    func dismiss(animated: Bool, completion: (() -> ())?)
    
    func showErrorAlert(_ localizedText: String, okHandler: (() -> ())?, retryHandler: (()-> ())?)
}

extension NewKeyViewController {
    
    func newKey(permission: Permission) {
        
        let lockIdentifier = self.lockIdentifier!
        
        // request name
        requestNewKeyName { (newKeyName) in
            
            guard let nameString = newKeyName
                else { return }
            
            guard let name = Key.Name(rawValue: nameString)
                else { self.newKeyError("Invalid name."); return }
            
            guard let (lockCache, parentKeyData) = Store.shared[lockIdentifier]
                else { self.newKeyError("The key for the specified lock has been deleted from the database."); return }
            
            let parentKey = (lockCache.keyIdentifier, parentKeyData)
            
            print("Setting up new key for lock \(lockIdentifier)")
            
            self.showProgressHUD()
            
            // add new key to lock
            async {
                
                let newKey = NewKey(identifier: UUID(), name: name, sharedSecret: KeyData(), permission: permission)
                
                do { try LockManager.shared.createNewKey(lockIdentifier, parentKey: parentKey, childKey: (newKey.identifier, newKey.permission, newKey.name), sharedSecret: newKey.sharedSecret)  }
                    
                catch { mainQueue { self.dismissProgressHUD(false); self.newKeyError("Could not create new key. (\(error))") }; return }
                
                print("Created new key \(newKey.identifier) (\(newKey.permission.type))")
                
                // save invitation file
                
                let newKeyInvitation = NewKeyInvitation(lock: lockIdentifier, key: newKey)
                
                let newKeyData = newKeyInvitation.toJSON().toString()!.toUTF8Data()
                
                let filePath = try! Foundation.FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("newKey-\(newKey.identifier).ekey").path
                
                guard FileManager.default.createFile(atPath: filePath, contents: newKeyData, attributes: nil)
                    else { fatalError("Could not write \(filePath) to disk") }
                
                // share new key
                mainQueue {
                    
                    self.dismissProgressHUD()
                    
                    // show activity controller
                    
                    let activityController = UIActivityViewController(activityItems: [URL(fileURLWithPath: filePath)], applicationActivities: nil)
                    
                    activityController.excludedActivityTypes = [.postToTwitter,
                                                                .postToFacebook,
                                                                .postToWeibo,
                                                                .print,
                                                                .copyToPasteboard,
                                                                .assignToContact,
                                                                .saveToCameraRoll,
                                                                .addToReadingList,
                                                                .postToFlickr,
                                                                .postToVimeo,
                                                                .postToTencentWeibo]
                    
                    activityController.completionWithItemsHandler = { (activityType, completed, items, error) in
                        
                        self.dismiss(animated: true, completion: nil)
                    }
                    
                    self.present(activityController, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func requestNewKeyName(_ completion: @escaping (String?) -> ()) {
        
        let alert = UIAlertController(title: "New Key",
                                      message: "Type a user friendly name for the new key.",
                                      preferredStyle: .alert)
        
        alert.addTextField { $0.text = "New Key" }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .`default`, handler: { (UIAlertAction) in
            
            completion((name: alert.textFields![0].text ?? ""))
            
            alert.dismiss(animated: true) {  }
            
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .destructive, handler: { (UIAlertAction) in
            
            completion(nil)
            
            alert.dismiss(animated: true) {  }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    private func newKeyError(_ error: String) {
        
        self.showErrorAlert(error, okHandler: { self.dismiss(animated: true, completion: nil) }, retryHandler: nil)
    }
}
