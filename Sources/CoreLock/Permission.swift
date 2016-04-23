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
