//
//  Store.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/23/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock

// Secure data store.
final class Store {
    
    // MARK: - Properties
    
    let filename: String
    
    private(set) var data: [Data]
    
    // MARK: - Initialization
    
    init(filename: String) {
        
        self.filename = filename
        
        // load existing data
        if FileManager.fileExists(at: filename) {
            
            if let fileData = try? FileManager.contents(at: filename),
                let jsonString = String(UTF8Data: fileData),
                let JSON = JSON.Value(string: jsonString),
                let JSONArray = JSON.arrayValue,
                let data = Data.fromJSON(JSONArray: JSONArray) {
                
                self.data = data
                
            } else {
                
                // could not decode
                self.data = []
            }
            
        } else {
            
            try! FileManager.createFile(at: filename)
            
            // no prevous data
            self.data = []
        }
    }
    
    // MARK: - Methods
    
    func clear() {
        
        data = []
        
        // delete file
        try! FileManager.removeItem(path: filename)
    }
    
    func add(key: Key) {
        
        let newEntry = Store.Data(key: key)
        
        self.data.append(newEntry)
        
        save()
    }
        
    // MARK: - Private Methods
    
    private func save() {
        
        let jsonData = data.toJSON().toString()!.toUTF8Data()
        
        try! FileManager.set(contents: jsonData, at: filename)
    }
}

// MARK: - Supporting Types

extension Store {
    
    struct Data: JSONEncodable, JSONDecodable {
        
        enum JSONKey: String {
            
            case date, data, permission
        }
        
        let date: Date
        
        let key: Key
        
        private init(key: Key) {
            
            self.date = Date()
            self.key = key
        }
        
        init?(JSONValue: JSON.Value) {
            
            guard let JSONObject = JSONValue.objectValue,
                let date = JSONObject[JSONKey.date.rawValue]?.rawValue as? Double,
                let keyDataString = JSONObject[JSONKey.data.rawValue]?.rawValue as? String,
                let permissionDataString = JSONObject[JSONKey.permission.rawValue]?.rawValue as? String
                else { return nil }
            
            guard let keyData = KeyData(data: Base64.decode(keyDataString.toUTF8Data())),
                let permission = Permission(bigEndian: Base64.decode(permissionDataString.toUTF8Data()))
                else { return nil }
            
            self.date = Date(since1970: date)
            self.key = Key(data: keyData, permission: permission)
        }
        
        func toJSON() -> JSON.Value {
            
            var JSONObject = JSON.Object(minimumCapacity: 3)
            
            JSONObject[JSONKey.date.rawValue] = .Number(.Double(date.since1970))
            
            JSONObject[JSONKey.data.rawValue] = .String(String(UTF8Data: Base64.encode(key.data.data))!)
            
            JSONObject[JSONKey.permission.rawValue] = .String(String(UTF8Data: Base64.encode(key.permission.toBigEndian()))!)
            
            return .Object(JSONObject)
        }
    }
}
