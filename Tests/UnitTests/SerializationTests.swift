//
//  SerializationTests.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/3/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import XCTest
import SwiftFoundation
@testable import CoreLock

final class SerializationTests: XCTestCase {
    
    static let allTests: [(String, (SerializationTests) -> () throws -> Void)] = [("keyJSON", keyJSON)]
    
    func keyJSON() {
        
        let key = Key(identifier: UUID(), name: Key.Name(rawValue: "New Key")!, data: KeyData(), permission: .admin)
        
        guard let decodedKey = Key(JSONValue: key.toJSON())
            else { XCTFail(); return }
        
        XCTAssert(key == decodedKey)
    }
}
