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
import enum CoreLock.PermissionType
#endif

/// Messages to send using `WatchConnectivity`.
public protocol WatchMessage {
    
    static var messageType: WatchMessageType { get }
    
    init?(message: [String: AnyObject])
    
    func toMessage() -> [String: AnyObject]
}

let WatchMessageIdentifierKey = "message"

public enum WatchMessageType: UInt8 {
    
    case FoundLockNotification
    case UnlockRequest
    case UnlockResponse
    case CurrentLockRequest
    case CurrentLockResponse
}

public struct FoundLockNotification: WatchMessage {
    
    enum Key: String { case permission }
    
    public static let messageType = WatchMessageType.FoundLockNotification
    
    public var permission: PermissionType?
    
    public init(permission: PermissionType? = nil) {
        
        self.permission = permission
    }
    
    public init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType
            else { return nil }
        
        /// optional value
        if let permissionRawValue = message[Key.permission.rawValue] as? NSNumber {
            
            guard let permission = PermissionType(rawValue: permissionRawValue.uint8Value)
                else { return nil }
            
            self.permission = permission
        }
    }
    
    public func toMessage() -> [String: AnyObject] {
        
        var message = [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue)]
        
        if let permission = self.permission {
            
            message[Key.permission.rawValue] = NSNumber(value: permission.rawValue)
        }
        
        return message
    }
}

public struct UnlockRequest: WatchMessage {
    
    public static let messageType = WatchMessageType.UnlockRequest
    
    public init() { }
    
    public init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType
            else { return nil }
    }
    
    public func toMessage() -> [String: AnyObject] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue)]
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

public struct CurrentLockRequest {
    
    public static let messageType = WatchMessageType.CurrentLockRequest
    
    public init() { }
    
    public init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType
            else { return nil }
    }
    
    public func toMessage() -> [String: AnyObject] {
        
        return [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue)]
    }
}

public struct CurrentLockResponse: WatchMessage {
    
    enum Key: String { case permission }
    
    public static let messageType = WatchMessageType.CurrentLockResponse
    
    public var permission: PermissionType?
    
    public init(permission: PermissionType? = nil) {
        
        self.permission = permission
    }
    
    public init?(message: [String: AnyObject]) {
        
        guard let identifier = message[WatchMessageIdentifierKey] as? NSNumber,
            let messageType = WatchMessageType(rawValue: identifier.uint8Value)
            where messageType == self.dynamicType.messageType
            else { return nil }
        
        /// optional value
        if let permissionRawValue = message[Key.permission.rawValue] as? NSNumber {
            
            guard let permission = PermissionType(rawValue: permissionRawValue.uint8Value)
                else { return nil }
            
            self.permission = permission
        }
    }
    
    public func toMessage() -> [String: AnyObject] {
        
        var message = [WatchMessageIdentifierKey: NSNumber(value: self.dynamicType.messageType.rawValue)]
        
        if let permission = self.permission {
            
            message[Key.permission.rawValue] = NSNumber(value: permission.rawValue)
        }
        
        return message
    }
}
