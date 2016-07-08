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
public protocol WatchMessage {
    
    static var messageType: WatchMessageType { get }
    
    init?(message: [String: AnyObject])
    
    func toMessage() -> [String: AnyObject]
}

let WatchMessageIdentifierKey = "message"

public enum WatchMessageType: UInt8 {
    
    case LocksUpdatedNotification
    case UnlockRequest
    case UnlockResponse
}

public struct LocksUpdatedNotification: WatchMessage {
    
    enum Key: String { case locks }
    
    public static let messageType = WatchMessageType.LocksUpdatedNotification
    
    public let locks: [LockObject]
    
    public init(locks: [LockObject]) {
        
        self.locks = locks
    }
    
    public init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType,
            let locks = message[Key.locks.rawValue] as? [LockObject]
            else { return nil }
        
        self.locks = locks
    }
    
    public func toMessage() -> [String: AnyObject] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue),
                Key.locks.rawValue: locks]
    }
}

// NSCoding version of `LockCache`.
public final class LockObject: NSObject, NSCoding {
    
    let identifier: UUID
    
    let name: String
    
    let model: Model
    
    let version: UInt64
    
    let permission: Permission
    
    let keyIdentifier: UUID
    
    public init(_ lockCache: LockCache) {
        
        self.identifier = lockCache.identifier
        self.name = lockCache.name
        self.model = lockCache.model
        self.version = lockCache.version
        self.permission = lockCache.permission
        self.keyIdentifier = lockCache.keyIdentifier
    }
}

public struct UnlockRequest: WatchMessage {
    
    enum Key: String { case lock }
    
    public static let messageType = WatchMessageType.UnlockRequest
    
    public let lock: UUID
    
    public init(lock: UUID) {
        
        self.lock = lock
    }
    
    public init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType,
            let lock = message[Key.lock.rawValue] as? UUID
            else { return nil }
        
        self.lock = lock
    }
    
    public func toMessage() -> [String: AnyObject] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue),
                Key.lock.rawValue: lock]
    }
}

public struct UnlockResponse: WatchMessage {
    
    enum Key: String { case error }
    
    public static let messageType = WatchMessageType.UnlockResponse
    
    public var error: String?
    
    public init(error: String? = nil) {
        
        self.error = error
    }
    
    public init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType
            else { return nil }
        
        /// optional value
        if let error = message[Key.error.rawValue] as? String {
            
            self.error = error
        }
    }
    
    public func toMessage() -> [String: AnyObject] {
        
        var message: [String: AnyObject] = [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue)]
        
        message[Key.error.rawValue] = self.error
        
        return message
    }
}
