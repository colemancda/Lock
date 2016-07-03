//
//  Activity.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/3/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreLock

final class LockActivityItem: NSObject /*, UIActivityItemSource */ {
    
    let identifier: UUID
    
    init(identifier: UUID) {
        
        self.identifier = identifier
    }
    
    // MARK: UIActivityItemSource
    
    // FIXME: Implement UIActivityItemSource
}

/// `UIActivity` types
enum LockActivity: String {
    
    case newKey = "com.colemancda.cerradura.activity.newKey"
}

/// `UIActivity` subclass for sharing a key.
final class NewKeyActivity: UIActivity {
    
    override static func activityCategory() -> UIActivityCategory { return .action }
    
    private var item: LockActivityItem!
    
    override func activityType() -> String? {
        
        return LockActivity.newKey.rawValue
    }
    
    override func activityTitle() -> String? {
        
        return "Share Key"
    }
    
    override func activityImage() -> UIImage? {
        
        return #imageLiteral(resourceName: "activityNewKey")
    }
    
    override func canPerform(withActivityItems activityItems: [AnyObject]) -> Bool {
        
        guard let lockItem = activityItems.first as? LockActivityItem,
            let lockCache = Store.shared[cache: lockItem.identifier],
            let _ = LockManager.shared[lockItem.identifier] // Lock must be reachable
            else { return false }
        
        switch lockCache.permission {
            
        case .owner, .admin: return true
            
        default: return false
        }
    }
    
    override func prepare(withActivityItems activityItems: [AnyObject]) {
        
        self.item = activityItems.first as! LockActivityItem
    }
    
    override func activityViewController() -> UIViewController? {
        
        let navigationController = UIStoryboard(name: "NewKey", bundle: nil).instantiateInitialViewController() as! UINavigationController
        
        let destinationViewController = navigationController.viewControllers.first! as! NewKeySelectPermissionViewController
        
        destinationViewController.lockIdentifier = item.identifier
        
        destinationViewController.completion = { self.activityDidFinish($0) }
        
        return navigationController
    }
}
