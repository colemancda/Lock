//
//  LockTableViewCell.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import UIKit

final class LockTableViewCell: UITableViewCell {
    
    static let reuseIdentifier = "LockTableViewCell"
    
    @IBOutlet weak var permissionImageView: UIImageView!
    
    @IBOutlet weak var lockNameLabel: UILabel!
    
    @IBOutlet weak var permissionLabel: UILabel!
}
