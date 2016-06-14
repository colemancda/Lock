//
//  Async.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 6/12/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation

func mainQueue(_ block: () -> ()) {
    
    NSOperationQueue.main().addOperation(block)
}

/// Perform a task on the internal queue.
func async(_ block: () -> ()) {
    
    dispatch_async(queue) { block() }
}

private let queue: dispatch_queue_t = dispatch_queue_create("Cerradura Internal Queue", DISPATCH_QUEUE_SERIAL)