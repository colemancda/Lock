//
//  Store.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/23/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import CoreLock

// Secure data store.
final class Store {
    
    private enum JSONKey: String {
        
        case keys, newKeys
    }
    
    // MARK: - Properties
    
    let filename: String
    
    private(set) var keys = [Key]()
    
    private(set) var newKeys = [NewKey]()
    
    // MARK: - Initialization
    
    init(filename: String) {
        
        self.filename = filename
        
        // try load existing data...
        
        guard FileManager.fileExists(at: filename) else {
            
            // no prevous data
            try! FileManager.createFile(at: filename)
            return
        }
        
        guard let fileData = try? FileManager.contents(at: filename),
            let jsonString = String(UTF8Data: fileData),
            let json = JSON.Value(string: jsonString),
            let jsonObject = json.objectValue,
            let keysJSON = jsonObject[JSONKey.keys.rawValue]?.arrayValue,
            let newKeysJSON = jsonObject[JSONKey.newKeys.rawValue]?.arrayValue,
            let keys = Key.from(JSON: keysJSON),
            let newKeys = NewKey.from(JSON: newKeysJSON)
            else { return }
        
        self.keys = keys
        self.newKeys = newKeys
    }
    
    // MARK: - Methods
    
    func clear() {
        
        keys = []
        newKeys = []
        
        // delete file
        try! FileManager.removeItem(path: filename)
    }
    
    func add(key: Key) {
        
        self.keys.append(key)
        
        do { try save() }
            
        catch { fatalError("Could not save key: \(key)") }
    }
    
    func add(newKey: NewKey) {
        
        self.newKeys.append(newKey)
        
        do { try save() }
            
        catch { fatalError("Could not save newKey: \(newKey)") }
    }
    
    @discardableResult
    func remove(key identifier: UUID) -> Bool {
        
        guard let index = keys.index(where: { $0.identifier == identifier })
            else { return false }
        
        keys.remove(at: index)
        
        do { try save() }
            
        catch { fatalError("Could not save key: \(identifier)") }
        
        return true
    }
    
    @discardableResult
    func remove(newKey identifier: UUID) -> Bool {
        
        guard let index = newKeys.index(where: { $0.identifier == identifier })
            else { return false }
        
        newKeys.remove(at: index)
        
        do { try save() }
            
        catch { fatalError("Could not save key: \(identifier)") }
        
        return true
    }
    
    // MARK: - Subcripting
    
    subscript(key identifier: UUID) -> Key? {
        
        guard let index = keys.index(where: { $0.identifier == identifier })
            else { return nil }
        
        return keys[index]
    }
    
    subscript(newKey identifier: UUID) -> NewKey? {
        
        guard let index = newKeys.index(where: { $0.identifier == identifier })
            else { return nil }
        
        return newKeys[index]
    }
    
    // MARK: - Private Methods
    
    private func save() throws {
        
        let json = JSON.Value.object([JSONKey.keys.rawValue: keys.toJSON(), JSONKey.newKeys.rawValue: newKeys.toJSON()])
        
        guard let jsonString = json.toString()
            else { fatalError("Could no encode to JSON string") }
        
        let data = jsonString.toUTF8Data()
        
        try FileManager.set(contents: data, at: filename)
    }
}
