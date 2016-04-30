//
//  Observable.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/30/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

public protocol ObservableProtocol {
    
    associatedtype Value
    
    var value: Value { get }
    
    func add(_ observer: Value -> ()) -> Int
    
    func remove(_ observer: Int) -> Bool
}

public final class Observable<Value>: ObservableProtocol {
    
    // MARK: - Properties
    
    public internal(set) var value: Value {
        
        didSet {
            
            for observer in observers {
                
                observer.callback(value)
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var observers = [Observer<Value>]()
    
    private var nextID = 1
    
    // MARK: - Initialization
    
    public init(_ value: Value) {
        
        self.value = value
    }
    
    // MARK: - Methods
    
    public func add(_ observer: Value -> ()) -> Int {
        
        let identifier = nextID
        
        // create notification
        let observer = Observer(identifier: identifier, callback: observer)
        
        // increment ID
        nextID += 1
        
        // add to queue
        observers.append(observer)
        
        return identifier
    }
    
    public func remove(_ observer: Int) -> Bool {
        
        guard let index = observers.index(where: { $0.identifier == observer })
            else { return false }
        
        observers.remove(at: index)
        
        return true
    }
}

public extension Observable where Value: NilLiteralConvertible {
    
    convenience init() { self.init(nil) }
}

private struct Observer<Value> {
    
    let identifier: Int
    
    let callback: Value -> ()
    
    init(identifier: Int, callback: Value -> ()) {
        
        self.identifier = identifier
        self.callback = callback
    }
}