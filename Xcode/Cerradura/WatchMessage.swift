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
    
    init?(message: [String: Any])
    
    func toMessage() -> [String: Any]
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
    
    static func from(message: [[String: Any]]) -> [LockCache]? {
        
        var values = [LockCache]()
        
        for encoded in message {
            
            guard let value = LockCache(message: encoded)
                else { return nil }
            
            values.append(value)
        }
        
        return values
    }
    
    init?(message: [String: Any]) {
        
        guard let identifierString = message[Property.identifier.rawValue] as? String,
            let identifier = UUID(rawValue: identifierString),
            let name = message[Property.name.rawValue] as? String,
            let modelRawValue = (message[Property.model.rawValue] as? NSNumber)?.uint8Value,
            let model = Model(rawValue: modelRawValue),
            let version = (message[Property.version.rawValue] as? NSNumber)?.uint64Value,
            let permissionData = message[Property.permission.rawValue] as? Data,
            let permission = Permission(bigEndian: permissionData),
            let keyIdentifierString = message[Property.keyIdentifier.rawValue] as? String,
            let keyIdentifier = UUID(rawValue: keyIdentifierString)
            else { return nil }
        
        self.identifier = identifier
        self.name = name
        self.model = model
        self.version = version
        self.permission = permission
        self.keyIdentifier = keyIdentifier
        
        #if os(iOS)
        self.packageVersion = nil
        #endif
    }
    
    func toMessage() -> [String: Any] {
        
        return [Property.identifier.rawValue: identifier.rawValue,
                Property.name.rawValue: name,
                Property.model.rawValue: NSNumber(value: model.rawValue),
                Property.version.rawValue: NSNumber(value: version),
                Property.permission.rawValue: permission.toBigEndian(),
                Property.keyIdentifier.rawValue: keyIdentifier.rawValue]
    }
}

struct LocksRequest {
    
    static let messageType = WatchMessageType.LocksRequest
    
    init() { }
    
    init?(message: [String: Any]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value),
            messageType == type(of: self).messageType
            else { return nil }
    }
    
    func toMessage() -> [String: Any] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: type(of: self).messageType.rawValue)]
    }
}

struct LocksUpdatedNotification: WatchMessage {
    
    enum Key: String { case locks }
    
    static let messageType = WatchMessageType.LocksUpdatedNotification
    
    let locks: [LockCache]
    
    init(locks: [LockCache]) {
        
        self.locks = locks
    }
    
    init?(message: [String: Any]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value),
            let locksMessage = message[Key.locks.rawValue] as? [[String: AnyObject]],
            let locks = LockCache.from(message: locksMessage),
            messageType == type(of: self).messageType
            else { return nil }
        
        self.locks = locks
    }
    
    func toMessage() -> [String: Any] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: type(of: self).messageType.rawValue),
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
    
    init?(message: [String: Any]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value),
            messageType == type(of: self).messageType,
            let lockString = message[Key.lock.rawValue] as? String,
            let lock = UUID(rawValue: lockString)
            else { return nil }
        
        self.lock = lock
    }
    
    func toMessage() -> [String: Any] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: type(of: self).messageType.rawValue),
                Key.lock.rawValue: lock.rawValue]
    }
}

struct UnlockResponse: WatchMessage {
    
    enum Key: String { case error }
    
    static let messageType = WatchMessageType.UnlockResponse
    
    var error: String?
    
    init(error: String? = nil) {
        
        self.error = error
    }
    
    init?(message: [String: Any]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value),
            messageType == type(of: self).messageType
            else { return nil }
        
        /// optional value
        if let error = message[Key.error.rawValue] as? String {
            
            self.error = error
        }
    }
    
    func toMessage() -> [String: Any] {
        
        var message: [String: Any] = [WatchMessageIdentifierKey: NSNumber(value: type(of: self).messageType.rawValue)]
        
        message[Key.error.rawValue] = self.error
        
        return message
    }
}
