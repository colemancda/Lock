//
//  NewKey.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/10/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

/// Temporary new key. (non-owner)
public struct NewKey: Equatable, JSONEncodable, JSONDecodable {
    
    public let identifier: UUID
    
    public let sharedSecret: KeyData
    
    public let permission: Permission
    
    public let date: Date
    
    public var name: Key.Name
    
    public init(identifier: UUID, date: Date = Date(), name: Key.Name, sharedSecret: KeyData, permission: Permission) {
        
        assert(permission != .owner, "Cannot create owner new key")
        
        self.identifier = identifier
        self.name = name
        self.sharedSecret = sharedSecret
        self.permission = permission
        self.date = date
    }
}

// MARK: - Equatable

public func == (lhs: NewKey, rhs: NewKey) -> Bool {
    
    return lhs.identifier == rhs.identifier
        && lhs.sharedSecret == rhs.sharedSecret
        && lhs.permission == rhs.permission
        && lhs.name == rhs.name
        && lhs.date == rhs.date
}

// MARK: - JSON

public extension NewKey {
    
    enum JSONKey: String {
        
        case identifier, sharedSecret, permission, name, date
    }
    
    init?(JSONValue: JSON.Value) {
        
        guard let JSONObject = JSONValue.objectValue,
            let identifierString = JSONObject[JSONKey.identifier.rawValue]?.stringValue,
            let identifier = UUID(rawValue: identifierString),
            let dataString = JSONObject[JSONKey.sharedSecret.rawValue]?.stringValue,
            let data = Data(base64Encoded: dataString),
            let keyData = KeyData(data: data),
            let permissionDataString = JSONObject[JSONKey.permission.rawValue]?.stringValue,
            let permissionData = Data(base64Encoded: permissionDataString),
            let permission = Permission(bigEndian: permissionData),
            let date = JSONObject[JSONKey.date.rawValue]?.doubleValue,
            let name = JSONObject[JSONKey.name.rawValue]?.stringValue,
            let keyName = Key.Name(rawValue: name)
            else { return nil }
        
        self.identifier = identifier
        self.sharedSecret = keyData
        self.permission = permission
        self.name = keyName
        self.date = Date(timeIntervalSince1970: date)
    }
    
    func toJSON() -> JSON.Value {
        
        var jsonObject = JSON.Object(minimumCapacity: 5)
        
        jsonObject[JSONKey.identifier.rawValue] = .string(identifier.rawValue)
        
        jsonObject[JSONKey.sharedSecret.rawValue] = .string(sharedSecret.data.base64EncodedString())
        
        jsonObject[JSONKey.permission.rawValue] = .string(permission.toBigEndian().base64EncodedString())
        
        jsonObject[JSONKey.name.rawValue] = .string(name.rawValue)
        
        jsonObject[JSONKey.date.rawValue] = .double(date.timeIntervalSince1970)
        
        return .object(jsonObject)
    }
}
