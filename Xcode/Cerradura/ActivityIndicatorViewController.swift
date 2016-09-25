//
//  ActivityIndicatorViewController.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 9/25/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import JGProgressHUD

protocol ActivityIndicatorViewController: class {
    
    var view: UIView! { get }
    
    var navigationItem: UINavigationItem { get }
    
    var progressHUD: JGProgressHUD { get }
    
    func showProgressHUD()
    
    func dismissProgressHUD(_ animated: Bool)
}

extension ActivityIndicatorViewController {
    
    func showProgressHUD() {
        
        self.view.isUserInteractionEnabled = false
        
        progressHUD.show(in: self.view)
    }
    
    func dismissProgressHUD(_ animated: Bool = true) {
        
        self.view.isUserInteractionEnabled = true
        
        progressHUD.dismiss(animated: animated)
    }
}
