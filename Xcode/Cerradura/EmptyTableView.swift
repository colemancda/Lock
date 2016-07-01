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
    
    @IBOutlet weak var button: UIButton!
    
    @IBOutlet weak var imageView: UIImageView!
    
    static func loadFromNib() -> EmptyTableView {
        
        let nib = UINib(nibName: "EmptyTableView", bundle: nil)
        
        return nib.instantiate(withOwner: nil, options: nil).first as! EmptyTableView
    }
}

// MARK: - Protocol

@objc protocol EmptyTableViewController: class {
    
    var tableView: UITableView { get }
    
    var emptyTableView: EmptyTableView? { get set }
    
    func emptyTableViewAction(_ sender: UIButton)
}

extension EmptyTableViewController {
    
    func showEmptyTableView(_ configure: (UIImageView) -> ()) {
        
        guard self.emptyTableView == nil else { return }
        
        let emptyTableView = EmptyTableView.loadFromNib()
        
        configure(emptyTableView.imageView)
        
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
