//
//  Async.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 6/12/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation

protocol AsyncProtocol {
    
    var queue: dispatch_queue_t { get }
}

extension AsyncProtocol {
    
    /// Perform a task on the internal queue.
    func async(_ block: () -> ()) {
        
        dispatch_async(queue) { block() }
    }
}

func mainQueue(_ block: () -> ()) {
    
    NSOperationQueue.main().addOperation(block)
}