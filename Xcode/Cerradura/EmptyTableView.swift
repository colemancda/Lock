//
//  EmptyTableView.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import UIKit

/// View for the empty state of a table view.
final class EmptyTableView: UIView {
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var label: UILabel!
    
    // MARK: - Initialization
    
    static func loadFromNib() -> EmptyTableView {
        
        let nib = UINib(nibName: "EmptyTableView", bundle: nil)
        
        return nib.instantiate(withOwner: nil, options: nil).first as! EmptyTableView
    }
}

// MARK: - Protocol

@objc protocol EmptyTableViewController: class {
    
    var tableView: UITableView { get }
    
    var emptyTableView: EmptyTableView? { get set }
}

extension EmptyTableViewController {
    
    func showEmptyTableView(_ configure: (EmptyTableView) -> ()) {
        
        self.tableView.isScrollEnabled = false
        
        guard self.emptyTableView == nil else {
            
            configure(self.emptyTableView!)
            
            return
        }
        
        let emptyTableView = EmptyTableView.loadFromNib()
        
        configure(emptyTableView)
        
        emptyTableView.frame = self.tableView.bounds
        
        emptyTableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        emptyTableView.translatesAutoresizingMaskIntoConstraints = true
        
        self.tableView.addSubview(emptyTableView)
        
        self.emptyTableView = emptyTableView
    }
    
    func hideEmptyTableView() {
        
        self.tableView.isScrollEnabled = true
        
        self.emptyTableView?.removeFromSuperview()
        
        self.emptyTableView = nil
    }
}
