//
//  NewKeySelectPermissionViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/26/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreLock
import SwiftFoundation

final class NewKeySelectPermissionViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    
    var lockIdentifier: SwiftFoundation.UUID!
    
    private let permissionTypes: [PermissionType] = [.admin, .anytime, .scheduled]
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.estimatedRowHeight = 100
        self.tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    // MARK: - Methods
    
    private func configure(cell: PermissionTypeTableViewCell, at indexPath: NSIndexPath) {
        
        let permissionType = permissionTypes[indexPath.row]
        
        let permissionImage: UIImage
        
        let permissionTypeName: String
        
        let permissionText: String
        
        switch permissionType {
            
        case .admin:
            
            permissionImage = UIImage(named: "permissionBadgeAdmin")!
            
            permissionTypeName = "Admin"
            
            permissionText = "Admin keys have unlimited access, and can create new keys."
            
        case .anytime:
            
            permissionImage = UIImage(named: "permissionBadgeAnytime")!
            
            permissionTypeName = "Anytime"
            
            permissionText = "Anytime keys have unlimited access, but cannot create new keys."
            
        case .scheduled:
            
            permissionImage = UIImage(named: "permissionBadgeScheduled")!
            
            permissionTypeName = "Scheduled"
            
            permissionText = "Scheduled keys have limited access during specified hours, and expire at a certain date. New keys cannot be created from this key"
            
        case .owner:
            
            fatalError("Cannot create owner keys")
        }
        
        cell.permissionImageView.image = permissionImage
        
        cell.permissionTypeLabel.text = permissionTypeName
        
        cell.permissionDescriptionLabel.text = permissionText
    }
    
    // MARK: - UITableViewDatasource
    
    @objc func numberOfSectionsInTableView(_ tableView: UITableView) -> Int {
        
        return 1
    }
    
    @objc func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return permissionTypes.count
    }
    
    @objc func tableView(_ tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: PermissionTypeTableViewCell.resuseIdentifier, for: indexPath) as! PermissionTypeTableViewCell
        
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedType = permissionTypes[indexPath.row]
        
        switch selectedType {
            
        case .admin, .anytime:
            
            let permission: Permission
            
            switch selectedType {
            case .admin: permission = .admin
            case .anytime: permission = .anytime
            default: fatalError()
            }
            
            let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "newKeyParent") as! NewKeyParentViewController
            
            viewController.newKey = (lockIdentifier, permission)
            
            self.show(viewController, sender: self)
            
        case .scheduled:
            
            //let viewController = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "newKeyScheduled") as! NewKeyScheduleViewController
            
            fatalError()
            
        case .owner: fatalError("Cannot create owner key")
        }
    }
}

// MARK: - Supporting Types

private extension NewKeySelectPermissionViewController {
    
    struct Option {
        
        let type: PermissionType
        
        let name: String
        
        let description: String
    }
}

final class PermissionTypeTableViewCell: UITableViewCell {
    
    static let resuseIdentifier = "PermissionTypeTableViewCell"
    
    @IBOutlet weak var permissionImageView: UIImageView!
    
    @IBOutlet weak var permissionTypeLabel: UILabel!
    
    @IBOutlet weak var permissionDescriptionLabel: UILabel!
}
