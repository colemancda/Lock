//
//  Key.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/22/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

public struct Key: Equatable, JSONEncodable, JSONDecodable {
    
    public let identifier: UUID
    
    public let data: KeyData
    
    public let permission: Permission
    
    /// The name of the key.
    ///
    /// - Note: Not applicable for Owner keys. 
    public var name: Name?
    
    public init(identifier: UUID = UUID(), name: Name? = nil, data: KeyData = KeyData(), permission: Permission) {
        
        self.identifier = identifier
        self.name = name
        self.data = data
        self.permission = permission
    }
}

// MARK: - Equatable

public func == (lhs: Key, rhs: Key) -> Bool {
    
    return lhs.identifier == rhs.identifier
        && lhs.data == rhs.data
        && lhs.permission == rhs.permission
        && lhs.name == rhs.name
}

// MARK: - JSON

public extension Key {
    
    enum JSONKey: String {
        
        case identifier, data, permission, name
    }
    
    init?(JSONValue: JSON.Value) {
        
        guard let JSONObject = JSONValue.objectValue,
            let identifierString = JSONObject[JSONKey.identifier.rawValue]?.stringValue,
            let identifier = UUID(rawValue: identifierString),
            let dataString = JSONObject[JSONKey.data.rawValue]?.stringValue,
            let data = Data(base64Encoded: dataString),
            let keyData = KeyData(data: data),
            let permissionDataString = JSONObject[JSONKey.permission.rawValue]?.stringValue,
            let permissionData = Data(base64Encoded: permissionDataString),
            let permission = Permission(bigEndian: permissionData)
            else { return nil }
        
        self.identifier = identifier
        self.data = keyData
        self.permission = permission
        
        if let name = JSONObject[JSONKey.name.rawValue]?.stringValue {
            
            guard let keyName = Key.Name(rawValue: name)
                else { return nil }
            
            self.name = keyName
            
        } else {
            
            self.name = nil
        }
    }
    
    func toJSON() -> JSON.Value {
        
        var jsonObject = JSON.Object(minimumCapacity: 4)
        
        jsonObject[JSONKey.identifier.rawValue] = .string(identifier.rawValue)
        
        jsonObject[JSONKey.data.rawValue] = .string(data.data.base64EncodedString())
        
        jsonObject[JSONKey.permission.rawValue] = .string(permission.toBigEndian().base64EncodedString())
        
        if let name = self.name {
            
            jsonObject[JSONKey.name.rawValue] = .string(name.rawValue)
        }
        
        return .object(jsonObject)
    }
}

// MARK: - Supporting Types

public extension Key {
    
    /// 64 byte String name.
    public struct Name: Equatable, RawRepresentable, DataConvertible, CustomStringConvertible {
        
        public static let maxLength = 64
        
        public let rawValue: String
        
        public init?(rawValue: String) {
            
            guard rawValue.utf8.count <= Name.maxLength
                && rawValue.isEmpty == false
                else { return nil }
            
            self.rawValue = rawValue
        }
        
        public init?(data: Data) {
            
            guard let string = String(UTF8Data: data)
                where string.isEmpty == false
                && data.bytes.count <= Name.maxLength
                else { return nil }
            
            self.rawValue = string
        }
        
        @inline(__always)
        public func toData() -> Data {
            
            return rawValue.toUTF8Data()
        }
        
        public var description: String {
            
            return rawValue
        }
    }
}
