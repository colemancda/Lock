//
//  Configuration.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/16/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock

struct Configuration: JSONEncodable, JSONDecodable {
    
    let identifier: UUID
    
    let model: Model
    
    init(model: Model = .orangePiOne) {
        
        self.identifier = UUID()
        
        self.model = Model.orangePiOne
    }
}

// MARK: - JSON

extension Configuration {
    
    enum JSONKey: String {
        
        case identifier, model
    }
    
    init?(JSONValue: JSON.Value) {
        
        guard let JSONObject = JSONValue.objectValue,
            let identifierString = JSONObject[JSONKey.identifier.rawValue]?.rawValue as? String,
            let identifier = UUID(rawValue: identifierString),
            let modelInteger = JSONObject[JSONKey.model.rawValue]?.rawValue as? Int,
            let model = Model(rawValue: UInt8(modelInteger))
            else { return nil }
        
        self.identifier = identifier
        self.model = model
    }
    
    func toJSON() -> JSON.Value {
        
        return .Object([JSONKey.identifier.rawValue: .String(identifier.rawValue),
                        JSONKey.model.rawValue: .Number(.Integer(Int(model.rawValue)))])
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
        
        let data = self.toJSON().toString(options: [JSON.WritingOption.Pretty])!.toUTF8Data()
        
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
