//
//  NewKeyInvitation.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/10/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import JSON

/// Exportable new key invitation.
public struct NewKeyInvitation: Equatable, JSONEncodable, JSONDecodable {
    
    public let lock: UUID
    
    public let key: NewKey
    
    public init(lock: UUID, key: NewKey) {
        
        self.lock = lock
        self.key = key
    }
}

// MARK: - Equatable

public func == (lhs: NewKeyInvitation, rhs: NewKeyInvitation) -> Bool {
    
    return lhs.lock == rhs.lock
        && lhs.key == rhs.key
}

// MARK: - JSON

public extension NewKeyInvitation {
    
    enum JSONKey: String {
        
        case lock, key
    }
    
    init?(JSONValue: JSON.Value) {
        
        guard let JSONObject = JSONValue.objectValue,
            let identifierString = JSONObject[JSONKey.lock.rawValue]?.stringValue,
            let identifier = UUID(rawValue: identifierString),
            let newKeyJSON = JSONObject[JSONKey.key.rawValue],
            let newKey = NewKey(JSONValue: newKeyJSON)
            else { return nil }
        
        self.lock = identifier
        self.key = newKey
    }
    
    func toJSON() -> JSON.Value {
        
        var jsonObject = JSON.Object(minimumCapacity: 2)
        
        jsonObject[JSONKey.lock.rawValue] = lock.toJSON()
        
        jsonObject[JSONKey.key.rawValue] = key.toJSON()
        
        return .object(jsonObject)
    }
}
