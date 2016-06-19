//
//  Store.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/23/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreLock
import BSON

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
        
        guard let fileData = try? FileManager.contents(at: filename)
            else { return }
        
        let bson = BSON.Document(data: fileData.byteValue)
                
        var existingData: [Store.Data] = []
        
        for bson in bson.arrayValue {
            
            guard let storeData = Store.Data(BSONValue: bson)
                else { return }
            
            existingData.append(storeData)
        }
        
        self.data = existingData
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
                
        let bsonArray = self.data.map { $0.toBSON() }
        
        let bson = Document(array: bsonArray)
        
        let data = SwiftFoundation.Data(byteValue: bson.bytes)
        
        try! FileManager.set(contents: data, at: filename)
    }
}

// MARK: - Supporting Types

extension Store {
    
    struct Data {
        
        enum BSONKey: String {
            
            case date, data, permission
        }
        
        let date: Date
        
        let key: CoreLock.Key
        
        private init(key: Key) {
            
            self.date = Date()
            self.key = key
        }
        
        init?(BSONValue: BSON.Value) {
            
            guard let document = BSONValue.documentValue,
                let date = document[BSONKey.date.rawValue].doubleValue,
                case let .binary(.generic, keyDataBytes) = document[BSONKey.data.rawValue],
                let keyData = KeyData(data: SwiftFoundation.Data(byteValue: keyDataBytes)),
                case let .binary(.generic, permissionBytes) = document[BSONKey.permission.rawValue],
                let permission = Permission(bigEndian: SwiftFoundation.Data(byteValue: permissionBytes))
                else { return nil }
            
            self.date = Date(since1970: date)
            self.key = CoreLock.Key(data: keyData, permission: permission)
        }
        
        func toBSON() -> BSON.Value {
            
            var document = BSON.Document()
            
            document[BSONKey.date.rawValue] = .double(date.since1970)
            
            document[BSONKey.data.rawValue] = .binary(subtype: .generic, data: key.data.data.byteValue)
            
            document[BSONKey.permission.rawValue] = .binary(subtype: .generic, data: key.permission.toBigEndian().byteValue)
            
            return BSON.Value.document(document)
        }
    }
}
