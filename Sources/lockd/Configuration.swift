//
//  Configuration.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import CoreLock
import JSON

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
        
        let fileManager = FileManager.default
        
        // load existing
        guard fileManager.fileExists(atPath: filename) else { return nil }
        
        guard let jsonData = fileManager.contents(atPath: filename),
            let jsonString = String(UTF8Data: jsonData),
            let jsonValue = try? JSON.Value(string: jsonString),
            let configuration = Configuration(JSONValue: jsonValue)
            else { return nil }
        
        self = configuration
    }
    
    func save(_ filename: String) throws {
        
        let data = try! self.toJSON().toString(options: .prettyPrint).toUTF8Data()
        
        let fileManager = FileManager.default
        
        // create file if not created
        if fileManager.fileExists(atPath: filename) == false {
            
            fileManager.createFile(atPath: filename, contents: nil)
        }
        
        try data.write(to: URL(fileURLWithPath: filename))
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
