//
//  SharedSecret.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/25/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
    import Glibc
    import SwiftShims
#else
    import Darwin
#endif

import SwiftFoundation

/// A shared secret for creating new keys.
public struct SharedSecret: DataConvertible, Equatable, CustomStringConvertible {
    
    public static let length = 8
    
    public var value: (Digit, Digit, Digit, Digit, Digit, Digit, Digit, Digit)
    
    public init(value: (Digit, Digit, Digit, Digit, Digit, Digit, Digit, Digit)) {
        
        self.value = value
    }
    
    /// Generates a random shared secret.
    public init() {
        
        self.value = (Digit(), Digit(), Digit(), Digit(), Digit(), Digit(), Digit(), Digit())
    }
    
    public var description: String {
        
        return value.0.description
            + value.1.description
            + value.2.description
            + value.3.description
            + value.4.description
            + value.5.description
    }
    
    public init?(data: Data) {
        
        guard data.byteValue.count == SharedSecret.length
            else { return nil }
        
        guard let d1 = Digit(rawValue: data.byteValue[0]),
            let d2 = Digit(rawValue: data.byteValue[1]),
            let d3 = Digit(rawValue: data.byteValue[2]),
            let d4 = Digit(rawValue: data.byteValue[3]),
            let d5 = Digit(rawValue: data.byteValue[4]),
            let d6 = Digit(rawValue: data.byteValue[5]),
            let d7 = Digit(rawValue: data.byteValue[6]),
            let d8 = Digit(rawValue: data.byteValue[7])
            else { return nil }
        
        self.value = (d1, d2, d3, d4, d5, d6, d7, d8)
    }
    
    public func toData() -> Data {
        
        return Data(byteValue: [value.0.rawValue,
                                value.1.rawValue,
                                value.2.rawValue,
                                value.3.rawValue,
                                value.4.rawValue,
                                value.5.rawValue,
                                value.6.rawValue,
                                value.7.rawValue])
    }
}

public extension SharedSecret {
    
    /// A Digit 0 ... 9
    public struct Digit: RawRepresentable, Equatable, CustomStringConvertible {
        
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
            
            self.rawValue = unsafeValue
        }
        
        /// Generates a random digit.
        public init() {
            
            @inline(__always)
            func arc4random_uniform(_ upperBound: UInt32) -> UInt32 {
                #if os(Linux)
                    return _swift_stdlib_cxx11_mt19937_uniform(upperBound)
                #else
                    return Darwin.arc4random_uniform(upperBound)
                #endif
            }
            
            let randomValue = UInt8(arc4random_uniform(10))
            
            assert(randomValue <= Digit.max.rawValue)
            
            self.rawValue = randomValue
        }
        
        public var description: String {
            
            return "\(rawValue)"
        }
    }
}

public func == (lhs: SharedSecret, rhs: SharedSecret) -> Bool {
    
    return lhs.value.0 == rhs.value.0
        && lhs.value.1 == rhs.value.1
        && lhs.value.2 == rhs.value.2
        && lhs.value.3 == rhs.value.3
        && lhs.value.4 == rhs.value.4
        && lhs.value.5 == rhs.value.5
}

// MARK: - KeyData conversion

public extension SharedSecret {
    
    public init?(keyData: KeyData) {
        
        let bytes = keyData.data.byteValue
        
        func sharedSecretBytes(_ index: Int) -> [UInt8] {
            
            return Array(bytes[SharedSecret.length * index ..< SharedSecret.length * (index + 1)])
        }
        
        let secretBytes = sharedSecretBytes(0)
        
        guard let sharedSecret = SharedSecret(data: Data(byteValue: secretBytes))
            else { return nil }
        
        // 4 repetitions of same value
        guard secretBytes == sharedSecretBytes(1)
            && secretBytes == sharedSecretBytes(2)
            && secretBytes == sharedSecretBytes(3)
            else { return nil }
        
        self = sharedSecret
    }
    
    public func toKeyData() -> KeyData {
        
        let secretBytes = self.toData().byteValue
        
        // 4 repetitions of same value
        let keyBytes = secretBytes + secretBytes + secretBytes + secretBytes
        
        return KeyData(data: Data(byteValue: keyBytes))!
    }
}
