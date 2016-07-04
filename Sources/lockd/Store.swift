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
    
    private(set) var keys: [Key]
    
    // MARK: - Initialization
    
    init(filename: String) {
        
        self.filename = filename
        self.keys = []
        
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
            let keys = Key.from(JSON: jsonArray)
            else { return }
        
        self.keys = keys
    }
    
    // MARK: - Methods
    
    func clear() {
        
        keys = []
        
        // delete file
        try! FileManager.removeItem(path: filename)
    }
    
    func add(_ key: Key) {
        
        self.keys.append(key)
        
        do { try save() }
            
        catch { fatalError("Could not save keys: \(key)") }
    }
    
    // MARK: - Private Methods
    
    private func save() throws {
        
        guard let jsonString = self.keys.toJSON().toString()
            else { fatalError("Could no encode to JSON string") }
        
        let data = jsonString.toUTF8Data()
        
        try FileManager.set(contents: data, at: filename)
    }
}
