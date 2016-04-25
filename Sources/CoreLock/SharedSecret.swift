//
//  SharedSecret.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/25/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

/// A shared secret for creating new keys.
public struct SharedSecret {
    
    public var value: (Digit, Digit, Digit, Digit, Digit, Digit)
    
    public init(value: (Digit, Digit, Digit, Digit, Digit, Digit)) {
        
        self.value = value
    }
    
    /// Generates a random shared secret.
    public init() {
        
        self.value = (Digit(), Digit(), Digit(), Digit(), Digit(), Digit())
    }
}

public extension SharedSecret {
    
    /// A Digit 0 ... 9
    public struct Digit: RawRepresentable {
        
        public static let min = Digit(0)
        
        public static let max = Digit(9)
        
        public var rawValue: UInt8
        
        public init?(rawValue: UInt8) {
            
            guard rawValue >= Digit.min.rawValue
                && rawValue <= Digit.max.rawValue
                else { return nil }
            
            self.rawValue = rawValue
        }
        
        private init(_ unsafeValue: UInt8) {
            
            assert(Digit(rawValue: unsafeValue) != nil, "Invalid unsafe value \(unsafeValue)")
            
            self.rawValue = unsafeValue
        }
        
        /// Generates a random digit.
        public init() {
            
            srand(UInt32(time(nil)))
            
            let randomNumber = rand() % 10
            
            self.init(UInt8(randomNumber))
        }
    }
}