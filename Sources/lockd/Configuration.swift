//
//  Configuration.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import CoreLock

struct Configuration: JSONEncodable, JSONDecodable {
    
    /// The lock's identifier.
    let identifier: UUID
    
    /// Whether HomeKit support is enabled.
    var isHomeKitEnabled: Bool = false
    
    /// Initializes a new `Configuration`. 
    init() { identifier = UUID() }
}

// MARK: - JSON

extension Configuration {
    
    enum JSONKey: String {
        
        case identifier, homekit
    }
    
    init?(JSONValue: JSON.Value) {
        
        guard let JSONObject = JSONValue.objectValue,
            let identifierString = JSONObject[JSONKey.identifier.rawValue]?.rawValue as? String,
            let identifier = UUID(rawValue: identifierString),
            let isHomeKitEnabled = JSONObject[JSONKey.homekit.rawValue]?.rawValue as? Bool
            else { return nil }
        
        self.identifier = identifier
        self.isHomeKitEnabled = isHomeKitEnabled
    }
    
    func toJSON() -> JSON.Value {
        
        return .object([JSONKey.identifier.rawValue: .string(identifier.rawValue),
                        JSONKey.homekit.rawValue: .boolean(isHomeKitEnabled)])
    }
}

// MARK: - Loading and Saving

extension Configuration {
        
    init?(filename: String) {
        
        // load existing
        guard FileManager.fileExists(at: filename) else { return nil }
        
        guard let jsonData = try? FileManager.contents(at: filename),
            let jsonString = String(UTF8Data: jsonData),
            let jsonValue = JSON.Value(string: jsonString),
            let configuration = Configuration(JSONValue: jsonValue)
            else { return nil }
        
        self = configuration
    }
    
    func save(_ filename: String) throws {
        
        let data = self.toJSON().toString(options: [JSON.WritingOption.pretty])!.toUTF8Data()
        
        // create file if not created
        if FileManager.fileExists(at: filename) == false {
            
            try FileManager.createFile(at: filename)
        }
        
        try FileManager.set(contents: data, at: filename)
    }
    
    
    
    static func load(_ filename: String) throws -> Configuration {
        
        if let configuration = Configuration(filename: filename) {
            
            return configuration
        }
        
        let newConfiguration = Configuration()
        
        try newConfiguration.save(filename)
        
        return newConfiguration
    }
}
