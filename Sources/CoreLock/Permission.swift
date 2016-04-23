//
//  Permission.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/20/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

/// A Key's permission level.
public enum Permission {
    
    /// This key belongs to the owner of the lock and has unlimited rights.
    case owner
    
    /// This key can create new keys, and has anytime access. 
    case admin
    
    /// This key has anytime access.
    case anytime
    
    //// This ket has access during certain hours and can expire.
    case scheduled(Schedule)
    
    /// Byte value of the permission type.
    public var byte: Byte {
        
        switch self {
            
        case .owner:        return 0x00
        case .admin:        return 0x01
        case .anytime:      return 0x02
        case .scheduled(_): return 0x03
        }
    }
    
    public static let length = 1 + sizeof(Int64.self) + (2 * sizeof(UInt16)) // 13
    
    public func toBigEndian() -> Data {
        
        switch self {
            
        case let .scheduled(schedule):
            
            var expiryBigEndianValue = Int64(schedule.expiry.since1970).bigEndian
            
            var expiryBytes = [UInt8](repeating: 0, count: sizeof(Int64))
            
            withUnsafePointer(&expiryBigEndianValue) { memcpy(&expiryBytes, $0, sizeof(Int64.self)) }
            
            let startBytes = schedule.interval.rawValue.startIndex.bigEndian.bytes
            
            let endBytes = schedule.interval.rawValue.endIndex.bigEndian.bytes
            
            let bytes = [self.byte] + expiryBytes + [startBytes.0, startBytes.1, endBytes.0, endBytes.1]
            
            return Data(byteValue: bytes)
        
        case .owner, .admin, .anytime:
            
            var bytes = [UInt8](repeating: 0, count: Permission.length)
            
            bytes[0] = self.byte
            
            return Data(byteValue: bytes)
        }
    }
    
    public init?(bigEndian: Data) {
        
        guard bigEndian.byteValue.count == Permission.length
            else { return nil }
        
        let byteValue = bigEndian.byteValue
        
        let permissionTypeByte = byteValue[0]
        
        switch permissionTypeByte {
            
        case Permission.owner.byte: self = .owner
            
        case Permission.admin.byte: self = .admin
            
        case Permission.anytime.byte: self = .anytime
            
        // scheduled
        case 0x03:
            
            var dateBytes = Array(byteValue[1 ..< 1 + sizeof(Int64)])
            
            var dateValue: Int64 = 0
            
            withUnsafeMutablePointer(&dateValue) { memcpy($0, &dateBytes, sizeof(Int64)) }
            
            dateValue = dateValue.bigEndian
            
            let start = UInt16.init(bytes: (byteValue[sizeof(Int64) + 1], byteValue[sizeof(Int64) + 2])).bigEndian
            
            let end = UInt16.init(bytes: (byteValue[sizeof(Int64) + 3], byteValue[sizeof(Int64) + 4])).bigEndian
            
            guard start <= end else { return nil }
            
            guard let interval = Schedule.Interval(rawValue: start ... end)
                else { return nil }
            
            let schedule = Schedule(expiry: Date(since1970: TimeInterval(dateValue)), interval: interval)
            
            self = .scheduled(schedule)
            
        // invalid type byte
        default: return nil
        }
    }
}

public extension Permission {
    
    /// Specifies the time and dates a permission is valid.
    public struct Schedule {
        
        /// The date this permission becomes invalid.
        public var expiry: Date
        
        /// The minute interval range the lock can be unlocked.
        public var interval: Interval
        
        public init(expiry: Date, interval: Interval = Interval.anytime) {
            
            self.expiry = expiry
            self.interval = interval
        }
        
        /// Verify that the specified date is valid for this schedule.
        public func valid(_ date: Date = Date()) -> Bool {
            
            guard date < expiry else { return false }
            
            // need to get hour and minute of day to validate
            let dateComponents = DateComponents(date: date)
            
            let minutesValue = UInt16(dateComponents.minute * dateComponents.hour)
            
            guard interval.rawValue.contains(minutesValue)
                else { return false }
            
            return true
        }
    }
}

public extension Permission.Schedule {
    
    /// The minute interval range the lock can be unlocked.
    public struct Interval: RawRepresentable {
        
        public static let min: UInt16 = 0
        
        public static let max: UInt16 = 1440
        
        /// Interval for anytime access.
        public static let anytime = Interval(rawValue: Interval.min ... Interval.max)!
        
        public let rawValue: Range<UInt16>
        
        public init?(rawValue: Range<UInt16>) {
            
            guard rawValue.endIndex <= Interval.max
                else { return nil }
            
            self.rawValue = rawValue
        }
    }
}
