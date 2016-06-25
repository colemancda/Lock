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
        self.data = []
        
        // try load existing data... 
        
        guard FileManager.fileExists(at: filename) else {
            
            // no prevous data
            try! FileManager.createFile(at: filename)
            return
        }
        
        guard let fileData = try? FileManager.contents(at: filename),
            let jsonString = String(UTF8Data: fileData),
            let json = JSON.Value(string: jsonString),
            let jsonArray = json.arrayValue,
            let data = Data.fromJSON(JSONArray: jsonArray)
            else { return }
        
        self.data = data
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
        
        do { try save() }
        
        catch { fatalError("Could not save keys: \(key)") }
    }
        
    // MARK: - Private Methods
    
    private func save() throws {
        
        let data = self.data.toJSON().toString(options: [.Pretty])!.toUTF8Data()
        
        try FileManager.set(contents: data, at: filename)
    }
}

// MARK: - Supporting Types

extension Store {
    
    struct Data: JSONDecodable, JSONEncodable {
        
        enum JSONKey: String {
            
            case date, data, permission
        }
        
        let date: Date
        
        let key: CoreLock.Key
        
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
            
            let keyBytes = Base64.decode(keyDataString.toUTF8Data())
            let permissionData = Base64.decode(permissionDataString.toUTF8Data())
            
            guard let permission = Permission(bigEndian: permissionData),
                let keyData = KeyData(data: keyBytes)
                else { return nil }
            
            self.date = Date(since1970: date)
            self.key = CoreLock.Key(data: keyData, permission: permission)
        }
        
        func toJSON() -> JSON.Value {
            
            var JSONObject = JSON.Object(minimumCapacity: 3)
            
            JSONObject[JSONKey.date.rawValue] = .Number(.Double(date.since1970))
            
            guard let encodedKeyData = String(UTF8Data: Base64.encode(key.data.data))
                else { fatalError("Could not encode KeyData to Base64") }
            
            JSONObject[JSONKey.data.rawValue] = .String(encodedKeyData)
            
            guard let encodedPermisson = String(UTF8Data: Base64.encode(key.permission.toBigEndian()))
                else { fatalError("Could not encode Permission to Base64") }
            
            JSONObject[JSONKey.permission.rawValue] = .String(encodedPermisson)
            
            return JSON.Value.Object(JSONObject)
        }
    }
}
