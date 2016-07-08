//
//  WatchMessage.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 5/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import WatchConnectivity

#if os(iOS)
import CoreLock
#endif

/// Messages to send using `WatchConnectivity`.
protocol WatchMessage {
    
    static var messageType: WatchMessageType { get }
    
    init?(message: [String: AnyObject])
    
    func toMessage() -> [String: AnyObject]
}

let WatchMessageIdentifierKey = "message"

enum WatchMessageType: UInt8 {
    
    case LocksRequest
    case LocksUpdatedNotification
    case UnlockRequest
    case UnlockResponse
}

// Declare LockCache for WatchOS
#if os(watchOS)

    struct LockCache {
        
        enum Property: String {
            
            case identifier, name, model, version, permission, keyIdentifier
        }
        
        let identifier: UUID
        
        let name: String
        
        let model: Model
        
        let version: UInt64
        
        let permission: Permission
        
        let keyIdentifier: UUID
    }
    
#endif

extension LockCache {
    
    static func from(message: [[String: AnyObject]]) -> [LockCache]? {
        
        var values = [LockCache]()
        
        for encoded in message {
            
            guard let value = LockCache(message: encoded)
                else { return nil }
            
            values.append(value)
        }
        
        return values
    }
    
    init?(message: [String: AnyObject]) {
        
        guard let identifier = message[Property.identifier.rawValue] as? UUID,
            let name = message[Property.name.rawValue] as? String,
            let modelRawValue = (message[Property.model.rawValue] as? NSNumber)?.uint8Value,
            let model = Model(rawValue: modelRawValue),
            let version = (message[Property.version.rawValue] as? NSNumber)?.uint64Value,
            let permissionData = message[Property.permission.rawValue] as? Data,
            let permission = Permission(bigEndian: permissionData),
            let keyIdentifier = message[Property.keyIdentifier.rawValue] as? UUID
            else { return nil }
        
        self.identifier = identifier
        self.name = name
        self.model = model
        self.version = version
        self.permission = permission
        self.keyIdentifier = keyIdentifier
    }
    
    func toMessage() -> [String: AnyObject] {
        
        return [Property.identifier.rawValue: identifier,
                Property.name.rawValue: name,
                Property.model.rawValue: NSNumber(value: model.rawValue),
                Property.version.rawValue: NSNumber(value: version),
                Property.permission.rawValue: permission.toBigEndian(),
                Property.keyIdentifier.rawValue: keyIdentifier]
    }
}

struct LocksRequest {
    
    static let messageType = WatchMessageType.LocksRequest
    
    init() { }
    
    init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType
            else { return nil }
    }
    
    func toMessage() -> [String: AnyObject] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue)]
    }
}

struct LocksUpdatedNotification: WatchMessage {
    
    enum Key: String { case locks }
    
    static let messageType = WatchMessageType.LocksUpdatedNotification
    
    let locks: [LockCache]
    
    init(locks: [LockCache]) {
        
        self.locks = locks
    }
    
    init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value),
            let locksMessage = message[Key.locks.rawValue] as? [[String: AnyObject]],
            let locks = LockCache.from(message: locksMessage)
            where messageType == self.dynamicType.messageType
            else { return nil }
        
        self.locks = locks
    }
    
    func toMessage() -> [String: AnyObject] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue),
                Key.locks.rawValue: locks.map({ $0.toMessage() })]
    }
}

struct UnlockRequest: WatchMessage {
    
    enum Key: String { case lock }
    
    static let messageType = WatchMessageType.UnlockRequest
    
    let lock: UUID
    
    init(lock: UUID) {
        
        self.lock = lock
    }
    
    init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType,
            let lock = message[Key.lock.rawValue] as? UUID
            else { return nil }
        
        self.lock = lock
    }
    
    func toMessage() -> [String: AnyObject] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue),
                Key.lock.rawValue: lock]
    }
}

struct UnlockResponse: WatchMessage {
    
    enum Key: String { case error }
    
    static let messageType = WatchMessageType.UnlockResponse
    
    var error: String?
    
    init(error: String? = nil) {
        
        self.error = error
    }
    
    init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType
            else { return nil }
        
        /// optional value
        if let error = message[Key.error.rawValue] as? String {
            
            self.error = error
        }
    }
    
    func toMessage() -> [String: AnyObject] {
        
        var message: [String: AnyObject] = [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue)]
        
        message[Key.error.rawValue] = self.error
        
        return message
    }
}
